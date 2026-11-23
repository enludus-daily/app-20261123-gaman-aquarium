import Foundation

/// 決まった乱数（撮影・テスト・魚の泳ぐ道を毎回同じにする）
struct SeededRNG: RandomNumberGenerator, Sendable {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0..<1 の小数
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// 金額の帯を決める尺度。円は円の帯、それ以外の通貨はドルの帯（英語の利用者向け。監督の注文 2026-11-23）
enum MoneyScale: String, Codable, Sendable {
    case yen, dollar

    static func of(currencyCode: String) -> MoneyScale {
        currencyCode.uppercased() == "JPY" ? .yen : .dollar
    }

    /// 魚の帯の境目：テトラ | エンゼル | マンタ | ジンベエ
    var bandEdges: [Int] { self == .yen ? [300, 3000, 10000] : [3, 30, 100] }

    /// これ以上は「大きな欲しい」で、冷ます時間が 1 日長い
    var bigEdge: Int { bandEdges[1] }

    /// 数字パッドで入れられる上限
    var keypadMax: Int { self == .yen ? 9_999_999 : 99_999 }

    /// 合計の目盛り（我慢した合計がここを越えるたびに目盛りが 1 つ上がる）
    var milestones: [Int] {
        self == .yen
            ? [1_000, 5_000, 10_000, 30_000, 50_000, 100_000, 200_000, 300_000, 500_000, 1_000_000]
            : [10, 50, 100, 300, 500, 1_000, 2_000, 3_000, 5_000, 10_000]
    }
}

enum Money {
    /// 金額の表示（通貨は端末の地域。小数は出さない）
    static func format(_ amount: Int, code: String) -> String {
        amount.formatted(.currency(code: code).precision(.fractionLength(0)).locale(Lang.locale))
    }
}

/// 欲しい物の種類（魚の色と模様になる）
enum WishKind: Int, Codable, CaseIterable, Sendable, Identifiable {
    case food, clothes, gadget, game, conbini, other

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .food: tr("食べ物", "Food")
        case .clothes: tr("服・小物", "Clothes")
        case .gadget: tr("ガジェット", "Gadgets")
        case .game: tr("ゲーム・課金", "Games")
        case .conbini: tr("コンビニ", "Snacks")
        case .other: tr("その他", "Other")
        }
    }

    var symbol: String {
        switch self {
        case .food: "fork.knife"
        case .clothes: "tshirt"
        case .gadget: "headphones"
        case .game: "gamecontroller"
        case .conbini: "cup.and.saucer"
        case .other: "sparkles"
        }
    }

    /// 魚の体・ひれ・光の色（夜の水の中で光って見える明るさ）
    var colors: (body: UInt32, fin: UInt32, glow: UInt32) {
        switch self {
        case .food: (0xFFA77E, 0xFFD6B8, 0xFF8A5C)
        case .clothes: (0xF59BC4, 0xFFD0E6, 0xFF77B4)
        case .gadget: (0x6FD3FF, 0xC4F0FF, 0x38BDF8)
        case .game: (0xB49BFF, 0xDCD0FF, 0x9B7BFF)
        case .conbini: (0xC9F27A, 0xEBFFC2, 0xA6E83A)
        case .other: (0xE6EEF5, 0xFFFFFF, 0xB8D8F0)
        }
    }
}

/// 金額の帯（魚の大きさと形）
enum Band: Int, Codable, CaseIterable, Sendable, Comparable {
    case tetra, angel, manta, whale

    static func < (a: Band, b: Band) -> Bool { a.rawValue < b.rawValue }

    static func of(amount: Int, scale: MoneyScale) -> Band {
        let e = scale.bandEdges
        if amount < e[0] { return .tetra }
        if amount < e[1] { return .angel }
        if amount < e[2] { return .manta }
        return .whale
    }

    /// 生まれたときの長さ（水槽の幅に対する割合）。えさで 1 回 10% ずつ、3 回まで大きくなる
    var baseLength: Double {
        switch self {
        case .tetra: 0.075
        case .angel: 0.12
        case .manta: 0.19
        case .whale: 0.29
        }
    }

