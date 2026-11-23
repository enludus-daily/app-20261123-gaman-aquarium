import SwiftUI

/// 水槽の 1 コマを描くのに要るもの（画面の状態から作る値。描く側は状態を持たない）
struct TankSnapshot {
    struct EggInfo {
        var egg: Egg
        var progress: Double
        var ready: Bool
    }

    var palette: TankPalette
    var fish: [Fish]
    var eggs: [EggInfo]
    var dim: Double
    var t: Double
    var burst: (slot: Int, start: Double)?
    var pop: (slot: Int, start: Double)?
    var feedStart: Double?
    var ghosts: Bool
    var reduceMotion: Bool
}

/// 夜のアクアリウムを Canvas で描く（画像を持たない）。動きは時刻 t だけで決まる（撮影では t を止める）
enum TankArt {
    /// 砂の上端（高さに対する割合）
    static let sandTop = 0.84

    static func draw(_ ctx: inout GraphicsContext, size: CGSize, s: TankSnapshot) {
        let w = size.width, h = size.height
        guard w > 10, h > 10 else { return }
        let p = s.palette
        let t = s.reduceMotion ? 1000 : s.t
        let sandY = h * sandTop

        // 1. 水
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(stops: [.init(color: Color(hex: p.waterTop), location: 0), .init(color: Color(hex: p.waterMid), location: 0.5), .init(color: Color(hex: p.waterBottom), location: 1)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

        // 2. 上から差すゆらぐ光の筋（コースティクス）
        var light = ctx
        light.blendMode = .plusLighter
        for i in 0..<6 {
            let fi = Double(i)
            let x0 = w * (0.06 + fi * 0.17 + 0.025 * sin(t * 0.13 + fi * 1.3))
            let topW = w * 0.07
            let shift = w * (i % 2 == 0 ? 0.13 : -0.08)
            let botW = w * 0.2
            var beam = Path()
            beam.move(to: CGPoint(x: x0, y: 0))
            beam.addLine(to: CGPoint(x: x0 + topW, y: 0))
            beam.addLine(to: CGPoint(x: x0 + shift + botW, y: sandY))
            beam.addLine(to: CGPoint(x: x0 + shift, y: sandY))
            beam.closeSubpath()
            let a = 0.07 + 0.045 * sin(t * 0.4 + fi * 1.7)
            light.fill(beam, with: .linearGradient(Gradient(colors: [Color(hex: p.light, opacity: a), Color(hex: p.light, opacity: 0)]),
                                                   startPoint: CGPoint(x: x0, y: 0), endPoint: CGPoint(x: x0 + shift, y: sandY)))
        }
        // 水面のゆらぎ
        for k in 0..<3 {
            var line = Path()
            let y0 = h * (0.025 + Double(k) * 0.018)
            line.move(to: CGPoint(x: 0, y: y0))
            for x in stride(from: 0.0, through: w, by: 8) {
                line.addLine(to: CGPoint(x: x, y: y0 + sin(x / w * 9 + t * 0.9 + Double(k)) * 2.2))
            }
            light.stroke(line, with: .color(Color(hex: p.light, opacity: 0.12 - Double(k) * 0.03)), lineWidth: 1)
        }

        // 3. 奥の岩と水草
        for (i, rx) in [0.16, 0.74].enumerated() {
            let r = CGRect(x: w * rx, y: sandY - h * (0.05 + Double(i) * 0.02), width: w * (0.16 + Double(i) * 0.05), height: h * (0.09 + Double(i) * 0.03))
            ctx.fill(Path(ellipseIn: r), with: .color(Color(hex: p.rock, opacity: 0.85)))
        }
        let stalks: [(x: Double, height: Double, width: Double)] = [
            (0.03, 0.42, 0.020), (0.07, 0.30, 0.016), (0.11, 0.22, 0.014),
            (0.58, 0.18, 0.012), (0.88, 0.26, 0.016), (0.93, 0.44, 0.020), (0.97, 0.33, 0.015),
        ]
        for (i, st) in stalks.enumerated() {
            var path = Path()
            let baseX = w * st.x
            let top = h * st.height
            let steps = 14
            for j in 0...steps {
                let f = Double(j) / Double(steps)
                let x = baseX + sin(t * 0.7 + Double(i) * 1.1 + f * 2.4) * w * 0.022 * f
                let y = sandY + 4 - top * f
                if j == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(path, with: .linearGradient(Gradient(colors: [Color(hex: p.plant), Color(hex: p.plantTip, opacity: 0.85)]),
                                                   startPoint: CGPoint(x: baseX, y: sandY), endPoint: CGPoint(x: baseX, y: sandY - top)),
                       style: StrokeStyle(lineWidth: w * st.width, lineCap: .round, lineJoin: .round))
        }

        // 4. 空の水槽：来るかもしれない魚の影
        if s.ghosts {
            for (i, band) in Band.allCases.enumerated() {
                let L = w * band.baseLength * 1.1
                let c = CGPoint(x: w * [0.27, 0.7, 0.33, 0.66][i], y: h * [0.2, 0.3, 0.46, 0.62][i])
                var g = ctx
                g.translateBy(x: c.x, y: c.y)
                g.scaleBy(x: i % 2 == 0 ? 1 : -1, y: 1)
                g.opacity = 0.22
                FishArt.silhouette(&g, band: band, length: L, t: t)
            }
        }

        // 5. 魚
        for f in s.fish {
            let pose = pose(of: f, t: t, size: size)
            var g = ctx
            g.translateBy(x: pose.center.x, y: pose.center.y)
            g.scaleBy(x: pose.facing, y: 1)
            var L = w * f.length
            if let fs = s.feedStart, t - fs < 0.9, t >= fs + 0.3 {
                L *= 1 + 0.12 * sin(.pi * (t - fs - 0.3) / 0.6)
            }
            FishArt.draw(&g, species: SpeciesBook.species(f.species), length: L, t: t + Double(f.seed % 97))
        }

        // 6. 泡の柱
        for (ci, cx) in [0.83, 0.2].enumerated() {
            for k in 0..<7 {
                let speed = h * 0.085
                let travel = (t * speed + Double(k) * sandY / 7 + Double(ci) * 37).truncatingRemainder(dividingBy: sandY)
                let y = sandY - travel
                let x = w * cx + sin(t * 2 + Double(k)) * 4
                let r = 1.6 + Double((k * 3 + ci) % 4) * 1.1
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.07)))
                ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.42)), lineWidth: 0.7)
            }
        }

        // 7. 砂
        var sand = Path()
        sand.move(to: CGPoint(x: 0, y: h))
        for x in stride(from: 0.0, through: w + 8, by: 8) {
            sand.addLine(to: CGPoint(x: x, y: sandY + sin(x / w * 7 + 0.6) * h * 0.008))
        }
        sand.addLine(to: CGPoint(x: w, y: h))
        sand.closeSubpath()
        ctx.fill(sand, with: .linearGradient(Gradient(colors: [Color(hex: p.sandLit, opacity: 0.9), Color(hex: p.sand), Color(hex: p.rock)]),
                                             startPoint: CGPoint(x: 0, y: sandY - 6), endPoint: CGPoint(x: 0, y: h)))
        // 砂の上を動く光のまだら
        for i in 0..<9 {
            let fi = Double(i)
            let x = ((fi * 0.13 + t * 0.008 * (1 + fi.truncatingRemainder(dividingBy: 3))).truncatingRemainder(dividingBy: 1.1) - 0.05) * w
            let y = sandY + h * (0.02 + (fi * 0.37).truncatingRemainder(dividingBy: 1) * 0.1)
            light.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w * 0.08, height: h * 0.012)), with: .color(Color(hex: p.light, opacity: 0.13)))
        }
        // 砂の波の線
        for k in 0..<3 {
            var line = Path()
            let y0 = sandY + h * (0.04 + Double(k) * 0.035)
            line.move(to: CGPoint(x: 0, y: y0))
            for x in stride(from: 0.0, through: w, by: 10) {
                line.addLine(to: CGPoint(x: x, y: y0 + sin(x / w * 11 + Double(k) * 2) * 2))
            }
            ctx.stroke(line, with: .color(Color(hex: p.rock, opacity: 0.35)), lineWidth: 0.8)
        }

        // 8. クラゲ（飾り）
        for j in 0..<2 {
            let fj = Double(j)
            let cx = w * (0.3 + 0.4 * fj + 0.12 * sin(t * 0.05 + fj * 2))
            let cy = h * (0.22 + 0.2 * fj + 0.05 * sin(t * 0.21 + fj))
            FishArt.jelly(&ctx, at: CGPoint(x: cx, y: cy), size: w * (0.07 - fj * 0.015), color: Color(hex: p.jelly), t: t + fj * 3)
        }

        // 9. 卵
        for info in s.eggs {
            drawEgg(&ctx, info: info, size: size, t: t)
        }

        // 10. 暗さ（「欲しい」が渦巻いている）
        if s.dim > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x02040C, opacity: s.dim)))
        }

        // 11. 孵る瞬間の光
        if let b = s.burst {
            let age = t - b.start
            if age >= 0, age < 1.4 {
                let c = eggRect(slot: b.slot, band: .angel, size: size).center
                let r = w * 0.45 * (age / 1.4)
                let a = 1 - age / 1.4
                light.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                           with: .radialGradient(Gradient(colors: [Color.white.opacity(0.75 * a), Ink.warm.opacity(0.35 * a), .clear]), center: c, startRadius: 0, endRadius: r))
                light.stroke(Path(ellipseIn: CGRect(x: c.x - r * 0.8, y: c.y - r * 0.8, width: r * 1.6, height: r * 1.6)), with: .color(Color.white.opacity(0.5 * a)), lineWidth: 1.5)
            }
        }
        // 12. 買った卵が泡になる
        if let pp = s.pop {
            let age = t - pp.start
            if age >= 0, age < 1.8 {
                let c = eggRect(slot: pp.slot, band: .angel, size: size).center
                for k in 0..<9 {
                    let fk = Double(k)
                    let y = c.y - age * h * (0.12 + fk.truncatingRemainder(dividingBy: 3) * 0.05)
                    let x = c.x + sin(age * 4 + fk) * (6 + fk * 2) + (fk - 4) * 3
                    let r = 2.5 + fk.truncatingRemainder(dividingBy: 4) * 1.4
                    ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Ink.bubble.opacity(0.8 * (1 - age / 1.8))), lineWidth: 1)
                }
            }
        }
        // 13. えさ
        if let fs = s.feedStart {
            let age = t - fs
            if age >= 0, age < 3 {
                for k in 0..<16 {
                    let fk = Double(k)
                    let start = fk * 0.06
                    guard age > start else { continue }
                    let x = w * (0.2 + (fk * 0.377).truncatingRemainder(dividingBy: 1) * 0.6) + sin(age * 3 + fk) * 5
                    let y = h * 0.02 + (age - start) * h * 0.22
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)), with: .color(Color(hex: 0xE8B27A, opacity: max(0, 1 - age / 3))))
                }
            }
        }
    }

    /// 卵の場所（砂の上、8 か所）
    static func eggRect(slot: Int, band: Band, size: CGSize) -> CGRect {
        let w = size.width, h = size.height
        let ew = min(w * (0.058 + 0.011 * Double(band.rawValue)), h * 0.09)
        let eh = ew * 1.3
        let cx = w * (0.09 + Double(slot) * (0.82 / 7))
        let bottom = h * (sandTop + 0.075)
        return CGRect(x: cx - ew / 2, y: bottom - eh, width: ew, height: eh)
    }

    static func drawEgg(_ ctx: inout GraphicsContext, info: TankSnapshot.EggInfo, size: CGSize, t: Double) {
        let egg = info.egg
        let r = eggRect(slot: egg.slot, band: egg.band, size: size)
        let c = r.center
        let pulse = info.ready ? 1 + 0.06 * sin(t * 5) : 1 + 0.03 * sin(t * 1.6 + Double(egg.slot))
        var g = ctx
        g.translateBy(x: c.x, y: r.maxY)
        if info.ready { g.rotate(by: .radians(sin(t * 6) * 0.09)) }
        g.scaleBy(x: pulse, y: pulse)
        let local = CGRect(x: -r.width / 2, y: -r.height, width: r.width, height: r.height)
        // 影と光
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r.width * 0.6, y: r.maxY - 3, width: r.width * 1.2, height: 6)), with: .color(.black.opacity(0.25)))
        let glowR = r.height * (info.ready ? 1.3 : 0.95)
        var light = g
        light.blendMode = .plusLighter
        light.fill(Path(ellipseIn: CGRect(x: -glowR, y: -r.height / 2 - glowR, width: glowR * 2, height: glowR * 2)),
                   with: .radialGradient(Gradient(colors: [Ink.warm.opacity(info.ready ? 0.55 : 0.28), .clear]), center: CGPoint(x: 0, y: -r.height / 2), startRadius: 0, endRadius: glowR))
        let shape = EggShape().path(in: local)
        let color = Color(hex: egg.kind.colors.body)
        g.fill(shape, with: .linearGradient(Gradient(colors: [Color.white.opacity(0.55), color.opacity(0.5), Ink.warm.opacity(0.45)]),
                                            startPoint: CGPoint(x: 0, y: -r.height), endPoint: CGPoint(x: 0, y: 0)))
        // 中の小さな命（進むほど大きく、明るく）
        let core = r.width * (0.16 + 0.22 * info.progress)
        light.fill(Path(ellipseIn: CGRect(x: -core / 2, y: -r.height * 0.45 - core / 2, width: core, height: core)),
                   with: .color(Color.white.opacity(0.35 + 0.4 * info.progress)))
        g.stroke(shape, with: .color(.white.opacity(0.55)), lineWidth: 1)
        // 進みの輪（卵のまわりの細い弧）
        if !info.ready {
            var arc = Path()
            arc.addArc(center: CGPoint(x: 0, y: -r.height / 2), radius: r.height * 0.68, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * info.progress), clockwise: false)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r.height * 0.68, y: c.y - r.height * 0.68, width: r.height * 1.36, height: r.height * 1.36)), with: .color(.white.opacity(0.08)), lineWidth: 1.2)
            var ag = ctx
            ag.translateBy(x: c.x, y: r.maxY)
            ag.stroke(arc, with: .color(Ink.glow.opacity(0.85)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        } else {
            // 孵せる：きらめき
            for k in 0..<4 {
                let a = t * 1.5 + Double(k) * .pi / 2
                let p = CGPoint(x: c.x + cos(a) * r.height * 0.75, y: c.y + sin(a) * r.height * 0.75)
                light.fill(Path(ellipseIn: CGRect(x: p.x - c.x - 1.8, y: p.y - r.maxY - 1.8, width: 3.6, height: 3.6)), with: .color(.white.opacity(0.9)))
            }
        }
    }

    /// 魚の位置と向き（魚ごとに決まった泳ぐ道。水槽の端で折り返す）
    static func pose(of f: Fish, t: Double, size: CGSize) -> (center: CGPoint, facing: CGFloat) {
        var rng = SeededRNG(seed: f.seed)
        let w = size.width, h = size.height
        let L = w * f.length
        let lane = 0.1 + rng.unit() * (f.band >= .manta ? 0.5 : 0.6)
        let phase = rng.unit()
        let jitter = 0.8 + rng.unit() * 0.4
        let margin = L * 0.6 + 6
        let range = max(10, w - margin * 2)
        let dist = (t * f.band.speed * w * jitter + phase * range * 2).truncatingRemainder(dividingBy: range * 2)
        let goingRight = dist < range
        let x = margin + (goingRight ? dist : range * 2 - dist)
        let bob = sin(t * 0.5 + phase * 6) * h * 0.02
        let y = min(h * sandTop - L * f.band.heightRatio * 0.5 - 4, max(L * f.band.heightRatio * 0.5 + 4, h * lane + bob))
        return (CGPoint(x: x, y: y), goingRight ? 1 : -1)
    }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

