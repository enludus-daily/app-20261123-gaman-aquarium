import Foundation

// 水槽の決まり（画面から切り離す。テストは Tests/GamanAquariumTests.swift）
//
// うれしいこと：待てた卵が孵り、金額の魚が水槽に増える。新しい種類が図鑑に載る。我慢した合計の目盛りが上がる。
// 怖い・惜しいこと：冷ます時間の途中で買うと卵が泡になる。卵が 3 つ以上たまると水槽が暗くなる。
//                  孵った翌日以降に見に来てえさをあげないと、魚は大きくならない（罰はない）。

/// 欲しい物の卵
struct Egg: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var amount: Int
    var currency: String
    var kind: WishKind
    var placedAt: Date
    var hatchAt: Date
    /// 砂の上の場所（0..<TankState.maxEggs）
    var slot: Int

    var scale: MoneyScale { .of(currencyCode: currency) }
    var band: Band { .of(amount: amount, scale: scale) }
    var seed: UInt64 { Hash.of(id) }
    var title: String { name.isEmpty ? kind.name : name }
}

enum EggStatus: Equatable, Sendable {
    /// 温めている（残りの秒数・0〜1 の進み）
    case warming(remaining: TimeInterval, progress: Double)
    /// 孵せる
    case ready
}

/// 水槽の魚
struct Fish: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var species: Int
    var name: String
    var amount: Int
    var currency: String
    var kind: WishKind
    var band: Band
    var placedAt: Date
    var hatchedAt: Date
    /// えさを食べた回数（0〜TankState.maxFeeds）
    var fed: Int = 0
    /// 最後にえさを食べた日（yyyy-MM-dd）
    var lastFedDay: String?

    var seed: UInt64 { Hash.of(id) }
    var length: Double { TankState.length(band: band, fed: fed) }
}

/// 待てずに買った卵（泡）。責めずに図鑑の端に残す
struct Bubble: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var amount: Int
    var currency: String
    var kind: WishKind
    var placedAt: Date
    var poppedAt: Date
}

struct HatchResult: Equatable, Sendable {
    var fish: Fish
    var isNewSpecies: Bool
}

struct MonthSummary: Equatable, Sendable {
    var saved: Int
    var hatched: Int
    var bubbles: Int
    var byKind: [WishKind: Int]
}