    /// 体の高さ ÷ 長さ（ひれを含む）
    var heightRatio: Double {
        switch self {
        case .tetra: 0.42
        case .angel: 1.05
        case .manta: 0.62
        case .whale: 0.34
        }
    }

    /// 泳ぐ速さ（小さいほど速い。1 秒に水槽の幅の何割か）
    var speed: Double {
        switch self {
        case .tetra: 0.075
        case .angel: 0.045
        case .manta: 0.032
        case .whale: 0.022
        }
    }

    var name: String {
        switch self {
        case .tetra: tr("テトラ", "Tetra")
        case .angel: tr("エンゼル", "Angelfish")
        case .manta: tr("マンタ", "Manta")
        case .whale: tr("ジンベエ", "Whale shark")
        }
    }

    /// 「¥300 未満」「¥3,000〜」など、帯の範囲の言葉
    func rangeLabel(scale: MoneyScale, code: String) -> String {
        let e = scale.bandEdges
        switch self {
        case .tetra: return trf("%@ 未満", "Under %@", Money.format(e[0], code: code))
        case .angel: return trf("%@〜", "%@+", Money.format(e[0], code: code))
        case .manta: return trf("%@〜", "%@+", Money.format(e[1], code: code))
        case .whale: return trf("%@〜", "%@+", Money.format(e[2], code: code))
        }
    }
}

/// 季節（Pro の季節の魚）
enum Season: Int, Codable, CaseIterable, Sendable {
    case spring, summer, autumn, winter

    static func of(_ date: Date, calendar: Calendar) -> Season {
        switch calendar.component(.month, from: date) {
        case 3...5: .spring
        case 6...8: .summer
        case 9...11: .autumn
        default: .winter
        }
    }

    var name: String {
        switch self {
        case .spring: tr("春", "Spring")
        case .summer: tr("夏", "Summer")
        case .autumn: tr("秋", "Autumn")
        case .winter: tr("冬", "Winter")
        }
    }

    var colors: (body: UInt32, fin: UInt32, glow: UInt32) {
        switch self {
        case .spring: (0xFFC4D6, 0xFFE8F0, 0xFF9DBB)
        case .summer: (0xFFE27A, 0xFFF4C2, 0x7CF5C8)
        case .autumn: (0xFF9F5A, 0xFFD39A, 0xE8642C)
        case .winter: (0xD8F3FF, 0xFFFFFF, 0x9EE6FF)
        }
    }
}

/// 魚の模様
enum Pattern: Int, Sendable {
    case spots, stripes, glowLine, pixels, bands, pearl, petals, sparks, leaves, frost
}

struct Species: Identifiable, Sendable, Hashable {
    let id: Int
    let band: Band
    let kind: WishKind?
    let season: Season?
    let ja: String
    let en: String
    let noteJa: String
    let noteEn: String

    var name: String { Lang.isJapanese ? ja : en }
    var note: String { Lang.isJapanese ? noteJa : noteEn }
    var isSeasonal: Bool { season != nil }

    var colors: (body: UInt32, fin: UInt32, glow: UInt32) {
        if let season { return season.colors }
        return (kind ?? .other).colors
    }

    var pattern: Pattern {
        if let season {
            switch season {
            case .spring: return .petals
            case .summer: return .sparks
            case .autumn: return .leaves
            case .winter: return .frost
            }
        }
        switch kind ?? .other {
        case .food: return .spots
        case .clothes: return .stripes
        case .gadget: return .glowLine
        case .game: return .pixels
        case .conbini: return .bands
        case .other: return .pearl
        }
    }
}

/// 図鑑：無料 24 種（4 つの帯 × 6 つの種類）＋ Pro の季節の魚 12 種（4 季節 × 小・中・大）
enum SpeciesBook {
    static let freeCount = 24
    static let seasonalCount = 12

