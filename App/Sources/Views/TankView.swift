import SwiftUI

/// 水槽の全画面（主役）。下にガラスの操作盤を固定する
struct TankView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        HStack(spacing: 0) {
            tankArea
            if sizeClass == .regular {
                SidePanel()
                    .frame(width: 340)
                    .background(Ink.sheet.opacity(0.92))
            }
        }
        .background(Color(hex: model.effectiveTheme.palette.waterTop).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { ControlBar() }
    }

    private var tankArea: some View {
        ZStack(alignment: .top) {
            Color(hex: model.effectiveTheme.palette.waterTop).ignoresSafeArea(edges: .top)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    TankCanvas()
                        .allowsHitTesting(false)
                    EggButtons(size: geo.size)
                    SandGauge()
                        .frame(width: geo.size.width, height: geo.size.height * (1 - TankArt.sandTop) - 4, alignment: .bottomLeading)
                        .offset(y: geo.size.height * TankArt.sandTop + 4)
                        .allowsHitTesting(false)
                }
            }
            if model.tank.fish.isEmpty && model.tank.eggs.isEmpty {
                VStack(spacing: 6) {
                    Text(tr("影は、来るかもしれない魚", "The shadows are fish that might come"))
                        .font(Fonts.light(17)).foregroundStyle(Ink.text)
                    Text(tr("欲しい物を思いついたら「欲しい」で卵にしよう。待てたら孵る", "When a want pops up, tap I want… to make an egg. Wait it out and it hatches"))
                        .font(Fonts.body(13)).foregroundStyle(Ink.soft)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.bottom, 60)
                .allowsHitTesting(false)
            }
            VStack(spacing: 8) {
                Header()
                if let banner = model.banner {
                    BannerView(banner: banner)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.banner)
        }
    }
}

/// 動く水槽（TimelineView ＋ Canvas）。撮影では時刻を止め、裏に回ったら止める
struct TankCanvas: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if model.still {
                canvas(t: 1000)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: model.paused)) { tl in
                    canvas(t: tl.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private func canvas(t: Double) -> some View {
        let snap = snapshot(t: t)
        return Canvas { ctx, size in
            TankArt.draw(&ctx, size: size, s: snap)
        }
    }

    private func snapshot(t: Double) -> TankSnapshot {
        let now = model.still ? model.now : max(model.now, Date())
        let eggs = model.tank.eggs.map { egg -> TankSnapshot.EggInfo in
            switch model.tank.status(of: egg, now: now) {
            case .ready: TankSnapshot.EggInfo(egg: egg, progress: 1, ready: true)
            case .warming(_, let p): TankSnapshot.EggInfo(egg: egg, progress: p, ready: false)
            }
        }
        return TankSnapshot(palette: model.effectiveTheme.palette, fish: model.tank.shownFish(), eggs: eggs,
                            dim: model.tank.dimness(now: now), t: t, burst: model.burst, pop: model.pop, feedStart: model.feedStart,
                            ghosts: model.tank.fish.isEmpty, reduceMotion: reduceMotion)
    }

    private var accessibilityText: String {
        trf("水槽：魚 %d 匹、卵 %d 個", "Tank: %d fish, %d eggs", model.tank.fish.count, model.tank.eggs.count)
    }
}

/// 卵を押す場所（絵は Canvas。押せる範囲だけをここで重ねる）
struct EggButtons: View {
    @Environment(AppModel.self) private var model
    var size: CGSize

    var body: some View {
        ForEach(model.tank.eggs) { egg in
            let r = TankArt.eggRect(slot: egg.slot, band: egg.band, size: size).insetBy(dx: -12, dy: -12)
            let ready = model.tank.status(of: egg, now: model.now) == .ready
            Button {
                model.tapEgg(egg)
            } label: {
                Color.clear.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: r.width, height: r.height)
            .position(x: r.midX, y: r.midY)
            .accessibilityLabel(ready ? trf("%@ の卵。孵せる", "%@ egg, ready to hatch", egg.title) : trf("%@ の卵", "%@ egg", egg.title))
            .accessibilityIdentifier("main.egg\(egg.slot)")
        }
    }
}

struct Header: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let waiting = model.tank.waitingCount(now: model.now)
        let ready = model.tank.readyEggs(now: model.now).count
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Caption(text: tr("がまん水族館", "Wishfish").uppercased(), color: Ink.glow)
                Text(model.tank.fish.isEmpty ? tr("まだ静かな水槽", "A quiet tank, for now") : trf("%d 匹が泳いでいる", "%d fish swimming", model.tank.fish.count))
                    .font(Fonts.light(20)).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            if ready > 0 {
                Label(trf("%d 個 孵せる", "%d ready", ready), systemImage: "sparkles")
                    .font(Fonts.label(12)).foregroundStyle(Color(hex: 0x1A1020))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Ink.warm))
                    .lineLimit(1)
            } else if waiting >= TankState.dimStart {
                Text(trf("欲しいが %d つ 渦巻いている", "%d wants swirling", waiting))
                    .font(Fonts.label(12)).foregroundStyle(Ink.soft).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }
}

