import SwiftUI

/// 按下的回饋（照 Domy）：縮一點；開了「減少動態」就改成變淡。
struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .scaleEffect(pressed && !reduceMotion ? Tokens.Motion.pressScale : 1)
            .opacity(pressed && reduceMotion ? Tokens.Opacity.pressed : 1)
            .animation(Tokens.Motion.press, value: pressed)
    }
}

/// 按下只變淡（文字鈕、半頁裡的列）。
struct FadeStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? Tokens.Opacity.pressed : 1)
    }
}

/// 滿版膠囊按鈕。主要的＝茄紫底，每個畫面只出現一次；second＝中性填色底。
/// 按了不震：震動只留給有意義的那幾刻（收下、拿掉東西、出錯），由 RootView 統一發。
struct BigButton: View {
    var label: String
    var second = false
    var disabled = false
    var action: () -> Void

    private var background: Color {
        disabled || second ? Tokens.Colors.fillButton : Tokens.Colors.accent
    }

    private var foreground: Color {
        if disabled {
            return Tokens.Colors.disabledText
        }
        return second ? Tokens.Colors.textPrimary : Tokens.Colors.onAccent
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Tokens.Fonts.button)
                .lineLimit(1)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: Tokens.Shape.tapPrimary)
                .padding(.horizontal, Tokens.Space.l)
                .background(background, in: Capsule())
        }
        .buttonStyle(PressStyle())
        .disabled(disabled)
    }
}

/// 文字鈕的三種口氣：產品色（可點的連結）、次要色（退讓的動作）、紅字（只有清空與刪除）。
enum TextTone {
    case accent, secondary, danger
}

/// 文字鈕：至少 44pt 高。flush＝貼齊左邊，不加左右內距。
struct TextButton: View {
    var label: String
    var tone = TextTone.accent
    var flush = false
    var a11yLabel: String?
    var action: () -> Void

    private var color: Color {
        switch tone {
        case .accent: Tokens.Colors.accentText
        case .secondary: Tokens.Colors.textSecondary
        case .danger: Tokens.Colors.danger
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(tone == .secondary ? Tokens.Fonts.body : Tokens.Fonts.bodyStrong)
                .foregroundStyle(color)
                .frame(minHeight: Tokens.Shape.tapMin)
                .padding(.horizontal, flush ? .zero : Tokens.Space.m)
                .contentShape(Rectangle())
        }
        .buttonStyle(FadeStyle())
        .accessibilityLabel(a11yLabel ?? label)
    }
}

/// 小顆的茄紫膠囊鈕（番茄架空狀態的鈕）。
struct CompactButton: View {
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Tokens.Fonts.chip)
                .foregroundStyle(Tokens.Colors.onAccent)
                .frame(minHeight: Tokens.Shape.buttonCompact)
                .padding(.horizontal, Tokens.Space.card)
                .background(Tokens.Colors.accent, in: Capsule())
        }
        .buttonStyle(PressStyle())
    }
}

/// 淡底膠囊鈕，高度夠手指按（計時中右上的「結束」）。
struct SoftPill: View {
    var label: String
    var a11yLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Tokens.Fonts.chip)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .lineLimit(1)
                .frame(minHeight: Tokens.Shape.tapMin)
                .padding(.horizontal, Tokens.Layout.cardPad)
                .background(Tokens.Colors.fillButton, in: Capsule())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(a11yLabel)
    }
}