    private static func s(_ band: Band, _ kind: WishKind, _ ja: String, _ en: String, _ nja: String, _ nen: String) -> Species {
        Species(id: band.rawValue * 6 + kind.rawValue, band: band, kind: kind, season: nil, ja: ja, en: en, noteJa: nja, noteEn: nen)
    }

    private static func z(_ season: Season, _ size: Int, _ band: Band, _ ja: String, _ en: String, _ nja: String, _ nen: String) -> Species {
        Species(id: freeCount + season.rawValue * 3 + size, band: band, kind: nil, season: season, ja: ja, en: en, noteJa: nja, noteEn: nen)
    }

    static let free: [Species] = [
        s(.tetra, .food, "こむぎテトラ", "Crumb Tetra", "パン 1 個ぶんの我慢から。香ばしい色の小魚", "Born from skipping one pastry. Toasty little thing"),
        s(.tetra, .clothes, "リボンテトラ", "Ribbon Tetra", "ヘアピン 1 本を見送った日に、しま模様で来た", "Arrived in stripes the day you passed on a hair clip"),
        s(.tetra, .gadget, "でんきテトラ", "Spark Tetra", "ケーブル 1 本の我慢。体に細い光の線が走る", "One cable not bought. A thin line of light runs along it"),
        s(.tetra, .game, "ピクセルテトラ", "Pixel Tetra", "ガチャ 1 回ぶん。うろこが四角い", "Worth one gacha pull. Its scales are square"),
        s(.tetra, .conbini, "よみちテトラ", "Corner-Store Tetra", "帰り道のおやつを見送った夜に生まれた", "Hatched the night you walked past the snack aisle"),
        s(.tetra, .other, "しずくテトラ", "Dewdrop Tetra", "名前のない「なんとなく欲しい」から。真珠色", "From a nameless little want. Pearly white"),

        s(.angel, .food, "あまいろエンゼル", "Caramel Angel", "外食 1 回ぶん。ひれがキャラメル色にとける", "One meal out. Its fins melt into caramel"),
        s(.angel, .clothes, "フリルエンゼル", "Frill Angel", "セールの服を待てた。ひれがフリルのよう", "You waited out a sale. Fins like frills"),
        s(.angel, .gadget, "ガラスエンゼル", "Glass Angel", "小さな周辺機器を見送った。中が透けて光る", "A gadget left in the cart. Glows from inside"),
        s(.angel, .game, "コンボエンゼル", "Combo Angel", "ゲームの課金を冷ました。四角い点が並ぶ", "An in-game purchase, cooled off. Rows of square dots"),
        s(.angel, .conbini, "レジ横エンゼル", "Checkout Angel", "レジ横の誘惑に勝った回数を、帯で数えている", "Counts checkout temptations you beat, in bands"),
        s(.angel, .other, "うたかたエンゼル", "Moonmist Angel", "ふわっとした欲しいが、ゆっくり形になった", "A drifting want that slowly took shape"),

        s(.manta, .food, "ごちそうマンタ", "Feast Manta", "ちょっといい店を見送った。翼に斑点", "You skipped the fancy dinner. Spotted wings"),
        s(.manta, .clothes, "ケープマンタ", "Cape Manta", "コート 1 着ぶん。翼がマントのようにひるがえる", "Worth a coat. Its wings sweep like a cape"),
        s(.manta, .gadget, "ホログラムマンタ", "Hologram Manta", "新しいイヤホンを 3 日冷ました", "New earbuds, cooled for three days"),
        s(.manta, .game, "ガチャマンタ", "Loot Manta", "天井まで回さなかった。背中に光る四角", "You didn't chase the pity. Glowing squares on its back"),
        s(.manta, .conbini, "まとめ買いマンタ", "Bulk-Buy Manta", "ついで買いの山を崩した", "You toppled a pile of add-on buys"),
        s(.manta, .other, "よぞらマンタ", "Night-Sky Manta", "大きな「なんとなく」を待てた。夜空の色", "A big vague want, waited out. Night-sky colored"),

        s(.whale, .food, "まんぷくジンベエ", "Banquet Whale Shark", "旅先のごちそうより、水槽を選んだ", "You picked the tank over a feast"),
        s(.whale, .clothes, "ドレスジンベエ", "Gala Whale Shark", "大きな服の買い物を見送った。ゆったり泳ぐ", "A big clothes haul, skipped. Swims slow and grand"),
        s(.whale, .gadget, "サーキットジンベエ", "Circuit Whale Shark", "新しい機種への買い替えを冷ました", "You cooled off on the new model"),
        s(.whale, .game, "ラスボスジンベエ", "Final Boss Whale Shark", "大きな課金に勝った。水槽のぬし", "You beat a big in-game spend. Ruler of the tank"),
        s(.whale, .conbini, "よふかしジンベエ", "All-Night Whale Shark", "小さな買い物の積み重ねを、まとめて冷ました", "A mountain of small buys, cooled all at once"),
        s(.whale, .other, "ほしぞらジンベエ", "Starfield Whale Shark", "いちばん大きな「欲しい」を待てた証", "Proof you waited out your biggest want"),
    ]

