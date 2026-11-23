import SwiftUI

/// 案内 3 ページ（自前のページ送り。TabView(.page) は撮影で黒い丸の原因になる）
struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let page = model.onboardingPage
        VStack(spacing: 0) {
            ZStack {
                TankThumbnail(theme: .night, fish: page == 2 ? sampleFish : [], t: 1000 + Double(page) * 7)
                    .opacity(0.9)
                    .ignoresSafeArea()
                LinearGradient(colors: [.clear, Ink.sheet.opacity(0.95)], startPoint: .center, endPoint: .bottom).ignoresSafeArea()
                VStack(spacing: 18) {
                    Spacer(minLength: 20)
                    illustration(page)
                        .frame(height: 170)
                    VStack(spacing: 10) {
                        Text(title(page)).font(Fonts.title(26)).foregroundStyle(Ink.text)
                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                        Text(detail(page)).font(Fonts.body(15)).foregroundStyle(Ink.soft)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 28)
                    Spacer(minLength: 10)
                }
                .frame(maxWidth: 560)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule().fill(i == page ? Ink.glow : Color.white.opacity(0.2)).frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                if page < 2 {
                    Button {
                        model.press()
                        withAnimation(.easeOut(duration: 0.3)) { model.onboardingPage += 1 }
                    } label: {
                        Text(tr("次へ", "Next")).font(Fonts.title(17)).frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .buttonStyle(GlassButtonStyle(tint: Ink.glow, prominent: true))
                    .accessibilityIdentifier("main.onboardNext")
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.35)) { model.finishOnboarding() }
                    } label: {
                        Text(tr("水槽をはじめる", "Open my tank")).font(Fonts.title(17)).frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .buttonStyle(GlassButtonStyle(tint: Ink.warm, prominent: true))
                    .accessibilityIdentifier("main.onboardStart")
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 10).padding(.top, 8)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .background(Ink.sheet.ignoresSafeArea(edges: .bottom))
        }
        .background(Ink.sheet.ignoresSafeArea())
    }

    private var sampleFish: [Fish] {
        Launch.sampleFish(now: model.now)
    }

    private func title(_ page: Int) -> String {
        switch page {
        case 0: tr("欲しい、と思ったら\n卵を置く", "Want something?\nPlace an egg")
        case 1: tr("待てたら、その金額の\n魚が生まれる", "Wait it out, and it hatches\ninto a fish")
        default: tr("買っても責めない。\n卵が泡になるだけ", "Bought it anyway?\nThe egg just turns to bubbles")
        }
    }

    private func detail(_ page: Int) -> String {
        switch page {
        case 0: tr("名前と金額と種類を入れるだけ。卵は 48 時間（大きな欲しい物は 72 時間）温まる。", "Just a price and a category. The egg cools for 48 hours — 72 for big wants.")
        case 1: tr("金額で魚が決まる。待てた合計が、水槽の底の目盛りに積もっていく。", "The price decides the fish. Everything you wait out adds up on the sand gauge.")
        default: tr("孵った翌日に見に来ると、魚はえさを食べて大きくなる。金額はこの iPhone の中だけ。銀行やカードとはつながらない。", "Visit the day after a hatch to feed your fish and watch them grow. Prices stay on this iPhone — no bank or card links.")
        }
    }

    @ViewBuilder
    private func illustration(_ page: Int) -> some View {
        switch page {
        case 0:
            HStack(spacing: 22) {
                ForEach(0..<3) { i in
                    let kind = [WishKind.food, .gadget, .clothes][i]
                    VStack(spacing: 8) {
                        EggShape()
                            .fill(LinearGradient(colors: [.white.opacity(0.6), Color(hex: kind.colors.body).opacity(0.6), Ink.warm.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                            .overlay(EggShape().stroke(.white.opacity(0.6), lineWidth: 1))
                            .frame(width: 46 + CGFloat(i) * 8, height: 60 + CGFloat(i) * 10)
                            .shadow(color: Ink.warm.opacity(0.5), radius: 14)
                        Text(Money.format([680, 12800, 4200][i], code: "JPY")).font(Fonts.number(13)).foregroundStyle(Ink.text)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
            }
        case 1:
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Band.allCases, id: \.self) { band in
                    VStack(spacing: 6) {
                        FishPortrait(species: SpeciesBook.species(band: band, kind: [WishKind.conbini, .food, .gadget, .game][band.rawValue]))
                            .frame(width: 40 + CGFloat(band.rawValue) * 16, height: 30 + CGFloat(band.rawValue) * 14)
                        Text(band.name).font(Fonts.label(11)).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.5)
                        Text(band.rangeLabel(scale: model.scale, code: model.currency)).font(Fonts.number(10)).foregroundStyle(Ink.soft)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
        default:
            HStack(spacing: 30) {
                VStack(spacing: 6) {
                    ZStack {
                        ForEach(0..<5) { i in
                            Circle().stroke(Ink.bubble.opacity(0.7), lineWidth: 1)
                                .frame(width: CGFloat(10 + i * 5), height: CGFloat(10 + i * 5))
                                .offset(x: CGFloat([-16, 12, -4, 18, -20][i]), y: CGFloat(-i * 18))
                        }
                    }
                    .frame(width: 80, height: 110)
                    Caption(text: tr("泡", "Bubbles").uppercased())
                }
                VStack(spacing: 6) {
                    FishPortrait(species: SpeciesBook.species(band: .manta, kind: .other)).frame(width: 110, height: 90)
                    Caption(text: tr("えさで大きく", "FEED TO GROW"))
                }
            }
        }
    }
}
