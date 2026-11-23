import SwiftUI
import UIKit

struct SheetContent: View {
    let sheet: ActiveSheet

    var body: some View {
        switch sheet {
        case .add: AddWishSheet()
        case .egg: EggSheet()
        case .book: BookSheet()
        case .settings: SettingsSheet()
        case .paywall: PaywallSheet()
        case .summary: SummarySheet()
        }
    }
}

// MARK: - 卵（温めている間）

struct EggSheet: View {
    @Environment(AppModel.self) private var model
    @State private var confirming = false

    var body: some View {
        if let egg = model.selectedEgg {
            let status = model.tank.status(of: egg, now: model.now)
            let progress: Double = { if case .warming(_, let p) = status { return p } else { return 1 } }()
            SheetFrame(title: egg.title) {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.08), lineWidth: 3)
                        Circle().trim(from: 0, to: progress).stroke(Ink.glow, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                        EggShape()
                            .fill(LinearGradient(colors: [.white.opacity(0.6), Color(hex: egg.kind.colors.body).opacity(0.6), Ink.warm.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                            .overlay(EggShape().stroke(.white.opacity(0.6), lineWidth: 1))
                            .frame(width: 70, height: 92)
                            .shadow(color: Ink.warm.opacity(0.5), radius: 18)
                    }
                    .frame(width: 150, height: 150)
                    .padding(.top, 6)
                    VStack(spacing: 4) {
                        Text(Remaining.text(status)).font(Fonts.number(30)).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.6)
                        Text(trf("%@・%@・%@ になる予定", "%@ · %@ · will be a %@", model.format(egg.amount), egg.kind.name, egg.band.name))
                            .font(Fonts.body(13)).foregroundStyle(Ink.soft).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Caption(text: tr("今日の冷ます問い", "TODAY'S COOL-DOWN QUESTION"), color: Ink.glow)
                        Text(CoolingPrompts.pick(eggSeed: egg.seed, dayKey: Days.key(model.now, calendar: model.calendar)).text)
                            .font(Fonts.light(20)).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Ink.glass))

                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 4) {
                    Button {
                        model.press()
                        model.activeSheet = nil
                    } label: {
                        Text(tr("待つ。水槽に戻る", "Keep waiting")).font(Fonts.title(16)).frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .buttonStyle(GlassButtonStyle(tint: Ink.glow, prominent: true))
                    .accessibilityIdentifier("main.wait")

                    if confirming {
                        VStack(spacing: 8) {
                            Text(tr("卵は泡になって消える。責めないから、正直に。", "The egg will turn to bubbles. No judgment, just honesty."))
                                .font(Fonts.body(13)).foregroundStyle(Ink.soft).multilineTextAlignment(.center)
                            Button { model.bought(egg) } label: {
                                Text(tr("買った。泡にする", "I bought it. Pop it")).font(Fonts.title(15)).frame(maxWidth: .infinity).frame(height: 46)
                            }
                            .buttonStyle(GlassButtonStyle(tint: Ink.bubble))
                            .accessibilityIdentifier("main.boughtConfirm")
                        }
                    } else {
                        Button {
                            model.press()
                            withAnimation(.easeOut(duration: 0.25)) { confirming = true }
                        } label: {
                            Text(tr("待てずに買ってしまった", "I couldn't wait — I bought it")).font(Fonts.body(14)).foregroundStyle(Ink.soft)
                                .frame(maxWidth: .infinity).frame(height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("main.bought")
                    }
                }
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 4)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
                .background(Ink.sheet)
            }
        } else {
            SheetFrame(title: tr("卵", "Egg")) {
                Text(tr("この卵はもう水槽にない", "This egg is no longer in the tank")).font(Fonts.body(14)).foregroundStyle(Ink.soft)
            }
        }
    }
}

// MARK: - 図鑑

