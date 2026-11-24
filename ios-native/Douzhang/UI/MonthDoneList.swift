import SwiftUI

/// 番茄架的月檢視：上面一格一天的格子，下面這個月做了什麼。整個月沒番茄就只有格子。
struct RackMonth: View {
    var state: AppState
    /// 這個月裡任一天的日期鍵
    var monthKey: String
    var todayKey: String
    /// 點了格子裡的某一天
    var onPickDay: (String) -> Void
    /// 點了清單上的某一天
    var onOpen: (String) -> Void

    var body: some View {
        let days = MonthDone.days(state, key: monthKey)
        VStack(alignment: .leading, spacing: Tokens.Layout.section) {
            MonthGrid(state: state, monthKey: monthKey, todayKey: todayKey, onPickDay: onPickDay)
            if !days.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Layout.item) {
                    Text(Words.doneTitle(monthKey, todayKey: todayKey))
                        .font(Tokens.Fonts.title3)
                        .foregroundStyle(Tokens.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: Tokens.Layout.group) {
                        ForEach(days, id: \.key) { day in
                            DoneCard(day: day) { onOpen(day.key) }
                        }
                    }
                }
            }
        }
    }
}

/// 清單上的一天：左邊日期塊（底色是那天最多分鐘的標籤色），中間做了什麼與那天寫的第一句，右邊幾顆多久。
/// 樣式照蒜日子清單的 UpcomingCardView。
struct DoneCard: View {
    var day: DoneDay
    var action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Shape.radiusCard)
        Button(action: action) {
            HStack(spacing: Tokens.Layout.group) {
                dateBlock
                VStack(alignment: .leading, spacing: Tokens.Layout.tight) {
                    headline
                    if !day.clue.isEmpty {
                        Text(day.clue)
                            .font(Tokens.Fonts.caption)
                            .foregroundStyle(Tokens.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Tokens.Layout.rowPadV)
            .padding(.horizontal, Tokens.Layout.cardPad)
            .background(Tokens.Colors.card, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Words.doneA11y(day))
    }

    /// 主字與右邊的幾顆多久。字放到無障礙那幾級時一列排不下，改成上下兩行。
    private var headline: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Tokens.Layout.tight))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Tokens.Layout.group))
        return layout {
            Text(Words.doneNames(day.names))
                .font(Tokens.Fonts.bodyStrong)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Words.daySumLine(day.sum.beans, day.sum.minutes))
                .font(Tokens.Fonts.caption)
                .foregroundStyle(Tokens.Colors.textSecondary)
                .layoutPriority(1)
        }
    }

    private var dateBlock: some View {
        VStack(spacing: .zero) {
            Text(String(Int(day.key.suffix(2)) ?? 0)).font(Tokens.Fonts.section)
            Text(Words.weekdayCompact(day.key)).font(Tokens.Fonts.tab)
        }
        .lineLimit(1)
        // 塊的大小固定，字再放大就超出去；整張卡的字讀屏都念得到
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .foregroundStyle(Tokens.Tomato.onBody(day.color).color)
        .frame(width: Tokens.Rack.doneBlock, height: Tokens.Rack.doneBlock)
        .background(
            Tokens.Tomato.body(day.color).color,
            in: RoundedRectangle(cornerRadius: Tokens.Shape.radiusButton)
        )
    }
}
