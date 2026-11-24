import SwiftUI

/// 待機點大時間開的整頁：滑刻度尺改這個標籤一顆多長。按「完成」才寫，按「取消」什麼都不變。
struct TimeDialScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var type: TagType

    @State private var minutes: Int

    init(type: TagType) {
        self.type = type
        _minutes = State(initialValue: Int(SettingsLogic.nearestLen(type.len)))
    }

    var body: some View {
        VStack(spacing: .zero) {
            TextButton(label: Words.cancel, tone: .secondary, flush: true) { dismiss() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.top, Tokens.Layout.item)
            Spacer(minLength: .zero)
            TomatoView(color: type.color, size: Tokens.Shape.celebrateTomato)
            Text(type.name)
                .font(Tokens.Fonts.title3)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.top, Tokens.Layout.item)
            number
                .padding(.top, Tokens.Layout.section)
            MinuteRuler(minutes: $minutes)
                .padding(.top, Tokens.Layout.item)
            DialPointer()
                .fill(Tokens.Colors.accent)
                .frame(width: Tokens.Dial.pointerWidth, height: Tokens.Dial.pointerHeight)
                .padding(.top, Tokens.Layout.item)
                .accessibilityHidden(true)
            Spacer(minLength: .zero)
            BigButton(label: Words.dialDone, action: done)
                .frame(width: Tokens.Dial.doneWidth)
                .padding(.bottom, Tokens.Layout.section)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Colors.background.ignoresSafeArea())
    }

    /// 選中的幾分鐘。滑的時候要跟手，數字直接換、不滾動；讀屏由刻度尺念。
    private var number: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Layout.tight) {
            Text(String(minutes))
                .font(Tokens.Fonts.clockFocus)
                .foregroundStyle(Tokens.Colors.accentText)
            Text(Words.minuteUnit)
                .font(Tokens.Fonts.title3)
                .foregroundStyle(Tokens.Colors.textSecondary)
        }
        .accessibilityHidden(true)
    }

    private func done() {
        model.setTypeLen(type.id, len: Double(minutes))
        dismiss()
    }
}

/// 刻度尺正下方指著選中那格的三角形。
struct DialPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
