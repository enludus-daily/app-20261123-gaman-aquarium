import Foundation
import Observation
import SwiftUI
import UserNotifications

enum ActiveSheet: String, Identifiable {
    case add, egg, book, settings, paywall, summary
    var id: String { rawValue }
}

struct Banner: Equatable {
    var title: String
    var detail: String
    var species: Int?
    var id = UUID()
}

/// 卵を置く画面の下書き（デモでも同じ流れを動かせるよう、モデルに持つ）
struct WishDraft: Equatable {
    var digits: String = ""
    var kind: WishKind = .other
    var name: String = ""

    var amount: Int { Int(digits) ?? 0 }
}

@MainActor
@Observable
final class AppModel {
    // 保存するもの（卵を置く・孵る・買った・えさ・設定を変えたときだけ保存する。毎秒は保存しない）
    var tank = TankState()
    var onboarded: Bool
    var soundOn: Bool
    var hapticsOn: Bool
    var notifyOn: Bool
    var theme: TankTheme
    var coolingHours: Int
    var paywallOffered: Bool
    var notifyAsked: Bool

    // 画面の状態
    var now: Date
    var currency: String
    var activeSheet: ActiveSheet?
    var selectedEggID: UUID?
    var draft = WishDraft()
    var banner: Banner?
    var onboardingPage = 0
    var burst: (slot: Int, start: Double)?
    var pop: (slot: Int, start: Double)?
    var feedStart: Double?
    var notifyDenied = false
    var reduceMotion = false
    /// 撮影（時刻を止める）
    var still = false
    /// 画面が裏に回ったら描画を止める（電池）
    var paused = false
    var proOverride: Bool?

    // 手応え（README の表）
    var pressTick = 0
    var placeTick = 0
    var hatchTick = 0
    var newTick = 0
    var popTick = 0
    var feedTick = 0

    let persists: Bool
    let calendar: Calendar
    let purchases: PurchaseStore
    private let defaults = UserDefaults.standard

    static let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.016"
    static let proID = ProductID.pro(bundleID: bundleID)

    init(persists: Bool = true, now: Date = Date(), currency: String? = nil, calendar: Calendar = .current) {
        self.persists = persists
        self.now = now
        self.calendar = calendar
        self.currency = currency ?? Locale.current.currency?.identifier ?? "JPY"
        purchases = PurchaseStore(productIDs: [Self.proID], proProductIDs: [Self.proID])
        let d = UserDefaults.standard
        if persists, let data = d.data(forKey: "tank"), let saved = try? JSONDecoder().decode(TankState.self, from: data) {
            tank = saved
        }
        onboarded = persists ? d.bool(forKey: "onboarded") : false
        soundOn = persists ? (d.object(forKey: "sound") as? Bool ?? true) : true
        hapticsOn = persists ? (d.object(forKey: "haptics") as? Bool ?? true) : true
        notifyOn = persists ? d.bool(forKey: "notify") : false
        notifyAsked = persists ? d.bool(forKey: "notifyAsked") : true
        theme = persists ? (TankTheme(rawValue: d.string(forKey: "theme") ?? "") ?? .night) : .night
        let hours = d.integer(forKey: "coolingHours")
        coolingHours = persists && TankState.coolingChoices.contains(hours) ? hours : TankState.defaultCoolingHours
        paywallOffered = persists ? d.bool(forKey: "paywallOffered") : true
    }

    // MARK: - 保存

    func save() {
        guard persists else { return }
        if let data = try? JSONEncoder().encode(tank) { defaults.set(data, forKey: "tank") }
    }

    func saveSettings() {
        guard persists else { return }
        defaults.set(onboarded, forKey: "onboarded")
        defaults.set(soundOn, forKey: "sound")
        defaults.set(hapticsOn, forKey: "haptics")
        defaults.set(notifyOn, forKey: "notify")
        defaults.set(notifyAsked, forKey: "notifyAsked")
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(coolingHours, forKey: "coolingHours")
        defaults.set(paywallOffered, forKey: "paywallOffered")
    }

    // MARK: - Pro

    var isPro: Bool { proOverride ?? purchases.entitlements.isPro }

    /// Pro でなくなったら（返金など）、Pro の設定を無料の既定に戻す
    func syncPro() {
        guard !isPro else { return }
        if theme.isPro { theme = .night }
        if coolingHours != TankState.defaultCoolingHours { coolingHours = TankState.defaultCoolingHours }
        saveSettings()
    }

    var effectiveTheme: TankTheme { isPro ? theme : .night }

    // MARK: - 時計

    /// 動きの時計（撮影では止める）
    func clock() -> Double { still ? 1000 : Date().timeIntervalSinceReferenceDate }

    var scale: MoneyScale { .of(currencyCode: currency) }
    var savedTotal: Int { tank.savedTotal(currency: currency) }
    var hungryCount: Int { tank.hungryFish(now: now, calendar: calendar).count }
    var selectedEgg: Egg? { tank.eggs.first { $0.id == selectedEggID } }

    func format(_ amount: Int) -> String { Money.format(amount, code: currency) }

    // MARK: - 操作

    func press() {
        pressTick += 1
        play(.tap)
    }

    func play(_ cue: SoundBox.Cue) {
        guard soundOn, !still else { return }
        SoundBox.shared.play(cue)
    }