/// 魚の絵（原点が体の真ん中、頭が +x）
enum FishArt {
    static func draw(_ g: inout GraphicsContext, species: Species, length L: Double, t: Double) {
        let col = species.colors
        let body = Color(hex: col.body), fin = Color(hex: col.fin), glow = Color(hex: col.glow)
        let H = L * species.band.heightRatio
        // ぼんやり光る
        var light = g
        light.blendMode = .plusLighter
        let gr = L * 0.75
        light.fill(Path(ellipseIn: CGRect(x: -gr, y: -gr * 0.7, width: gr * 2, height: gr * 1.4)),
                   with: .radialGradient(Gradient(colors: [glow.opacity(0.32), .clear]), center: .zero, startRadius: 0, endRadius: gr))
        let wag = sin(t * (species.band == .whale ? 2.2 : 5.5)) * 0.22

        let bodyPath: Path
        switch species.band {
        case .tetra:
            fins(&g, tail: L * 0.5, spread: H * 0.55, at: -L * 0.3, wag: wag, color: fin)
            bodyPath = fishBody(L: L, H: H * 0.9)
        case .angel:
            var dorsal = Path()
            dorsal.move(to: CGPoint(x: L * 0.12, y: -H * 0.22))
            dorsal.addQuadCurve(to: CGPoint(x: -L * 0.32, y: -H * 0.5), control: CGPoint(x: -L * 0.02, y: -H * 0.5))
            dorsal.addLine(to: CGPoint(x: -L * 0.18, y: -H * 0.12))
            dorsal.closeSubpath()
            var anal = dorsal
            anal = anal.applying(CGAffineTransform(scaleX: 1, y: -1))
            g.fill(dorsal, with: .color(fin.opacity(0.75)))
            g.fill(anal, with: .color(fin.opacity(0.75)))
            fins(&g, tail: L * 0.42, spread: H * 0.28, at: -L * 0.28, wag: wag, color: fin)
            bodyPath = fishBody(L: L * 0.9, H: H * 0.5)
        case .manta:
            let flap = 0.75 + 0.25 * sin(t * 1.8)
            var tail = Path()
            tail.move(to: CGPoint(x: -L * 0.3, y: 0))
            tail.addQuadCurve(to: CGPoint(x: -L * 0.65, y: sin(t * 1.8) * L * 0.05), control: CGPoint(x: -L * 0.48, y: L * 0.03))
            g.stroke(tail, with: .color(fin.opacity(0.8)), lineWidth: max(1, L * 0.02))
            var p = Path()
            p.move(to: CGPoint(x: L * 0.42, y: 0))
            p.addQuadCurve(to: CGPoint(x: -L * 0.05, y: -H * 0.5 * flap), control: CGPoint(x: L * 0.25, y: -H * 0.45 * flap))
            p.addQuadCurve(to: CGPoint(x: -L * 0.32, y: 0), control: CGPoint(x: -L * 0.12, y: -H * 0.12))
            p.addQuadCurve(to: CGPoint(x: -L * 0.05, y: H * 0.5 * flap), control: CGPoint(x: -L * 0.12, y: H * 0.12))
            p.addQuadCurve(to: CGPoint(x: L * 0.42, y: 0), control: CGPoint(x: L * 0.25, y: H * 0.45 * flap))
            p.closeSubpath()
            bodyPath = p
        case .whale:
            var tail = Path()
            let tw = wag * 0.6
            tail.move(to: CGPoint(x: -L * 0.36, y: 0))
            tail.addLine(to: CGPoint(x: -L * 0.52, y: -H * 0.9 + tw * H))
            tail.addQuadCurve(to: CGPoint(x: -L * 0.47, y: 0), control: CGPoint(x: -L * 0.45, y: -H * 0.3))
            tail.addLine(to: CGPoint(x: -L * 0.5, y: H * 0.6 + tw * H))
            tail.closeSubpath()
            g.fill(tail, with: .color(fin.opacity(0.75)))
            var dorsal = Path()
            dorsal.move(to: CGPoint(x: L * 0.02, y: -H * 0.42))
            dorsal.addLine(to: CGPoint(x: -L * 0.1, y: -H * 0.85))
            dorsal.addLine(to: CGPoint(x: -L * 0.14, y: -H * 0.4))
            dorsal.closeSubpath()
            g.fill(dorsal, with: .color(fin.opacity(0.75)))
            var p = Path()
            p.move(to: CGPoint(x: L * 0.5, y: -H * 0.05))
            p.addQuadCurve(to: CGPoint(x: L * 0.2, y: -H * 0.5), control: CGPoint(x: L * 0.48, y: -H * 0.45))
            p.addQuadCurve(to: CGPoint(x: -L * 0.38, y: 0), control: CGPoint(x: -L * 0.2, y: -H * 0.42))
            p.addQuadCurve(to: CGPoint(x: L * 0.2, y: H * 0.45), control: CGPoint(x: -L * 0.2, y: H * 0.4))
            p.addQuadCurve(to: CGPoint(x: L * 0.5, y: -H * 0.05), control: CGPoint(x: L * 0.48, y: H * 0.4))
            p.closeSubpath()
            bodyPath = p
        }
        g.fill(bodyPath, with: .linearGradient(Gradient(colors: [body, body.opacity(0.85), fin.opacity(0.9)]),
                                               startPoint: CGPoint(x: 0, y: -H / 2), endPoint: CGPoint(x: 0, y: H / 2)))
        var pg = g
        pg.clip(to: bodyPath)
        pattern(&pg, species.pattern, L: L, H: H, body: body, fin: fin, glow: glow, t: t)
        g.stroke(bodyPath, with: .color(.white.opacity(0.35)), lineWidth: 0.7)
        // 目
        let eye = CGPoint(x: L * (species.band == .manta ? 0.28 : 0.33), y: -H * (species.band == .angel ? 0.06 : 0.08))
        let er = max(1.2, L * 0.032)
        g.fill(Path(ellipseIn: CGRect(x: eye.x - er, y: eye.y - er, width: er * 2, height: er * 2)), with: .color(Color(hex: 0x0B1426)))
        g.fill(Path(ellipseIn: CGRect(x: eye.x - er * 0.2, y: eye.y - er * 0.7, width: er * 0.7, height: er * 0.7)), with: .color(.white.opacity(0.9)))
    }

