import Foundation
import Testing
@testable import GamanAquarium

/// 水槽の決まり（監督の注文 2026-11-23：①1 か月の図鑑の埋まり方 ②魚の大きさが水槽に収まるか ③冷ます時間の計算）
struct TankRuleTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    func date(_ d: Int, _ h: Int = 12, _ m: Int = 0, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: d, hour: h, minute: m))!
    }

    // MARK: ③ 冷ます時間

    @Test func coolingIs48HoursAnd72ForBigWants() {
        #expect(TankState.coolingHours(amount: 2_999, scale: .yen) == 48)
        #expect(TankState.coolingHours(amount: 3_000, scale: .yen) == 72)
        #expect(TankState.coolingHours(amount: 29, scale: .dollar) == 48)
        #expect(TankState.coolingHours(amount: 30, scale: .dollar) == 72)
        #expect(TankState.coolingHours(amount: 500, scale: .yen, baseHours: 168) == 168)
    }

    @Test func eggHatchesExactlyAfterCoolingAcrossMidnight() throws {
        var tank = TankState()
        let placed = date(23, 23, 30)
        let egg = try #require(tank.place(name: "", amount: 680, currency: "JPY", kind: .food, now: placed))
        // 日をまたいでも、時刻の差で数える（25 日 23:30 に孵る）
        #expect(egg.hatchAt == date(25, 23, 30))
        if case .warming(let remaining, let progress) = tank.status(of: egg, now: date(24, 23, 30)) {
            #expect(abs(remaining - 24 * 3600) < 1)
            #expect(abs(progress - 0.5) < 0.001)
        } else {
            Issue.record("まだ温めているはず")
        }
        #expect(tank.status(of: egg, now: date(25, 23, 29)) != .ready)
        #expect(tank.status(of: egg, now: date(25, 23, 30)) == .ready)
    }

    @Test func clockGoingBackwardKeepsTheEggWarming() throws {
        var tank = TankState()
        let egg = try #require(tank.place(name: "", amount: 500, currency: "JPY", kind: .food, now: date(23)))
        // 端末の時刻を戻しても、進みは 0 のまま（マイナスにならない）
        if case .warming(_, let p) = tank.status(of: egg, now: date(20)) { #expect(p == 0) } else { Issue.record("温めているはず") }
        #expect(tank.hatch(egg.id, now: date(24), pro: false, calendar: calendar) == nil)
    }

    @Test func cannotHatchEarly() throws {
        var tank = TankState()
        let egg = try #require(tank.place(name: "", amount: 500, currency: "JPY", kind: .food, now: date(1)))
        #expect(tank.hatch(egg.id, now: date(2), pro: false, calendar: calendar) == nil)
        let result = try #require(tank.hatch(egg.id, now: date(3, 12, 1), pro: false, calendar: calendar))
        #expect(result.isNewSpecies)
        #expect(result.fish.band == .angel)
        #expect(tank.eggs.isEmpty)
        #expect(tank.savedTotal(currency: "JPY") == 500)
    }

    // MARK: 帯と種類

    @Test func bandsFollowThePrice() {
        #expect(Band.of(amount: 299, scale: .yen) == .tetra)
        #expect(Band.of(amount: 300, scale: .yen) == .angel)
        #expect(Band.of(amount: 2_999, scale: .yen) == .angel)
        #expect(Band.of(amount: 3_000, scale: .yen) == .manta)
        #expect(Band.of(amount: 9_999, scale: .yen) == .manta)
        #expect(Band.of(amount: 10_000, scale: .yen) == .whale)
        #expect(Band.of(amount: 2, scale: .dollar) == .tetra)
        #expect(Band.of(amount: 3, scale: .dollar) == .angel)
        #expect(Band.of(amount: 100, scale: .dollar) == .whale)
        #expect(MoneyScale.of(currencyCode: "JPY") == .yen)
        #expect(MoneyScale.of(currencyCode: "EUR") == .dollar)
    }

    @Test func bookHas24FreeAnd12SeasonalWithUniqueIDs() {
        #expect(SpeciesBook.free.count == 24)
        #expect(SpeciesBook.seasonal.count == 12)
        #expect(Set(SpeciesBook.all.map(\.id)).count == 36)
        for band in Band.allCases {
            for kind in WishKind.allCases {
                let s = SpeciesBook.species(band: band, kind: kind)
                #expect(s.band == band && s.kind == kind)
            }
        }
        #expect(SpeciesBook.all.allSatisfy { !$0.ja.isEmpty && !$0.en.isEmpty && !$0.noteEn.isEmpty })
    }

    @Test func seasonalFishOnlyWithPro() {
        var seasonal = 0
        for i in 0..<300 {
            let free = SpeciesBook.pick(band: .angel, kind: .food, eggSeed: UInt64(i) &* 7919, pro: false, season: .autumn)
            #expect(!free.isSeasonal)
            let pro = SpeciesBook.pick(band: .angel, kind: .food, eggSeed: UInt64(i) &* 7919, pro: true, season: .autumn)
            if pro.isSeasonal { seasonal += 1; #expect(pro.season == .autumn) }
        }
        // 3 回に 1 回くらい
        #expect(seasonal > 70 && seasonal < 130)
    }

    // MARK: ① 1 か月の図鑑の埋まり方

    /// 1 か月に卵 15 個・孵る率 6 割（金額は ¥100〜¥20,000 の対数で一様、種類は一様）。
    /// 孵るのは 9 匹前後なので、24 種のうち 1 か月で埋まるのは 6〜9 種（3〜4 か月で全部がそろう見込み）
    @Test func aMonthFillsAboutAThirdOfTheBook() {
        var rng = SeededRNG(seed: 2026)
        var total = 0
        let trials = 100
        for _ in 0..<trials {
            var tank = TankState()
            for d in 0..<15 {
                let placed = date(1, 9).addingTimeInterval(Double(d) * 2 * 86_400 / 2)
                let amount = Int(exp(log(100.0) + rng.unit() * (log(20_000.0) - log(100.0))))
                let kind = WishKind(rawValue: Int(rng.unit() * 6)) ?? .other
                guard let egg = tank.place(name: "", amount: amount, currency: "JPY", kind: kind, now: placed) else { continue }
                if rng.unit() < 0.6 {
                    _ = tank.hatch(egg.id, now: egg.hatchAt, pro: false, calendar: calendar)
                } else {
                    tank.buy(egg.id, now: placed.addingTimeInterval(3600))
                }
            }
            total += tank.found.count
        }
        let mean = Double(total) / Double(trials)
        #expect(mean >= 6 && mean <= 9, "1 か月の平均 \(mean) 種")
    }

    // MARK: 怖い・惜しい：泡になる割合

    /// 冷ます時間の長さの決まり：1 日ごとに「買ってしまう」気持ちが 10〜25% ある人（ランダム）が、
    /// 15 個の卵を置いたとき、泡になる割合が 2〜4 割に入る（0 割なら緊張がない、8 割なら理不尽。review.md）
    @Test func aboutAThirdOfEggsPopForATypicalUser() {
        var rng = SeededRNG(seed: 1123)
        var popped = 0, placed = 0
        for _ in 0..<100 {
            for _ in 0..<15 {
                let amount = Int(exp(log(100.0) + rng.unit() * (log(20_000.0) - log(100.0))))
                let days = TankState.coolingHours(amount: amount, scale: .yen) / 24
                let urge = 0.10 + rng.unit() * 0.15
                var survived = true
                for _ in 0..<days where rng.unit() < urge { survived = false }
                placed += 1
                if !survived { popped += 1 }
            }
        }
        let rate = Double(popped) / Double(placed)
        #expect(rate >= 0.2 && rate <= 0.4, "泡になる割合 \(rate)")
    }

    @Test func boughtEggBecomesABubbleAndCountsNothing() throws {
        var tank = TankState()
        let egg = try #require(tank.place(name: "スニーカー", amount: 8_000, currency: "JPY", kind: .clothes, now: date(1)))
        #expect(tank.buy(egg.id, now: date(2)) != nil)
        #expect(tank.eggs.isEmpty)
        #expect(tank.bubbles.count == 1)
        #expect(tank.savedTotal(currency: "JPY") == 0)
        #expect(tank.found.isEmpty)
    }

    @Test func threeWaitingEggsDimTheTank() {
        var tank = TankState()
        let now = date(10)
        tank.place(name: "", amount: 100, currency: "JPY", kind: .food, now: now)
        tank.place(name: "", amount: 100, currency: "JPY", kind: .food, now: now)
        #expect(tank.dimness(now: now) == 0)
        tank.place(name: "", amount: 100, currency: "JPY", kind: .food, now: now)
        #expect(tank.dimness(now: now) > 0.15)
        // 孵せる卵は「渦巻く欲しい」に数えない
        #expect(tank.dimness(now: date(13)) == 0)
    }

    @Test func sandHoldsEightEggsAndPlacesFromTheMiddle() {
        var tank = TankState()
        for i in 0..<TankState.maxEggs {
            let egg = tank.place(name: "", amount: 100, currency: "JPY", kind: .food, now: date(1))
            #expect(egg != nil)
            if i == 0 { #expect(egg?.slot == 3) }
        }
        #expect(tank.isFull)
        #expect(tank.place(name: "", amount: 100, currency: "JPY", kind: .food, now: date(1)) == nil)
        #expect(Set(tank.eggs.map(\.slot)).count == TankState.maxEggs)
        #expect(tank.place(name: "", amount: 0, currency: "JPY", kind: .food, now: date(1)) == nil || tank.isFull)
    }

    // MARK: えさと成長

    @Test func fishGrowOnlyWhenVisitedOnALaterDay() throws {
        var tank = TankState()
        let egg = try #require(tank.place(name: "", amount: 1_000, currency: "JPY", kind: .game, now: date(1, 8)))
        _ = try #require(tank.hatch(egg.id, now: date(3, 9), pro: false, calendar: calendar))
        // 孵った日はまだ食べない
        #expect(tank.feed(now: date(3, 22), calendar: calendar) == 0)
        // 翌日に来ると 1 回大きくなる。同じ日に 2 回はない
        #expect(tank.feed(now: date(4, 7), calendar: calendar) == 1)
        #expect(tank.feed(now: date(4, 23), calendar: calendar) == 0)
        // 来なかった日は大きくならない（罰もない）
        #expect(tank.fish[0].fed == 1)
        #expect(tank.feed(now: date(9), calendar: calendar) == 1)
        #expect(tank.feed(now: date(10), calendar: calendar) == 1)
        // 3 回で育ちきる
        #expect(tank.feed(now: date(11), calendar: calendar) == 0)
        #expect(tank.fish[0].fed == TankState.maxFeeds)
    }

    // MARK: ② 魚の大きさが水槽からはみ出ない

    @Test func biggestFishFitsInTheTank() {
        for band in Band.allCases {
            let L = TankState.length(band: band, fed: 99)
            // 水槽の幅の 4 割まで。高さ（ひれ込み）は、縦長の画面でも水の高さ（砂より上）に収まる
            #expect(L <= 0.4, "\(band) の長さ \(L)")
            let heightInWidths = L * band.heightRatio
            // 横長の水槽（Duo の内側：幅 ÷ 高さ ≒ 1.5）でも、水の高さ（0.84）の半分より小さい
            #expect(heightInWidths * 1.5 < 0.84 * 0.5, "\(band) の高さ \(heightInWidths)")
        }
        #expect(TankState.length(band: .whale, fed: 3) > TankState.length(band: .whale, fed: 0))
    }

    @Test func tankDrawsAtMost40FishBiggestFirst() {
        var tank = TankState()
        for i in 0..<60 {
            let band: Band = i == 59 ? .whale : .tetra
            tank.fish.append(Fish(id: UUID(), species: 0, name: "", amount: 100, currency: "JPY", kind: .food, band: band,
                                  placedAt: date(1), hatchedAt: date(1).addingTimeInterval(Double(i) * 60)))
        }
        let shown = tank.shownFish()
        #expect(shown.count == TankState.maxFishShown)
        #expect(shown.first?.band == .whale)
    }

    // MARK: 合計とまとめ

    @Test func milestonesAndMonthlySummary() throws {
        #expect(TankState.milestone(total: 0, scale: .yen).next == 1_000)
        #expect(TankState.milestone(total: 12_000, scale: .yen).passed == 3)
        #expect(TankState.milestone(total: 2_000_000, scale: .yen).next == nil)
        var tank = TankState()
        let a = try #require(tank.place(name: "", amount: 1_200, currency: "JPY", kind: .game, now: date(1)))
        let b = try #require(tank.place(name: "", amount: 300, currency: "JPY", kind: .food, now: date(1)))
        _ = tank.hatch(a.id, now: date(4), pro: false, calendar: calendar)
        tank.buy(b.id, now: date(2))
        let s = tank.summary(month: date(20), currency: "JPY", calendar: calendar)
        #expect(s.saved == 1_200 && s.hatched == 1 && s.bubbles == 1)
        #expect(s.byKind[.game] == 1_200)
        #expect(tank.summary(month: date(5, month: 12), currency: "JPY", calendar: calendar).hatched == 0)
    }

    @Test func promptsChangeByDayAndHaveEnglish() {
        #expect(CoolingPrompts.all.count >= 40)
        #expect(CoolingPrompts.all.allSatisfy { !$0.en.isEmpty })
        let days = (1...10).map { CoolingPrompts.pick(eggSeed: 42, dayKey: "2026-11-\($0)") }
        #expect(Set(days).count > 4)
    }

    @Test func savedStateRoundTrips() throws {
        var tank = TankState()
        let egg = try #require(tank.place(name: "本", amount: 1_500, currency: "JPY", kind: .other, now: date(1)))
        _ = tank.hatch(egg.id, now: date(3, 13), pro: false, calendar: calendar)
        tank.place(name: "", amount: 50, currency: "USD", kind: .gadget, now: date(3))
        let data = try JSONEncoder().encode(tank)
        let back = try JSONDecoder().decode(TankState.self, from: data)
        #expect(back == tank)
    }
}