/// 砂に埋めた目盛り：我慢した合計と、次の目盛りまで
struct SandGauge: View {
    @Environment(AppModel.self) private var model

    /// 砂に彫った文字の色（深海の暗い砂では明るくする）
    private var ink: Color { model.effectiveTheme == .deep ? Ink.text : Color(hex: 0x0A1A33) }

    var body: some View {
        let total = model.savedTotal
        let m = TankState.milestone(total: total, scale: model.scale)
        let prev = m.passed > 0 ? model.scale.milestones[m.passed - 1] : 0
        let frac = m.next.map { Double(total - prev) / Double(max(1, $0 - prev)) } ?? 1
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Caption(text: tr("我慢した合計", "Waited out").uppercased(), color: ink.opacity( 0.75))
                Text(model.format(total))
                    .font(Fonts.number(22)).kerning(-0.5)
                    .foregroundStyle(ink)
                    .contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            VStack(alignment: .trailing, spacing: 3) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ink.opacity( 0.18))
                        Capsule().fill(ink.opacity( 0.6)).frame(width: max(4, g.size.width * frac))
                        ForEach(1..<5) { i in
                            Rectangle().fill(ink.opacity( 0.3)).frame(width: 1, height: 8)
                                .offset(x: g.size.width * Double(i) / 5, y: -1)
                        }
                    }
                }
                .frame(height: 6)
                Text(m.next.map { trf("次の目盛り %@", "Next mark %@", model.format($0)) } ?? tr("目盛りを全部こえた", "Every mark passed"))
                    .font(Fonts.label(10)).foregroundStyle(ink.opacity( 0.7)).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: 150)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
    }
}

struct BannerView: View {
    var banner: Banner

    var body: some View {
        HStack(spacing: 12) {
            if let id = banner.species {
                FishPortrait(species: SpeciesBook.species(id)).frame(width: 52, height: 40)
            } else {
                EggShape().fill(Ink.warm.opacity(0.8)).frame(width: 22, height: 28).padding(.horizontal, 15)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title).font(Fonts.title(15)).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.7)
                Text(banner.detail).font(Fonts.body(12)).foregroundStyle(Ink.soft).lineLimit(2).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Ink.sheet.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).strokeBorder(Ink.glassLine, lineWidth: 1))
        .frame(maxWidth: 520)
    }
}