    static func fishBody(L: Double, H: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: L * 0.5, y: 0))
        p.addCurve(to: CGPoint(x: -L * 0.32, y: 0), control1: CGPoint(x: L * 0.38, y: -H * 0.78), control2: CGPoint(x: -L * 0.1, y: -H * 0.6))
        p.addCurve(to: CGPoint(x: L * 0.5, y: 0), control1: CGPoint(x: -L * 0.1, y: H * 0.6), control2: CGPoint(x: L * 0.38, y: H * 0.78))
        p.closeSubpath()
        return p
    }

    /// 尾びれ（付け根を中心に振れる）
    static func fins(_ g: inout GraphicsContext, tail: Double, spread: Double, at x: Double, wag: Double, color: Color) {
        var f = g
        f.translateBy(x: x, y: 0)
        f.rotate(by: .radians(wag))
        var p = Path()
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: -tail * 0.5, y: -spread), control: CGPoint(x: -tail * 0.2, y: -spread * 0.3))
        p.addQuadCurve(to: CGPoint(x: -tail * 0.35, y: 0), control: CGPoint(x: -tail * 0.4, y: -spread * 0.4))
        p.addQuadCurve(to: CGPoint(x: -tail * 0.5, y: spread), control: CGPoint(x: -tail * 0.4, y: spread * 0.4))
        p.addQuadCurve(to: .zero, control: CGPoint(x: -tail * 0.2, y: spread * 0.3))
        f.fill(p, with: .color(color.opacity(0.7)))
    }

    static func pattern(_ g: inout GraphicsContext, _ pattern: Pattern, L: Double, H: Double, body: Color, fin: Color, glow: Color, t: Double) {
        switch pattern {
        case .spots:
            for (x, y, r) in [(0.18, -0.15, 0.05), (0.0, 0.1, 0.06), (-0.15, -0.1, 0.045), (0.08, -0.28, 0.035), (-0.22, 0.12, 0.04)] {
                g.fill(Path(ellipseIn: CGRect(x: L * x - L * r, y: H * y * 2 - L * r, width: L * r * 2, height: L * r * 2)), with: .color(.white.opacity(0.45)))
            }
        case .stripes:
            for x in [0.2, 0.02, -0.16] {
                g.fill(Path(CGRect(x: L * x, y: -H, width: L * 0.06, height: H * 2)), with: .color(fin.opacity(0.75)))
            }
        case .glowLine:
            var p = Path()
            p.move(to: CGPoint(x: L * 0.4, y: -H * 0.04))
            p.addLine(to: CGPoint(x: -L * 0.4, y: -H * 0.04))
            g.stroke(p, with: .color(.white.opacity(0.65 + 0.3 * sin(t * 2))), lineWidth: max(1, L * 0.035))
        case .pixels:
            let s = L * 0.06
            for i in 0..<5 {
                for j in 0..<2 where (i + j) % 2 == 0 {
                    g.fill(Path(CGRect(x: L * 0.2 - Double(i) * s * 1.4, y: -s + Double(j) * s * 1.2, width: s, height: s)), with: .color(fin.opacity(0.85)))
                }
            }
        case .bands:
            for x in [0.12, -0.14] {
                g.fill(Path(CGRect(x: L * x, y: -H, width: L * 0.11, height: H * 2)), with: .color(Color(hex: 0x0B1426, opacity: 0.35)))
            }
        case .pearl:
            g.fill(Path(ellipseIn: CGRect(x: -L * 0.2, y: -H * 0.42, width: L * 0.5, height: H * 0.3)), with: .color(.white.opacity(0.5)))
        case .petals:
            for (x, y) in [(0.15, -0.12), (-0.05, 0.08), (-0.2, -0.1)] {
                var p = g
                p.translateBy(x: L * x, y: H * y * 2)
                p.rotate(by: .degrees(35))
                p.fill(Path(ellipseIn: CGRect(x: -L * 0.05, y: -L * 0.025, width: L * 0.1, height: L * 0.05)), with: .color(Color(hex: 0xFFFFFF, opacity: 0.6)))
            }
        case .sparks:
            for k in 0..<6 {
                let a = Double(k) * 1.7
                let x = L * (0.3 - Double(k) * 0.11), y = H * 0.3 * sin(a)
                let r = L * 0.02 * (1 + 0.5 * sin(t * 3 + a))
                g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.85)))
            }
        case .leaves:
            for (x, y) in [(0.12, -0.1), (-0.1, 0.1)] {
                var p = g
                p.translateBy(x: L * x, y: H * y * 2)
                p.rotate(by: .degrees(-30))
                p.fill(Path(ellipseIn: CGRect(x: -L * 0.07, y: -L * 0.03, width: L * 0.14, height: L * 0.06)), with: .color(Color(hex: 0xC2410C, opacity: 0.55)))
            }
        case .frost:
            for (x, y) in [(0.12, -0.05), (-0.15, 0.05)] {
                let c = CGPoint(x: L * x, y: H * y * 2)
                var p = Path()
                for k in 0..<3 {
                    let a = Double(k) * .pi / 3
                    p.move(to: CGPoint(x: c.x - cos(a) * L * 0.06, y: c.y - sin(a) * L * 0.06))
                    p.addLine(to: CGPoint(x: c.x + cos(a) * L * 0.06, y: c.y + sin(a) * L * 0.06))
                }
                g.stroke(p, with: .color(.white.opacity(0.8)), lineWidth: max(0.6, L * 0.012))
            }
        }
    }

    /// 来るかもしれない魚の影（空の水槽）
    static func silhouette(_ g: inout GraphicsContext, band: Band, length L: Double, t: Double) {
        let sp = SpeciesBook.species(band: band, kind: .other)
        var gg = g
        gg.opacity = 0.6
        draw(&gg, species: sp, length: L, t: t)
    }

    /// クラゲ（飾り。ゆっくり脈打つ）
    static func jelly(_ ctx: inout GraphicsContext, at c: CGPoint, size s: Double, color: Color, t: Double) {
        var light = ctx
        light.blendMode = .plusLighter
        let pulse = 1 + 0.08 * sin(t * 1.3)
        light.fill(Path(ellipseIn: CGRect(x: c.x - s, y: c.y - s * 0.9, width: s * 2, height: s * 1.8)),
                   with: .radialGradient(Gradient(colors: [color.opacity(0.22), .clear]), center: c, startRadius: 0, endRadius: s))
        var bell = Path()
        let bw = s * 0.62 * pulse, bh = s * 0.45 / pulse
        bell.move(to: CGPoint(x: c.x - bw, y: c.y))
        bell.addQuadCurve(to: CGPoint(x: c.x + bw, y: c.y), control: CGPoint(x: c.x, y: c.y - bh * 2))
        bell.addQuadCurve(to: CGPoint(x: c.x - bw, y: c.y), control: CGPoint(x: c.x, y: c.y + bh * 0.3))
        ctx.fill(bell, with: .color(color.opacity(0.32)))
        ctx.stroke(bell, with: .color(color.opacity(0.7)), lineWidth: 0.8)
        for k in 0..<4 {
            var p = Path()
            let x0 = c.x - bw * 0.6 + Double(k) * bw * 0.4
            p.move(to: CGPoint(x: x0, y: c.y))
            for j in 1...6 {
                let y = c.y + Double(j) * s * 0.16
                p.addLine(to: CGPoint(x: x0 + sin(t * 1.6 + Double(j) * 0.8 + Double(k)) * s * 0.07, y: y))
            }
            ctx.stroke(p, with: .color(color.opacity(0.45)), lineWidth: 0.8)
        }
    }
}

/// 図鑑・案内・Pro の画面で使う、1 匹だけの魚（止まった絵）
struct FishPortrait: View {
    var species: Species
    var hidden = false
    var t: Double = 3

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            let L = min(size.width * 0.86, size.height / max(0.5, species.band.heightRatio) * 0.8)
            if hidden {
                g.opacity = 0.18
                g.addFilter(.colorMultiply(.black))
            }
            FishArt.draw(&g, species: species, length: L, t: t)
        }
        .accessibilityHidden(true)
    }
}

/// 小さな水槽の見本（Pro の見た目・共有カード）
struct TankThumbnail: View {
    var theme: TankTheme
    var fish: [Fish]
    var t: Double = 1000
    var ghosts = true

    var body: some View {
        Canvas { ctx, size in
            let s = TankSnapshot(palette: theme.palette, fish: fish, eggs: [], dim: 0, t: t, burst: nil, pop: nil, feedStart: nil, ghosts: ghosts && fish.isEmpty, reduceMotion: false)
            TankArt.draw(&ctx, size: size, s: s)
        }
        .accessibilityHidden(true)
    }
}
