import SwiftUI

/// 「欲しい」を卵にする（5 秒で終わる：金額 → 種類 → 置く。名前は任意）
struct AddWishSheet: View {
    @Environment(AppModel.self) private var model
    @FocusState private var nameFocused: Bool

    var body: some View {
        @Bindable var model = model
        let amount = model.draft.amount
        let band = Band.of(amount: amount, scale: model.scale)
        let hours = TankState.coolingHours(amount: max(amount, 1), scale: model.scale, baseHours: model.isPro ? model.coolingHours : TankState.defaultCoolingHours)
        VStack(spacing: 0) {
            HStack {
                Text(tr("欲しい物を卵にする", "Turn a want into an egg")).font(Fonts.title(19)).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Button { model.press(); model.activeSheet = nil } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).frame(width: 44, height: 44)
                }
                .buttonStyle(GlassButtonStyle())
                .accessibilityLabel(tr("閉じる", "Close"))
                .accessibilityIdentifier("main.close")
            }
            .padding(.horizontal, 20).padding(.top, 18)

            ScrollView {
                VStack(spacing: 16) {
                    // 金額と、生まれる予定の魚
                    VStack(spacing: 6) {
                        Text(amount > 0 ? model.format(amount) : model.format(0))
                            .font(Fonts.number(46)).kerning(-1.5)
                            .foregroundStyle(amount > 0 ? Ink.text : Ink.faint)
                            .contentTransition(.numericText())
                            .lineLimit(1).minimumScaleFactor(0.5)
                        HStack(spacing: 10) {
                            FishPortrait(species: SpeciesBook.species(band: band, kind: model.draft.kind), hidden: amount == 0)
                                .frame(width: 54, height: 34)
                            Text(amount > 0
                                 ? trf("%@ になる予定・%d 時間 冷ます", "Will hatch a %@ · cools %dh", band.name, hours)
                                 : tr("金額を入れると、生まれる魚が決まる", "Enter a price to see which fish it becomes"))
                                .font(Fonts.body(13)).foregroundStyle(Ink.soft).lineLimit(1).minimumScaleFactor(0.65)
                        }
                    }
                    .padding(.top, 6)

                    // 種類（魚の色になる）
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(WishKind.allCases) { kind in
                            let on = model.draft.kind == kind
                            Button {
                                model.pressTick += 1
                                model.draft.kind = kind
                            } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(Color(hex: kind.colors.body)).frame(width: 9, height: 9)
                                    Image(systemName: kind.symbol).font(.system(size: 12))
                                    Text(kind.name).font(Fonts.label(12)).lineLimit(1).minimumScaleFactor(0.6)
                                }
                                .foregroundStyle(on ? Color(hex: 0x0A1A33) : Ink.text)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).fill(on ? Color(hex: kind.colors.body) : Ink.glass))
                                .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).strokeBorder(on ? Color.white.opacity(0.6) : Ink.glassLine, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("main.kind\(kind.rawValue)")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }

                    TextField(text: $model.draft.name, prompt: Text(tr("名前（なくてもいい）", "Name (optional)")).foregroundStyle(Ink.faint)) { EmptyView() }
                        .font(Fonts.body(15)).foregroundStyle(Ink.text)
                        .padding(.horizontal, 14).frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).fill(Ink.glass))
                        .focused($nameFocused)
                        .submitLabel(.done)
                    if model.tank.isFull {
                        Text(tr("砂の上は卵でいっぱい。孵すか、正直に「買った」を押そう", "The sand is full of eggs. Hatch one, or mark one as bought"))
                            .font(Fonts.body(12)).foregroundStyle(Ink.warm)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 12)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !nameFocused { keypad(amount: amount) }
        }
        .background(LinearGradient(colors: [Ink.sheetLow, Ink.sheet], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: model.draft.kind)
    }

    private func keypad(amount: Int) -> some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "00", "0", "del"]
        return VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(keys, id: \.self) { k in
                    Button { model.key(k) } label: {
                        Group {
                            if k == "del" { Image(systemName: "delete.left").font(.system(size: 18)) } else { Text(k).font(Fonts.number(24)) }
                        }
                        .foregroundStyle(Ink.text)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(KeyStyle())
                    .accessibilityLabel(k == "del" ? tr("1 文字けす", "Delete") : k)
                    .accessibilityIdentifier("main.key\(k)")
                }
            }
            Button {
                model.placeDraft()
            } label: {
                HStack(spacing: 8) {
                    EggShape().fill(Color(hex: 0x1A1020).opacity(0.7)).frame(width: 13, height: 17)
                    Text(tr("卵を置いて、冷ます", "Place the egg & wait")).font(Fonts.title(17)).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity).frame(height: 54)
            }
            .buttonStyle(GlassButtonStyle(tint: Ink.warm, prominent: true))
            .disabled(amount == 0 || model.tank.isFull)
            .opacity(amount == 0 ? 0.5 : 1)
            .accessibilityIdentifier("main.place")
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(Ink.sheet)
    }
}

struct KeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .brightness(configuration.isPressed ? 0.12 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
