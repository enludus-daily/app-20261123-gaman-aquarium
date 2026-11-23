import AVFoundation

/// 効果音（端末の中で作る。録音したファイルは持たない）。
/// 夜のアクアリウム：卵を置く＝水に沈むポコッ、孵る＝ガラスの鈴がふわっと上がる、新しい種類＝鈴の 4 音、
/// 泡になる＝やわらかく下がる泡の音、えさ＝小さな粒の音。消音スイッチに従い、ほかのアプリの音と混ぜる（.ambient）
@MainActor
final class SoundBox {
    static let shared = SoundBox()

    enum Cue: Hashable {
        case tap, place, hatch, newSpecies, pop, feed, milestone
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var prepared = false
    private let rate = 44_100.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)

    /// 音量の段階：触る 0.25・えさ 0.4・置く 0.5・泡 0.5・孵る 0.7・新しい種類/目盛り 0.8
    private func volume(_ cue: Cue) -> Float {
        switch cue {
        case .tap: 0.25
        case .feed: 0.4
        case .place, .pop: 0.5
        case .hatch: 0.7
        case .newSpecies, .milestone: 0.8
        }
    }

    private func prepare() -> Bool {
        if prepared { return engine.isRunning || ((try? engine.start()) != nil) }
        guard let format else { return false }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        prepared = true
        return (try? engine.start()) != nil
    }

    func play(_ cue: Cue) {
        guard prepare(), engine.isRunning else { return }
        let buffer: AVAudioPCMBuffer
        if let b = buffers[cue] {
            buffer = b
        } else {
            guard let b = make(cue) else { return }
            buffers[cue] = b
            buffer = b
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = volume(cue)
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    private struct Tone {
        var freq: Double
        var amp: Double
        var decay: Double
        var delay: Double = 0
        var glide: Double? = nil
    }

    private func make(_ cue: Cue) -> AVAudioPCMBuffer? {
        switch cue {
        case .tap:
            return render(0.06, noise: 0.05, noiseDecay: 120, tones: [Tone(freq: 1200, amp: 0.15, decay: 80)])
        case .place:
            // 水に沈む：低いポコッが上へ抜ける
            return render(0.35, noise: 0.06, noiseDecay: 30, tones: [Tone(freq: 220, amp: 0.4, decay: 14, glide: 520), Tone(freq: 880, amp: 0.08, decay: 20, delay: 0.05)])
        case .hatch:
            // ガラスの鈴がふわっと上がる
            let notes = [659.3, 987.8, 1318.5, 1975.5]
            return render(1.4, noise: 0, tones: notes.enumerated().flatMap { i, f in
                [Tone(freq: f, amp: 0.2, decay: 3.5, delay: Double(i) * 0.07), Tone(freq: f * 2.76, amp: 0.04, decay: 8, delay: Double(i) * 0.07)]
            })
        case .newSpecies:
            let notes = [784.0, 1046.5, 1318.5, 1568.0, 2093.0]
            return render(1.6, noise: 0, tones: notes.enumerated().map { i, f in Tone(freq: f, amp: 0.2, decay: 3, delay: Double(i) * 0.11) })
        case .pop:
            // 泡になる：やわらかく下がる（責めない音）
            return render(0.6, noise: 0, tones: [0.0, 0.12, 0.22].enumerated().map { i, d in
                Tone(freq: 900 - Double(i) * 120, amp: 0.18, decay: 12, delay: d, glide: 600 - Double(i) * 90)
            })
        case .feed:
            return render(0.5, noise: 0.04, noiseDecay: 60, tones: [0.0, 0.07, 0.15, 0.24].enumerated().map { i, d in
                Tone(freq: 2200 + Double(i) * 180, amp: 0.1, decay: 40, delay: d)
            })
        case .milestone:
            let notes = [523.3, 659.3, 784.0, 1046.5]
            return render(1.2, noise: 0, tones: notes.enumerated().map { i, f in Tone(freq: f, amp: 0.22, decay: 4, delay: Double(i) * 0.09) })
        }
    }

    private func render(_ seconds: Double, noise: Double, noiseDecay: Double = 60, tones: [Tone]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frames = AVAudioFrameCount(seconds * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var rng = SeededRNG(seed: 22)
        var phases = Array(repeating: 0.0, count: tones.count)
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            var v = 0.0
            for (k, p) in tones.enumerated() where t >= p.delay {
                let local = t - p.delay
                var f = p.freq
                if let to = p.glide {
                    let x = min(1, local / max(0.01, seconds - p.delay))
                    f = p.freq + (to - p.freq) * x
                }
                phases[k] += 2 * .pi * f / rate
                let attack = min(1, local / 0.003)
                v += sin(phases[k]) * p.amp * exp(-local * p.decay) * attack
            }
            if noise > 0 {
                let n = rng.unit() * 2 - 1
                v += n * noise * exp(-t * noiseDecay)
            }
            let tail = min(1, (seconds - t) / 0.01)
            data[i] = Float(max(-1, min(1, v * tail)))
        }
        return buffer
    }
}
