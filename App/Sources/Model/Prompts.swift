import Foundation

/// 日本語と英語の組（手で用意した中身。gen-strings.py が String Catalog にも入れる）
struct T: Sendable, Hashable {
    let ja: String
    let en: String
    init(_ ja: String, _ en: String) {
        self.ja = ja
        self.en = en
    }

    var text: String { tr(ja, en) }
}

/// 卵を温めている間に出す「冷ます問い」。卵と日で 1 つ選ぶ（毎日ちがう問いになる）
enum CoolingPrompts {
    static let all: [T] = [
        T("それ、1 週間後も欲しい？", "Will you still want it next week?"),
        T("もう持っている物で、代わりにならない？", "Could something you own do the job?"),
        T("欲しくなったのは、疲れていたから？", "Did you want it because you were tired?"),
        T("それを使う場面を、3 つ言える？", "Can you name three times you'd use it?"),
        T("買ったあと、どこに置く？", "Where would it live once you own it?"),
        T("その金額は、何時間ぶんの働き？", "How many hours of work is that price?"),
        T("広告やおすすめで見かけたから？", "Did an ad or a feed put it in your head?"),
        T("セールが終わっても欲しい？", "Would you want it after the sale ends?"),
        T("同じ物を前にも買っていない？", "Have you bought something like it before?"),
        T("1 か月後の自分は、どっちを喜ぶ？", "Which would future-you thank you for?"),
        T("借りる・試す方法はない？", "Could you borrow it or try it first?"),
        T("夜ふかしの勢いで決めていない？", "Is this a late-night decision?"),
        T("それがなかった昨日、困った？", "Did you miss it yesterday?"),
        T("誰かに見せたいから欲しい？", "Do you want it, or want to show it?"),
        T("手に入れた瞬間の気分を想像してみて", "Picture the moment you get it. Then the day after"),
        T("その金額で、ほかに何ができる？", "What else could that money do?"),
        T("欲しい理由を一言で言うと？", "Why do you want it, in one word?"),
        T("お腹がすいているときに選んでいない？", "Are you shopping hungry?"),
        T("持っている物を 1 つ手放してでも欲しい？", "Would you give something up to make room?"),
        T("値段を見ずに選んでも、これを選ぶ？", "Would you pick it if price didn't show?"),
        T("今日は、深呼吸を 3 回してから決めよう", "Take three slow breaths before you decide"),
        T("その「欲しい」は、何色をしている？", "What color is this want, today?"),
        T("同じくらいうれしい、無料のことは？", "What free thing would feel just as good?"),
        T("1 年前の自分なら、欲しがった？", "Would you have wanted it a year ago?"),
        T("箱を開けたあとの片付けまで想像して", "Imagine unboxing it, then cleaning up after"),
        T("期間限定の言葉に急かされていない？", "Is a countdown rushing you?"),
        T("友だちに相談したら、なんて言われそう？", "What would a friend say about it?"),
        T("もし壊れたら、また買う？", "If it broke, would you buy it again?"),
        T("使う時間は、週に何時間ありそう？", "How many hours a week would you use it?"),
        T("それは、ずっと探していた物？", "Have you been looking for this for a while?"),
        T("欲しくなったのは、退屈だったから？", "Did boredom start this want?"),
        T("今月の自分に、ごほうびは足りてる？", "Has this month been short on treats?"),
        T("小さいサイズ・安い版では足りない？", "Would a smaller or cheaper one do?"),
        T("見た目のため？ 使うため？", "Is it for looks, or for use?"),
        T("待つ間に、値段が下がるかもしれない", "The price might drop while you wait"),
        T("この卵が孵ったら、どんな魚になりそう？", "What fish do you think this egg will be?"),
        T("待てた自分を、少しほめておこう", "Give yourself a little credit for waiting"),
        T("明日の朝、もう一度考えよう", "Think about it again tomorrow morning"),
        T("それがあると、毎日の何が変わる？", "What would change in your day with it?"),
        T("買わない日も、水槽は育つ", "Your tank grows on the days you don't buy"),
    ]

    static func pick(eggSeed: UInt64, dayKey: String) -> T {
        var h: UInt64 = eggSeed
        for b in dayKey.utf8 { h = (h ^ UInt64(b)) &* 0x100_0000_01B3 }
        return all[Int(h % UInt64(all.count))]
    }
}
