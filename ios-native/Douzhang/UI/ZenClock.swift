import SwiftUI

/// 聚焦模式的大時鐘：分、番茄、秒。聚焦模式與付費頁的預覽用同一份排版。
/// 兩個數字各佔番茄旁邊一樣寬的一塊、靠著番茄排，換秒時番茄不會左右動。
/// 字級照整個畫面的寬；放不下（安全區、分鐘有三位）就縮到剛好。
struct ZenClock<Tomato: View>: View {
    var parts: (minutes: String, seconds: String)
    /// 整個畫面多寬
    var screen: CGFloat
    /// 扣掉左右安全區剩多寬
    var width: CGFloat
    var gap = Tokens.Layout.section
    /// 全熟大小的那顆番茄
    @ViewBuilder var tomato: (CGFloat) -> Tomato

    var body: some View {
        let fruit = min(Tokens.ZenLayout.tomatoMax, screen * Tokens.ZenLayout.tomato)
        let room = max(0, (width - fruit) / 2 - gap)
        let digits = CGFloat(max(parts.minutes.count, parts.seconds.count))
        let size = min(
            screen * Tokens.ZenLayout.digit,
            room / (digits * Tokens.Fonts.zenDigitWidth)
        )
        HStack(spacing: gap) {
            number(parts.minutes, size: size)
                .frame(width: room, alignment: .trailing)
            tomato(fruit)
            number(parts.seconds, size: size)
                .frame(width: room, alignment: .leading)
        }
    }

    private func number(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(Tokens.Fonts.zenDigit(size))
            .foregroundStyle(Tokens.Zen.digit)
            .modifier(NumberChange(value: text, countsDown: true))
            .fixedSize()
            .frame(height: size * Tokens.ZenLayout.digitRow)
    }
}
