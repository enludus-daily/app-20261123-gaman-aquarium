import SwiftUI

@main
struct GamanAquariumApp: App {
    /// アプリ全体で 1 つだけ
    private let model = Launch.shared

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        ZStack {
            if !model.onboarded {
                OnboardingView().transition(.opacity)
            } else {
                TankView().transition(.opacity)
            }
        }
        .environment(model)
        // 夜のアクアリウムを自前の色で描くので、ダークに固定する（ライトでも同じ夜の水槽）
        .preferredColorScheme(.dark)
        .sheet(item: $model.activeSheet) { sheet in
            SheetContent(sheet: sheet)
                .environment(model)
                .environment(\.locale, Lang.locale)
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Ink.sheet)
                .presentationDetents(sheet == .egg ? [.large, .medium] : [.large])
        }
        // 手応えの表（README）：押す・卵を置く・孵る・新しい種類・泡になる・えさ
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.placeTick) { _, _ in model.hapticsOn ? .impact(flexibility: .soft, intensity: 0.7) : nil }
        .sensoryFeedback(trigger: model.hatchTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: model.newTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy, intensity: 0.8) : nil }
        .sensoryFeedback(trigger: model.popTick) { _, _ in model.hapticsOn ? .impact(flexibility: .soft, intensity: 0.4) : nil }
        .sensoryFeedback(trigger: model.feedTick) { _, _ in model.hapticsOn ? .impact(weight: .light, intensity: 0.6) : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load(); model.syncPro() }
        .task {
            // 卵の残り時間を進める（画面の表示だけ。保存はしない）
            guard !model.still, !Launch.isDemo else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                if !model.paused { model.now = Date() }
            }
        }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in model.reduceMotion = v }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.backgrounded() }
            guard phase == .active, !model.still else { return }
            model.paused = false
            if !Launch.isDemo { model.now = Date() }
        }
        .environment(\.locale, Lang.locale)
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    static let shared: AppModel = makeModel()

    /// 撮影の日（決まった日にして、毎回同じ水槽にする）
    static func stageDate() -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 21, minute: 40)) ?? Date()
    }

    /// 撮影の通貨：日本語は円、英語はドル
    static var stageCurrency: String { Lang.isJapanese ? "JPY" : "USD" }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in ["tank", "onboarded", "sound", "haptics", "notify", "notifyAsked", "theme", "coolingHours", "paywallOffered"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            let model = AppModel(persists: false, now: stageDate(), currency: stageCurrency)
            model.soundOn = false
            return model
        }
        guard isDemo || scene != nil else { return AppModel() }
        let model = AppModel(persists: false, now: stageDate(), currency: stageCurrency)
        model.still = scene != nil
        let name = scene ?? ""
        model.onboarded = !name.hasPrefix("onboarding")
        model.onboardingPage = name == "onboarding2" ? 1 : (name == "onboarding3" ? 2 : 0)
        if name != "empty" && !name.hasPrefix("onboarding") {
            model.tank = sampleTank(now: model.now, currency: model.currency)
        }
        return model
    }

    static func amounts(_ yen: [Int], currency: String) -> [Int] {
        currency == "JPY" ? yen : yen.map { max(1, $0 / 100) }
    }

    /// 見本の魚（使って 3 週間くらい）
    static func sampleFish(now: Date, currency: String = stageCurrency) -> [Fish] {
        let plan: [(Band, WishKind, Int, Int)] = [
            (.whale, .gadget, 14_800, 3), (.manta, .clothes, 6_900, 3), (.manta, .food, 4_200, 2),
            (.angel, .game, 1_200, 2), (.angel, .conbini, 980, 1), (.angel, .other, 1_800, 3), (.angel, .food, 1_500, 0),
            (.tetra, .conbini, 220, 3), (.tetra, .food, 180, 1), (.tetra, .game, 160, 2), (.tetra, .other, 250, 0), (.tetra, .conbini, 140, 1),
        ]
        var rng = SeededRNG(seed: 23)
        return plan.enumerated().map { i, p in
            let amount = currency == "JPY" ? p.2 : max(1, p.2 / 100)
            var bytes = [UInt8](repeating: 0, count: 16)
            for k in 0..<16 { bytes[k] = UInt8(truncatingIfNeeded: rng.next()) }
            let id = UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
            let hatched = now.addingTimeInterval(-Double(20 - i) * 86_400)
            return Fish(id: id, species: SpeciesBook.species(band: p.0, kind: p.1).id, name: "", amount: amount, currency: currency, kind: p.1,
                        band: p.0, placedAt: hatched.addingTimeInterval(-48 * 3600), hatchedAt: hatched, fed: p.3)
        }
    }

    static func sampleTank(now: Date, currency: String) -> TankState {
        var t = TankState()
        t.fish = sampleFish(now: now, currency: currency)
        t.found = Set(t.fish.map(\.species))
        let a = amounts([12_800, 680, 3_400], currency: currency)
        t.place(name: tr("ワイヤレスイヤホン", "Wireless earbuds"), amount: a[0], currency: currency, kind: .gadget, now: now.addingTimeInterval(-50 * 3600))
        t.place(name: tr("新作のフラペ", "New frappé"), amount: a[1], currency: currency, kind: .conbini, now: now.addingTimeInterval(-30 * 3600))
        t.place(name: tr("冬のニット", "Winter knit"), amount: a[2], currency: currency, kind: .clothes, now: now.addingTimeInterval(-10 * 3600))
        t.bubbles = [Bubble(id: UUID(), name: tr("ガチャ 10 連", "10x gacha pull"), amount: amounts([3_000], currency: currency)[0], currency: currency, kind: .game,
                            placedAt: now.addingTimeInterval(-9 * 86_400), poppedAt: now.addingTimeInterval(-8 * 86_400))]
        return t
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        try? await Task.sleep(for: .milliseconds(150))
        let now = model.now
        let cur = model.currency
        switch scene {
        case "tank": break
        case "ready":
            // 1 つ目の卵（イヤホン）が孵せる
            model.tank.eggs[0].hatchAt = now.addingTimeInterval(-60)
        case "hatch":
            model.tank.eggs[0].hatchAt = now.addingTimeInterval(-60)
            let egg = model.tank.eggs[0]
            model.tank.found.remove(SpeciesBook.species(band: egg.band, kind: egg.kind).id)
            model.hatch(egg)
            model.burst = (egg.slot, model.clock() - 0.35)
        case "dim":
            let a = amounts([5_400, 2_200], currency: cur)
            model.tank.place(name: tr("スニーカー", "Sneakers"), amount: a[0], currency: cur, kind: .clothes, now: now.addingTimeInterval(-3 * 3600))
            model.tank.place(name: tr("推しのアクスタ", "Fan merch"), amount: a[1], currency: cur, kind: .other, now: now.addingTimeInterval(-1 * 3600))
        case "feed":
            model.tank.fish[6].fed = 0
            model.tank.fish[6].hatchedAt = now.addingTimeInterval(-86_400)
            model.feed()
            model.feedStart = model.clock() - 1.2
        case "add":
            model.draft = WishDraft(digits: cur == "JPY" ? "4800" : "48", kind: .game, name: tr("新作ゲームのDLC", "New game DLC"))
            model.activeSheet = .add
        case "egg":
            model.selectedEggID = model.tank.eggs[0].id
            model.activeSheet = .egg
        case "book", "empty": model.activeSheet = .book
        case "settings": model.activeSheet = .settings
        case "paywall": model.activeSheet = .paywall
        case "summary":
            model.proOverride = true
            model.activeSheet = .summary
        case "reef", "deep", "river":
            model.proOverride = true
            model.theme = TankTheme(rawValue: scene) ?? .reef
            if let i = model.tank.fish.indices.last {
                // Pro の季節の魚を 1 匹
                model.tank.fish[i].species = SpeciesBook.seasonal(.autumn, band: .angel).id
                model.tank.fish[i].band = .angel
            }
        default: break
        }
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// 夜の水槽 → 孵せる卵が光る → 孵って新しい魚 → えさで魚が育つ → 「欲しい」を卵にして置く
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ s: Double) async { try? await Task.sleep(for: .milliseconds(Int(s * 1000))) }
        model.soundOn = true
        model.onboarded = true
        model.paywallOffered = true
        var tank = sampleTank(model)
        tank.eggs[0].hatchAt = model.now.addingTimeInterval(-60)
        tank.found.remove(SpeciesBook.species(band: tank.eggs[0].band, kind: tank.eggs[0].kind).id)
        model.tank = tank
        await wait(1.2)
        model.showBanner(tr("欲しい物は、卵にして冷ます", "Every want becomes an egg"), tr("待てたら、その金額の魚が生まれる", "Wait it out and it hatches into a fish"))
        await wait(3.0)
        model.hatch(model.tank.eggs[0])
        await wait(3.6)
        if let i = model.tank.fish.indices.first {
            model.tank.fish[i].hatchedAt = model.now.addingTimeInterval(-86_400)
            model.tank.fish[i].fed = 0
        }
        model.feed()
        await wait(3.0)
        model.openAdd()
        await wait(0.8)
        model.draft.kind = .game
        for k in (model.currency == "JPY" ? ["4", "8", "0", "0"] : ["4", "8"]) {
            model.key(k)
            await wait(0.35)
        }
        await wait(0.8)
        model.placeDraft()
        await wait(3.5)
    }

    private static func sampleTank(_ model: AppModel) -> TankState {
        Launch.sampleTank(now: model.now, currency: model.currency)
    }
}