struct BookSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let found = model.tank.found
        SheetFrame(title: trf("図鑑 %d / %d", "Fish book %d / %d", found.filter { $0 < SpeciesBook.freeCount }.count, SpeciesBook.freeCount)) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Stat(label: tr("我慢した合計", "Waited out"), value: model.format(model.savedTotal))
                    Stat(label: tr("孵った", "Hatched"), value: "\(model.tank.fish.count)")
                    Stat(label: tr("泡", "Bubbles"), value: "\(model.tank.bubbles.count)")
                }
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Ink.glass))

                if model.tank.fish.isEmpty {
                    Text(tr("まだ魚はいない。欲しい物を卵にして、待てたら孵る。下の影は、来るかもしれない魚", "No fish yet. Turn a want into an egg; wait it out and it hatches. The shadows below are fish that might come"))
                        .font(Fonts.body(13)).foregroundStyle(Ink.soft).fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Band.allCases, id: \.self) { band in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Caption(text: band.name.uppercased(), color: Ink.glow)
                            Spacer()
                            Caption(text: band.rangeLabel(scale: model.scale, code: model.currency))
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(WishKind.allCases) { kind in
                                let sp = SpeciesBook.species(band: band, kind: kind)
                                BookCell(species: sp, found: found.contains(sp.id), hint: kind.name)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Caption(text: tr("季節の魚（PRO）", "SEASONAL FISH (PRO)"), color: Ink.warm)
                        Spacer()
                        if !model.isPro {
                            Button { model.press(); model.activeSheet = .paywall } label: {
                                Label(tr("Pro を見る", "See Pro"), systemImage: "lock").font(Fonts.label(12)).padding(.horizontal, 12).frame(height: 32)
                            }
                            .buttonStyle(GlassButtonStyle(tint: Ink.warm))
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(SpeciesBook.seasonal) { sp in
                            BookCell(species: sp, found: found.contains(sp.id), hint: sp.season?.name ?? "")
                        }
                    }
                }

                if model.isPro {
                    Button { model.press(); model.activeSheet = .summary } label: {
                        Label(tr("今月のまとめ", "This month's summary"), systemImage: "calendar").font(Fonts.title(15)).frame(maxWidth: .infinity).frame(height: 48)
                    }
                    .buttonStyle(GlassButtonStyle(tint: Ink.glow, prominent: true))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Caption(text: tr("泡になった卵", "EGGS THAT POPPED"))
                    if model.tank.bubbles.isEmpty {
                        Text(tr("まだない。泡になっても、また卵を置けばいい", "None yet. If one pops, just place another egg"))
                            .font(Fonts.body(13)).foregroundStyle(Ink.faint)
                    }
                    ForEach(model.tank.bubbles.suffix(10).reversed()) { b in
                        HStack(spacing: 10) {
                            Circle().stroke(Ink.bubble.opacity(0.7), lineWidth: 1).frame(width: 14, height: 14)
                            Text(b.name.isEmpty ? b.kind.name : b.name).font(Fonts.body(14)).foregroundStyle(Ink.soft).lineLimit(1)
                            Spacer()
                            Text(Money.format(b.amount, code: b.currency)).font(Fonts.number(13)).foregroundStyle(Ink.faint)
                        }
                    }
                }
            }
        }
    }
}

struct BookCell: View {
    var species: Species
    var found: Bool
    var hint: String

    var body: some View {
        VStack(spacing: 4) {
            FishPortrait(species: species, hidden: !found)
                .frame(height: 44)
            Text(found ? species.name : "？").font(Fonts.label(11)).foregroundStyle(found ? Ink.text : Ink.faint)
                .lineLimit(1).minimumScaleFactor(0.55)
            Text(found ? species.note : hint).font(Fonts.body(9)).foregroundStyle(Ink.faint).lineLimit(2).minimumScaleFactor(0.7)
                .multilineTextAlignment(.center).frame(height: 24, alignment: .top)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).fill(found ? Color(hex: species.colors.glow, opacity: 0.12) : Ink.glass))
        .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).strokeBorder(found ? Color(hex: species.colors.glow, opacity: 0.4) : Color.clear, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(found ? species.name + "、" + species.note : trf("まだ見ていない魚（%@）", "Not found yet (%@)", hint))
    }
}