/// 下に固定する操作盤（図鑑・欲しい・えさ・設定）。どのボタンも同じ優先度で、幅 0 にならない
struct ControlBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            side(icon: "book.pages", text: tr("図鑑", "Book"), id: "main.book") { model.press(); model.activeSheet = .book }
            Button {
                model.openAdd()
            } label: {
                HStack(spacing: 8) {
                    EggShape().fill(Color(hex: 0x1A1020).opacity(0.75)).frame(width: 13, height: 17)
                    Text(tr("欲しい", "I want…")).font(Fonts.title(17)).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(minWidth: 110, maxWidth: .infinity, minHeight: 52, maxHeight: 52)
            }
            .buttonStyle(GlassButtonStyle(tint: Ink.warm, prominent: true))
            .disabled(model.tank.isFull)
            .accessibilityIdentifier("main.add")
            if model.hungryCount > 0 {
                side(icon: "circle.grid.cross", text: tr("えさ", "Feed"), id: "main.feed", badge: model.hungryCount) { model.feed() }
            } else {
                side(icon: "gearshape", text: tr("設定", "Settings"), id: "main.settings") { model.press(); model.activeSheet = .settings }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(Color(hex: model.effectiveTheme.palette.rock).ignoresSafeArea(edges: .bottom))
    }

    private func side(icon: String, text: String, id: String, badge: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 17, weight: .regular))
                Text(text).font(Fonts.label(11)).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(minWidth: 64, maxWidth: .infinity, minHeight: 52, maxHeight: 52)
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text("\(badge)").font(Fonts.label(11)).foregroundStyle(Color(hex: 0x1A1020))
                        .frame(minWidth: 18, minHeight: 18).background(Circle().fill(Ink.warm)).offset(x: -6, y: 2)
                }
            }
        }
        .buttonStyle(GlassButtonStyle())
        .accessibilityIdentifier(id)
    }
}

/// 大きな画面（Duo の内側・regular）の右の欄：卵の一覧・今日の問い・まとめ
struct SidePanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Caption(text: tr("温めている卵", "EGGS COOLING"))
                if model.tank.eggs.isEmpty {
                    Text(tr("欲しい物を思いついたら、下の「欲しい」で卵にしよう", "When a want pops up, turn it into an egg with I want… below"))
                        .font(Fonts.body(13)).foregroundStyle(Ink.soft)
                }
                ForEach(model.tank.eggs) { egg in
                    EggRow(egg: egg).onTapGesture { model.tapEgg(egg) }
                }
                Divider().overlay(Ink.glassLine)
                Caption(text: tr("今日の問い", "TODAY'S QUESTION"))
                Text(CoolingPrompts.pick(eggSeed: 7, dayKey: Days.key(model.now, calendar: model.calendar)).text)
                    .font(Fonts.light(18)).foregroundStyle(Ink.text)
                Divider().overlay(Ink.glassLine)
                HStack {
                    Stat(label: tr("孵った", "Hatched"), value: "\(model.tank.fish.count)")
                    Stat(label: tr("泡", "Bubbles"), value: "\(model.tank.bubbles.count)")
                    Stat(label: tr("図鑑", "Book"), value: "\(model.tank.found.count)")
                }
            }
            .padding(20)
        }
    }
}

struct EggRow: View {
    @Environment(AppModel.self) private var model
    var egg: Egg

    var body: some View {
        let status = model.tank.status(of: egg, now: model.now)
        HStack(spacing: 12) {
            EggShape().fill(Color(hex: egg.kind.colors.body).opacity(0.7)).frame(width: 20, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(egg.title).font(Fonts.title(14)).foregroundStyle(Ink.text).lineLimit(1)
                Text(model.format(egg.amount)).font(Fonts.number(12)).foregroundStyle(Ink.soft)
            }
            Spacer(minLength: 4)
            Text(Remaining.text(status)).font(Fonts.label(12)).foregroundStyle(status == .ready ? Ink.warm : Ink.glow).lineLimit(1)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).fill(Ink.glass))
    }
}

struct Stat: View {
    var label: String
    var value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(Fonts.number(22)).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.6)
            Caption(text: label)
        }
        .frame(maxWidth: .infinity)
    }
}

enum Remaining {
    static func text(_ status: EggStatus) -> String {
        switch status {
        case .ready: return tr("孵せる", "Ready")
        case .warming(let r, _):
            let hours = Int(r / 3600)
            if hours >= 24 { return trf("あと %d日 %d時間", "%dd %dh left", hours / 24, hours % 24) }
            if hours >= 1 { return trf("あと %d 時間", "%dh left", hours) }
            return trf("あと %d 分", "%dm left", max(1, Int(r / 60)))
        }
    }
}