enum Hash {
    /// UUID から決まった数を作る（魚の泳ぐ道・季節の魚の抽選）
    static func of(_ id: UUID) -> UInt64 {
        let u = id.uuid
        let bytes = [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7, u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for b in bytes {
            h ^= UInt64(b)
            h = h &* 0x100_0000_01B3
        }
        return h
    }
}

enum Days {
    static func key(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

struct TankState: Codable, Equatable, Sendable {
    var eggs: [Egg] = []
    var fish: [Fish] = []
    var bubbles: [Bubble] = []
    /// 図鑑に載った種類
    var found: Set<Int> = []

    /// 砂の上に置ける卵の数
    static let maxEggs = 8
    /// 水槽に同時に描く魚の数（電池と見やすさのため。図鑑には全部残る）
    static let maxFishShown = 40
    /// えさで大きくなる回数
    static let maxFeeds = 3
    /// えさ 1 回で長さが何割伸びるか
    static let growthPerFeed = 0.10
    /// 冷ます時間（既定）。大きな欲しいは 1 日長い
    static let defaultCoolingHours = 48
    static let bigExtraHours = 24
    /// Pro で選べる冷ます時間
    static let coolingChoices = [24, 48, 72, 168]
    /// 水槽が暗くなり始める卵の数
    static let dimStart = 3

    static func length(band: Band, fed: Int) -> Double {
        band.baseLength * (1 + growthPerFeed * Double(min(max(fed, 0), maxFeeds)))
    }

    /// 冷ます時間（時間）。¥3,000（$30）以上は 1 日長い
    static func coolingHours(amount: Int, scale: MoneyScale, baseHours: Int = defaultCoolingHours) -> Int {
        baseHours + (amount >= scale.bigEdge ? bigExtraHours : 0)
    }

    var isFull: Bool { eggs.count >= Self.maxEggs }

    func status(of egg: Egg, now: Date) -> EggStatus {
        let total = egg.hatchAt.timeIntervalSince(egg.placedAt)
        let remaining = egg.hatchAt.timeIntervalSince(now)
        if remaining <= 0 { return .ready }
        let progress = total > 0 ? min(1, max(0, 1 - remaining / total)) : 1
        return .warming(remaining: remaining, progress: progress)
    }

    /// 温めている卵（孵せる卵は数えない）
    func waitingCount(now: Date) -> Int {
        eggs.filter { if case .warming = status(of: $0, now: now) { true } else { false } }.count
    }

    func readyEggs(now: Date) -> [Egg] {
        eggs.filter { status(of: $0, now: now) == .ready }
    }

    /// 水槽の暗さ（0 = ふつう）。「欲しい」が渦巻いている合図
    func dimness(now: Date) -> Double {
        let n = waitingCount(now: now)
        if n < Self.dimStart { return 0 }
        return min(0.42, 0.2 + Double(n - Self.dimStart) * 0.06)
    }

    /// 卵を置く。満杯・金額 0 以下なら置かない
    @discardableResult
    mutating func place(name: String, amount: Int, currency: String, kind: WishKind, now: Date, baseHours: Int = defaultCoolingHours, id: UUID = UUID()) -> Egg? {
        guard !isFull, amount > 0 else { return nil }
        let scale = MoneyScale.of(currencyCode: currency)
        let hours = Self.coolingHours(amount: amount, scale: scale, baseHours: baseHours)
        let used = Set(eggs.map(\.slot))
        // 真ん中から外へ埋める（最初の卵が真ん中に置かれる）
        let order = [3, 4, 2, 5, 1, 6, 0, 7]
        let slot = order.first { !used.contains($0) } ?? 0
        let egg = Egg(id: id, name: String(name.prefix(24)), amount: min(amount, scale.keypadMax), currency: currency, kind: kind,
                      placedAt: now, hatchAt: now.addingTimeInterval(Double(hours) * 3600), slot: slot)
        eggs.append(egg)
        return egg
    }

    /// 孵す（冷ます時間が過ぎた卵だけ）
    mutating func hatch(_ eggID: UUID, now: Date, pro: Bool, calendar: Calendar) -> HatchResult? {
        guard let i = eggs.firstIndex(where: { $0.id == eggID }), status(of: eggs[i], now: now) == .ready else { return nil }
        let egg = eggs.remove(at: i)
        let species = SpeciesBook.pick(band: egg.band, kind: egg.kind, eggSeed: egg.seed, pro: pro, season: .of(now, calendar: calendar))
        let isNew = !found.contains(species.id)
        found.insert(species.id)
        let fish = Fish(id: egg.id, species: species.id, name: egg.name, amount: egg.amount, currency: egg.currency, kind: egg.kind,
                        band: egg.band, placedAt: egg.placedAt, hatchedAt: now)
        self.fish.append(fish)
        return HatchResult(fish: fish, isNewSpecies: isNew)
    }

    /// 待てずに買った。卵は泡になる
    @discardableResult
    mutating func buy(_ eggID: UUID, now: Date) -> Bubble? {
        guard let i = eggs.firstIndex(where: { $0.id == eggID }) else { return nil }
        let egg = eggs.remove(at: i)
        let bubble = Bubble(id: egg.id, name: egg.name, amount: egg.amount, currency: egg.currency, kind: egg.kind, placedAt: egg.placedAt, poppedAt: now)
        bubbles.append(bubble)
        return bubble
    }

    /// えさを待っている魚：孵った日の翌日以降で、今日まだ食べていない、まだ育ちきっていない魚
    func hungryFish(now: Date, calendar: Calendar) -> [Fish] {
        let today = Days.key(now, calendar: calendar)
        return fish.filter { f in
            f.fed < Self.maxFeeds && Days.key(f.hatchedAt, calendar: calendar) < today && f.lastFedDay != today
        }
    }

    /// えさをあげる。大きくなった魚の数を返す
    @discardableResult
    mutating func feed(now: Date, calendar: Calendar) -> Int {
        let hungry = Set(hungryFish(now: now, calendar: calendar).map(\.id))
        let today = Days.key(now, calendar: calendar)
        for i in fish.indices where hungry.contains(fish[i].id) {
            fish[i].fed += 1
            fish[i].lastFedDay = today
        }
        return hungry.count
    }

    /// 我慢した合計（その通貨の魚だけ）
    func savedTotal(currency: String) -> Int {
        fish.filter { $0.currency == currency }.reduce(0) { $0 + $1.amount }
    }

    /// 水槽に描く魚：大きい帯を先に、同じ帯なら新しい順に maxFishShown まで
    func shownFish() -> [Fish] {
        Array(fish.sorted { a, b in a.band != b.band ? a.band > b.band : a.hatchedAt > b.hatchedAt }.prefix(Self.maxFishShown))
    }

    /// 合計の目盛り：いま越えた目盛りと、次の目盛り
    static func milestone(total: Int, scale: MoneyScale) -> (passed: Int, next: Int?) {
        let m = scale.milestones
        let passed = m.filter { total >= $0 }.count
        return (passed, passed < m.count ? m[passed] : nil)
    }

    /// 月のまとめ（Pro）
    func summary(month: Date, currency: String, calendar: Calendar) -> MonthSummary {
        func same(_ d: Date) -> Bool { calendar.isDate(d, equalTo: month, toGranularity: .month) }
        let hatched = fish.filter { same($0.hatchedAt) }
        var byKind: [WishKind: Int] = [:]
        for f in hatched where f.currency == currency { byKind[f.kind, default: 0] += f.amount }
        return MonthSummary(saved: hatched.filter { $0.currency == currency }.reduce(0) { $0 + $1.amount },
                            hatched: hatched.count,
                            bubbles: bubbles.filter { same($0.poppedAt) }.count,
                            byKind: byKind)
    }
}
