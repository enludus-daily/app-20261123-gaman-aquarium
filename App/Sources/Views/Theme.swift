import SwiftUI

// 世界観：夜のアクアリウム。深い藍〜青緑の水、上から差すゆらぐ光の筋、ぼんやり光る魚とクラゲ、底の白い砂と小さな泡。
// 「このアプリでは〔欲しい物〕が〔水槽の底の卵〕になり、〔我慢した金額〕が〔光る魚〕になる」。
// うおさがし（11/18、昼の水面・数字の盤）とは、夜・光る・ゆっくり・丸い細い書体で分ける。

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// 水槽の見た目（夜のアクアリウムは無料、ほか 3 つは Pro）
enum TankTheme: String, Codable, CaseIterable, Sendable, Identifiable {
    case night, reef, deep, river

    var id: String { rawValue }
    var isPro: Bool { self != .night }

    var name: String {
        switch self {
        case .night: tr("夜のアクアリウム", "Night aquarium")
        case .reef: tr("夜の礁", "Night reef")
        case .deep: tr("深海", "Deep sea")
        case .river: tr("熱帯の川", "Jungle river")
        }
    }

    var palette: TankPalette {
        switch self {
        case .night:
            TankPalette(waterTop: 0x123B5E, waterMid: 0x0B2546, waterBottom: 0x06142B, light: 0xA6ECFF,
                        sand: 0x6F8599, sandLit: 0xB9CCDA, plant: 0x1F6A6A, plantTip: 0x5FC6B5, rock: 0x22344A, jelly: 0xC7B8FF)
        case .reef:
            TankPalette(waterTop: 0x18506E, waterMid: 0x0F3352, waterBottom: 0x0A1C33, light: 0xFFDDA8,
                        sand: 0x9C8A74, sandLit: 0xE5D3B8, plant: 0xB85A72, plantTip: 0xFFA0B4, rock: 0x3A3246, jelly: 0xFFC2A8)
        case .deep:
            TankPalette(waterTop: 0x0D1438, waterMid: 0x070B26, waterBottom: 0x020414, light: 0x7C8CFF,
                        sand: 0x2E3352, sandLit: 0x5A6090, plant: 0x2B2A66, plantTip: 0x8A7CFF, rock: 0x14183A, jelly: 0x7CF0FF)
        case .river:
            TankPalette(waterTop: 0x24685A, waterMid: 0x164237, waterBottom: 0x0A231D, light: 0xEEFFB8,
                        sand: 0x7D6C4C, sandLit: 0xC8B489, plant: 0x2F7A3E, plantTip: 0x9BE07A, rock: 0x2E3A2A, jelly: 0xF4FFC2)
        }
    }
}

struct TankPalette: Sendable {
    var waterTop: UInt32
    var waterMid: UInt32
    var waterBottom: UInt32
    var light: UInt32
    var sand: UInt32
    var sandLit: UInt32
    var plant: UInt32
    var plantTip: UInt32
    var rock: UInt32
    var jelly: UInt32
}

/// 画面の文字と部品の色（夜の水の上に置くガラス）
enum Ink {
    /// 文字（真っ白にしない。少し青い）
    static let text = Color(hex: 0xE9F6FB)
    static let soft = Color(hex: 0x9DB8C9)
    static let faint = Color(hex: 0x6F8BA0)
    /// 卵とあたたかい光（強調はオレンジ寄り）
    static let warm = Color(hex: 0xFFB48A)
    static let warmDeep = Color(hex: 0xE07A4E)
    /// 冷たい光（選択・進み）
    static let glow = Color(hex: 0x7FE6E2)
    static let glowDeep = Color(hex: 0x2E9C9E)
    /// 泡（買った卵）。責めない色にする
    static let bubble = Color(hex: 0xBFD7EA)
    static let glass = Color.white.opacity(0.08)
    static let glassLine = Color.white.opacity(0.2)
    /// シートの地（水の奥の色）
    static let sheet = Color(hex: 0x0A1A33)
    static let sheetLow = Color(hex: 0x0E2442)
}

/// 書体：細めの丸いサンセリフ（水の中のやわらかさ）、数字は等幅
enum Fonts {
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func light(_ size: CGFloat) -> Font { .system(size: size, weight: .light, design: .rounded) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .light, design: .rounded).monospacedDigit() }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

enum Radius {
    static let chip: CGFloat = 14
    static let panel: CGFloat = 22
    static let sheet: CGFloat = 30
}

/// ガラスの丸いボタン（押すと少し沈んで、光がにじむ）
struct GlassButtonStyle: ButtonStyle {
    var tint: Color = Ink.glow
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color(hex: 0x1A1020) : Ink.text)
            .background(
                Capsule(style: .continuous)
                    .fill(prominent ? AnyShapeStyle(tint) : AnyShapeStyle(Ink.glass))
            )
            .overlay(Capsule(style: .continuous).strokeBorder(prominent ? Color.white.opacity(0.5) : Ink.glassLine, lineWidth: 1))
            .shadow(color: tint.opacity(prominent ? 0.55 : 0.0), radius: configuration.isPressed ? 6 : 14)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 卵の形（主なボタン・卵の絵）
struct EggShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let x = r.minX, y = r.minY
        p.move(to: CGPoint(x: x + w / 2, y: y))
        p.addCurve(to: CGPoint(x: x + w, y: y + h * 0.62), control1: CGPoint(x: x + w * 0.83, y: y), control2: CGPoint(x: x + w, y: y + h * 0.33))
        p.addCurve(to: CGPoint(x: x + w / 2, y: y + h), control1: CGPoint(x: x + w, y: y + h * 0.86), control2: CGPoint(x: x + w * 0.78, y: y + h))
        p.addCurve(to: CGPoint(x: x, y: y + h * 0.62), control1: CGPoint(x: x + w * 0.22, y: y + h), control2: CGPoint(x: x, y: y + h * 0.86))
        p.addCurve(to: CGPoint(x: x + w / 2, y: y), control1: CGPoint(x: x, y: y + h * 0.33), control2: CGPoint(x: x + w * 0.17, y: y))
        p.closeSubpath()
        return p
    }
}

/// 小さなラベル（字間を開ける）
struct Caption: View {
    var text: String
    var color: Color = Ink.soft
    var body: some View {
        Text(text).font(Fonts.label(11)).kerning(0.8).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
    }
}

/// シートの共通の枠（夜の水の地・閉じるボタン）
struct SheetFrame<Content: View>: View {
    @Environment(AppModel.self) private var model
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(Fonts.title(20)).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Button {
                    model.press()
                    model.activeSheet = nil
                } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(GlassButtonStyle())
                .accessibilityLabel(tr("閉じる", "Close"))
                .accessibilityIdentifier("main.close")
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8)
            ScrollView {
                content.padding(.horizontal, 20).padding(.bottom, 28)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(
            LinearGradient(colors: [Ink.sheetLow, Ink.sheet], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        )
    }
}