    func openAdd() {
        press()
        draft = WishDraft()
        activeSheet = .add
    }

    func key(_ k: String) {
        pressTick += 1
        switch k {
        case "del": draft.digits = String(draft.digits.dropLast())
        default:
            let next = draft.digits + k
            if next == "0" || next == "00" { return }
            if let v = Int(next), v <= scale.keypadMax { draft.digits = next }
        }
    }

    /// 卵を置く（5 秒で終わる流れの最後）
    @discardableResult
    func placeDraft() -> Egg? {
        guard let egg = tank.place(name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines), amount: draft.amount, currency: currency,
                                   kind: draft.kind, now: now, baseHours: isPro ? coolingHours : TankState.defaultCoolingHours) else { return nil }
        save()
        placeTick += 1
        play(.place)
        activeSheet = nil
        let hours = Int(egg.hatchAt.timeIntervalSince(egg.placedAt) / 3600)
        showBanner(tr("卵を置いた", "Egg placed"), trf("%d 時間 冷まして待とう", "Let it cool for %d hours", hours))
        if notifyOn { Notifier.schedule(egg) }
        if !notifyAsked, !still, !Launch.isDemo, !Launch.isFreshUITest {
            notifyAsked = true
            saveSettings()
            Task { await askNotifications() }
        }
        return egg
    }

    func tapEgg(_ egg: Egg) {
        if tank.status(of: egg, now: now) == .ready {
            hatch(egg)
        } else {
            press()
            selectedEggID = egg.id
            activeSheet = .egg
        }
    }

    func hatch(_ egg: Egg) {
        let beforeTotal = savedTotal
        guard let result = tank.hatch(egg.id, now: now, pro: isPro, calendar: calendar) else { return }
        save()
        Notifier.cancel(egg.id)
        burst = (egg.slot, clock())
        hatchTick += 1
        play(.hatch)
        let sp = SpeciesBook.species(result.fish.species)
        if result.isNewSpecies {
            newTick += 1
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                self.play(.newSpecies)
            }
            showBanner(trf("新しい魚：%@", "New fish: %@", sp.name), trf("%@ を待てた。図鑑に載った", "You waited out %@. Added to the book", format(egg.amount)), species: sp.id)
        } else {
            showBanner(trf("%@ が生まれた", "%@ hatched", sp.name), trf("%@ を待てた", "You waited out %@", format(egg.amount)), species: sp.id)
        }
        let before = TankState.milestone(total: beforeTotal, scale: scale).passed
        let after = TankState.milestone(total: savedTotal, scale: scale).passed
        if after > before {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1400))
                self.play(.milestone)
            }
        }
        // 価値を感じた直後（はじめて孵った）に、1 回だけ Pro を見せる
        if !isPro, !paywallOffered, !Launch.isDemo {
            paywallOffered = true
            saveSettings()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(2600))
                if self.activeSheet == nil { self.activeSheet = .paywall }
            }
        }
    }

    func bought(_ egg: Egg) {
        guard tank.buy(egg.id, now: now) != nil else { return }
        save()
        Notifier.cancel(egg.id)
        pop = (egg.slot, clock())
        popTick += 1
        play(.pop)
        activeSheet = nil
        showBanner(tr("卵は泡になった", "The egg turned to bubbles"), tr("正直に押せたのはえらい。泡も図鑑に残る", "Thanks for being honest. Bubbles stay in the book too"))
    }

    func feed() {
        let n = tank.feed(now: now, calendar: calendar)
        guard n > 0 else { return }
        save()
        feedStart = clock()
        feedTick += 1
        play(.feed)
        showBanner(trf("%d 匹が一回り大きくなった", "%d fish grew a size", n), tr("また明日、見に来てね", "Come back tomorrow"))
    }

    func showBanner(_ title: String, _ detail: String, species: Int? = nil) {
        let b = Banner(title: title, detail: detail, species: species)
        banner = b
        guard !still else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.2))
            if self.banner?.id == b.id { self.banner = nil }
        }
    }

    func finishOnboarding() {
        press()
        onboarded = true
        saveSettings()
    }

    func replayOnboarding() {
        activeSheet = nil
        onboardingPage = 0
        onboarded = false
    }

    // MARK: - 通知（卵が孵ったときだけ。許可は最初の卵を置いた後に聞く）

    func askNotifications() async {
        let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        notifyOn = ok
        notifyDenied = !ok
        saveSettings()
        if ok { tank.eggs.forEach(Notifier.schedule) }
    }

    func setNotify(_ on: Bool) {
        if on {
            Task {
                if await Notifier.status() == .denied {
                    notifyOn = false
                    notifyDenied = true
                } else {
                    await askNotifications()
                }
            }
        } else {
            notifyOn = false
            saveSettings()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    func backgrounded() {
        paused = true
    }
}

enum Notifier {
    static func schedule(_ egg: Egg) {
        let content = UNMutableNotificationContent()
        content.title = tr("卵が孵りそう", "An egg is ready to hatch")
        content.body = trf("%@ を待てた。水槽で孵そう", "You waited out %@. Hatch it in your tank", egg.title)
        content.sound = .default
        let interval = egg.hatchAt.timeIntervalSinceNow
        guard interval > 1 else { return }
        let request = UNNotificationRequest(identifier: egg.id.uuidString, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func cancel(_ id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}