// MARK: - 設定

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        SheetFrame(title: tr("設定", "Settings")) {
            VStack(alignment: .leading, spacing: 18) {
                group(tr("音と振動", "SOUND & HAPTICS")) {
                    Toggle(tr("効果音", "Sound effects"), isOn: $model.soundOn)
                    Toggle(tr("振動", "Haptics"), isOn: $model.hapticsOn)
                }
                group(tr("お知らせ", "NOTIFICATIONS")) {
                    Toggle(tr("卵が孵るときに知らせる", "Tell me when an egg is ready"), isOn: Binding(get: { model.notifyOn }, set: { model.setNotify($0) }))
                    if model.notifyDenied {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tr("通知が許可されていない。iPhone の設定で許可できる", "Notifications are off for this app. You can allow them in Settings"))
                                .font(Fonts.body(12)).foregroundStyle(Ink.soft)
                            Button(tr("設定を開く", "Open Settings")) {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                            .font(Fonts.label(13)).foregroundStyle(Ink.glow)
                        }
                    }
                }
                group(tr("水槽の見た目", "TANK STYLE")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(TankTheme.allCases) { theme in
                            let locked = theme.isPro && !model.isPro
                            Button {
                                model.press()
                                if locked { model.activeSheet = .paywall } else { model.theme = theme; model.saveSettings() }
                            } label: {
                                VStack(spacing: 4) {
                                    TankThumbnail(theme: theme, fish: [])
                                        .frame(height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    HStack(spacing: 4) {
                                        if locked { Image(systemName: "lock.fill").font(.system(size: 9)) }
                                        Text(theme.name).font(Fonts.label(11)).lineLimit(1).minimumScaleFactor(0.6)
                                    }
                                    .foregroundStyle(model.effectiveTheme == theme ? Ink.glow : Ink.soft)
                                }
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(model.effectiveTheme == theme ? Ink.glow : Ink.glassLine, lineWidth: model.effectiveTheme == theme ? 1.5 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                group(tr("冷ます時間", "COOL-DOWN TIME")) {
                    HStack(spacing: 6) {
                        ForEach(TankState.coolingChoices, id: \.self) { h in
                            let on = (model.isPro ? model.coolingHours : TankState.defaultCoolingHours) == h
                            Button {
                                model.press()
                                if model.isPro { model.coolingHours = h; model.saveSettings() } else { model.activeSheet = .paywall }
                            } label: {
                                Text(h >= 168 ? tr("1 週間", "1 week") : trf("%d 時間", "%dh", h)).font(Fonts.label(12)).lineLimit(1).minimumScaleFactor(0.6)
                                    .foregroundStyle(on ? Color(hex: 0x0A1A33) : Ink.text)
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(Capsule().fill(on ? Ink.glow : Ink.glass))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(model.isPro ? tr("¥3,000（$30）以上の欲しい物は、さらに 1 日長く冷ます", "Wants of ¥3,000 ($30) or more cool one extra day")
                                     : tr("無料は 48 時間（大きな欲しい物は 72 時間）。Pro で自分で決められる", "Free: 48h (72h for big wants). Pro lets you choose"))
                        .font(Fonts.body(12)).foregroundStyle(Ink.faint)
                }
                group(tr("そのほか", "MORE")) {
                    Button(tr("Pro を見る", "See Pro")) { model.press(); model.activeSheet = .paywall }
                    Button(tr("購入を復元", "Restore purchases")) { Task { await model.purchases.restore(); model.syncPro() } }
                    Button(tr("使い方をもう一度見る", "Show the intro again")) { model.replayOnboarding() }
                    Text(tr("金額や名前はこの iPhone の中だけに保存する。銀行・カードとはつながらず、どこにも送らない", "Prices and names stay on this iPhone. No bank or card links, nothing is sent anywhere"))
                        .font(Fonts.body(12)).foregroundStyle(Ink.faint)
                }
            }
            .tint(Ink.glow)
            .onChange(of: model.soundOn) { _, _ in model.saveSettings() }
            .onChange(of: model.hapticsOn) { _, _ in model.saveSettings() }
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: title, color: Ink.glow)
            VStack(alignment: .leading, spacing: 12) { content() }
                .font(Fonts.body(15)).foregroundStyle(Ink.text)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Ink.glass))
        }
    }
}

// MARK: - Pro

struct PaywallSheet: View {
    @Environment(AppModel.self) private var model
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        let product = model.purchases.products.first
        VStack(spacing: 0) {
            SheetFrame(title: tr("がまん水族館 Pro", "Wishfish Pro")) {
                VStack(alignment: .leading, spacing: 16) {
                    // あなたが我慢した合計
                    VStack(alignment: .leading, spacing: 4) {
                        Caption(text: tr("あなたが我慢した合計", "YOU'VE WAITED OUT"), color: Ink.glow)
                        Text(model.format(model.savedTotal)).font(Fonts.number(34)).kerning(-1).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.6)
                        Text(tr("Pro の代金は、1 回の我慢で取り戻せる", "One waited-out want pays for Pro"))
                            .font(Fonts.body(13)).foregroundStyle(Ink.soft)
                    }
                    HStack(spacing: 8) {
                        ForEach([TankTheme.reef, .deep, .river]) { theme in
                            VStack(spacing: 4) {
                                TankThumbnail(theme: theme, fish: model.tank.shownFish())
                                    .frame(height: 92)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                Text(theme.name).font(Fonts.label(10)).foregroundStyle(Ink.soft).lineLimit(1).minimumScaleFactor(0.6)
                            }
                        }
                    }
                    Feature(icon: "drop.halffull", title: tr("水槽の見た目 3 種", "3 tank styles"), detail: tr("夜の礁・深海・熱帯の川。あなたの魚がそのまま泳ぐ", "Night reef, deep sea, jungle river — with your own fish"))
                    Feature(icon: "leaf", title: tr("季節の魚 12 種", "12 seasonal fish"), detail: tr("孵るとき 3 回に 1 回、その季節だけの魚になる", "1 in 3 hatches becomes a fish of the season"))
                    Feature(icon: "timer", title: tr("冷ます時間を自分で決める", "Set your own cool-down"), detail: tr("24 時間・48 時間・72 時間・1 週間", "24h, 48h, 72h or a full week"))
                    Feature(icon: "calendar", title: tr("月のまとめと共有画像", "Monthly summary & share card"), detail: tr("我慢した合計・種類ごとの金額・孵った数と泡の数", "Total waited out, by category, hatched vs. popped"))
                    Text(tr("無料でも、卵・孵化・図鑑 24 種・水槽は全部使える。広告はない。", "Eggs, hatching, the 24-fish book and your tank are all free. No ads, ever."))
                        .font(Fonts.body(12)).foregroundStyle(Ink.faint)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                if model.isPro {
                    Text(tr("Pro を使っている。ありがとう！", "You have Pro. Thank you!")).font(Fonts.title(16)).foregroundStyle(Ink.glow).frame(height: 54)
                } else {
                    Button {
                        guard let product else { return }
                        busy = true
                        Task {
                            let outcome = await model.purchases.purchase(product)
                            busy = false
                            switch outcome {
                            case .purchased: message = nil; model.syncPro(); model.newTick += 1; model.play(.milestone)
                            case .pending: message = tr("承認を待っている", "Waiting for approval")
                            case .failed: message = tr("購入できなかった。もう一度試してほしい", "Purchase failed. Please try again")
                            case .cancelled: break
                            }
                        }
                    } label: {
                        VStack(spacing: 1) {
                            Text(product.map { trf("%@ で Pro にする", "Get Pro for %@", $0.displayPrice) } ?? tr("Pro にする", "Get Pro")).font(Fonts.title(17))
                            Text(tr("1 回の購入で、ずっと", "One purchase, forever")).font(Fonts.label(10)).opacity(0.85)
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                    }
                    .buttonStyle(GlassButtonStyle(tint: Ink.warm, prominent: true))
                    .disabled(product == nil || busy)
                    .accessibilityIdentifier("main.buyPro")
                    if model.purchases.loadState == .unavailable || (model.purchases.loadState == .ready && product == nil) {
                        Text(tr("いまは App Store につながらない。あとでもう一度試してほしい", "Can't reach the App Store right now. Please try again later"))
                            .font(Fonts.body(11)).foregroundStyle(Ink.warm)
                    } else if model.purchases.loadState == .loading {
                        ProgressView().tint(Ink.glow)
                    }
                    if let message { Text(message).font(Fonts.body(11)).foregroundStyle(Ink.soft) }
                    Button { Task { await model.purchases.restore(); model.syncPro() } } label: {
                        Text(tr("購入を復元", "Restore purchases")).font(Fonts.body(13)).foregroundStyle(Ink.soft).frame(maxWidth: .infinity).frame(height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            .background(Ink.sheet)
        }
        .background(Ink.sheet.ignoresSafeArea())
    }
}

struct Feature: View {
    var icon: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Ink.glow)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Ink.glass))
                .overlay(Circle().strokeBorder(Ink.glassLine, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Fonts.title(15)).foregroundStyle(Ink.text)
                Text(detail).font(Fonts.body(12)).foregroundStyle(Ink.soft).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 月のまとめ（Pro）

struct SummarySheet: View {
    @Environment(AppModel.self) private var model
    @State private var shareImage: Image?

    var body: some View {
        let sum = model.tank.summary(month: model.now, currency: model.currency, calendar: model.calendar)
        SheetFrame(title: tr("今月のまとめ", "This month's summary")) {
            VStack(alignment: .leading, spacing: 16) {
                SummaryCard(summary: sum)
                    .environment(model)
                VStack(alignment: .leading, spacing: 8) {
                    Caption(text: tr("種類ごとの我慢", "BY CATEGORY"), color: Ink.glow)
                    let top = max(1, sum.byKind.values.max() ?? 1)
                    ForEach(WishKind.allCases) { kind in
                        let v = sum.byKind[kind] ?? 0
                        HStack(spacing: 8) {
                            Text(kind.name).font(Fonts.label(12)).foregroundStyle(Ink.soft).frame(width: 90, alignment: .leading).lineLimit(1).minimumScaleFactor(0.6)
                            GeometryReader { g in
                                Capsule().fill(Color(hex: kind.colors.body, opacity: 0.8)).frame(width: max(3, g.size.width * Double(v) / Double(top)), height: 8)
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(height: 16)
                            Text(model.format(v)).font(Fonts.number(12)).foregroundStyle(Ink.text).frame(width: 84, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.6)
                        }
                    }
                }
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview(tr("今月のがまん水族館", "My Wishfish month"), image: shareImage)) {
                        Label(tr("共有画像を送る", "Share the card"), systemImage: "square.and.arrow.up").font(Fonts.title(15)).frame(maxWidth: .infinity).frame(height: 48)
                    }
                    .buttonStyle(GlassButtonStyle(tint: Ink.glow, prominent: true))
                }
            }
        }
        .task {
            let renderer = ImageRenderer(content: SummaryCard(summary: sum).environment(model).frame(width: 360, height: 420))
            renderer.scale = 3
            if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
        }
    }
}

struct SummaryCard: View {
    @Environment(AppModel.self) private var model
    var summary: MonthSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TankThumbnail(theme: model.effectiveTheme, fish: model.tank.shownFish())
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Caption(text: model.now.formatted(.dateTime.year().month(.wide).locale(Lang.locale)).uppercased(), color: Ink.glow)
            Text(model.format(summary.saved)).font(Fonts.number(36)).kerning(-1).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.6)
            HStack(spacing: 16) {
                Text(trf("孵った %d", "Hatched %d", summary.hatched))
                Text(trf("泡 %d", "Popped %d", summary.bubbles))
                Spacer()
                Text(tr("がまん水族館", "Wishfish")).foregroundStyle(Ink.faint)
            }
            .font(Fonts.label(12)).foregroundStyle(Ink.soft)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Ink.sheetLow))
    }
}