    static let seasonal: [Species] = [
        z(.spring, 0, .tetra, "さくらテトラ", "Sakura Tetra", "春に孵った小さな我慢。花びら模様", "A small spring win. Petal patterned"),
        z(.spring, 1, .angel, "はなびらエンゼル", "Petal Angel", "ひれが花びらのように重なる", "Fins layered like petals"),
        z(.spring, 2, .manta, "はるがすみマンタ", "Spring-Haze Manta", "春の霞の色をした大きな翼", "Wide wings the color of spring haze"),
        z(.summer, 0, .tetra, "ほたるテトラ", "Firefly Tetra", "夏の夜だけ光る小魚", "Glows only on summer nights"),
        z(.summer, 1, .angel, "はなびエンゼル", "Firework Angel", "孵るとき、小さな花火が散る", "Little fireworks scatter when it hatches"),
        z(.summer, 2, .whale, "なつぞらジンベエ", "Summer-Sky Whale Shark", "入道雲のような白い斑点", "White spots like summer clouds"),
        z(.autumn, 0, .tetra, "もみじテトラ", "Maple Tetra", "紅葉の色の小さな群れ", "A tiny school in maple red"),
        z(.autumn, 1, .angel, "つきみエンゼル", "Moon-Viewing Angel", "秋の月の下で孵る", "Hatches under the autumn moon"),
        z(.autumn, 2, .manta, "いなほマンタ", "Harvest Manta", "稲穂の色の翼で、ゆっくり舞う", "Glides on wings the color of ripe rice"),
        z(.winter, 0, .tetra, "ゆきテトラ", "Snow Tetra", "雪の結晶の模様", "Snowflake patterned"),
        z(.winter, 1, .angel, "オーロラエンゼル", "Aurora Angel", "ひれに冬の空の光", "Winter sky light on its fins"),
        z(.winter, 2, .whale, "こおりジンベエ", "Ice Whale Shark", "氷のように透ける大きな体", "A great body, clear as ice"),
    ]

    static let all: [Species] = free + seasonal

    static func species(_ id: Int) -> Species { all.first { $0.id == id } ?? free[0] }

    static func species(band: Band, kind: WishKind) -> Species { free[band.rawValue * 6 + kind.rawValue] }

    /// 季節の魚（帯をそのまま使わず、小・中・大の 3 つに分ける）
    static func seasonal(_ season: Season, band: Band) -> Species {
        let size = min(band.rawValue, 2)
        return seasonal[season.rawValue * 3 + size]
    }

    /// 孵るときの魚。Pro なら 3 回に 1 回くらい季節の魚になる（卵ごとに決まる）
    static func pick(band: Band, kind: WishKind, eggSeed: UInt64, pro: Bool, season: Season) -> Species {
        if pro {
            var rng = SeededRNG(seed: eggSeed ^ 0x5EA5_0F15)
            if rng.unit() < 1.0 / 3.0 { return seasonal(season, band: band) }
        }
        return species(band: band, kind: kind)
    }
}
