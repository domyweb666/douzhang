import SwiftUI

/// 葉子：一片斜放的圓角葉形，沒有數字、沒有空格。
struct LeafMark: View {
    var body: some View {
        let dot = Tokens.Shape.podDot
        UnevenRoundedRectangle(topLeadingRadius: dot, bottomTrailingRadius: dot)
            .fill(Tokens.Tomato.leafSoft)
            .frame(width: dot * 2, height: dot)
            .rotationEffect(.degrees(Tokens.Rack.leafTilt))
            .accessibilityLabel(Words.leafA11y)
    }
}

/// 番茄架的月檢視：一格一天，裡面是那天收下的番茄（一顆一個標籤色的小圓點）。
/// 沒番茄的週壓扁成一行，只剩日期，整個月不會出現一排排空格子（沒番茄的日子不寫 0）。
/// 過完、沒番茄的日子掛一片葉子，不算缺；壓扁的週不畫葉子，畫了那列就撐開。點一天就切到那天的天檢視。
struct MonthGrid: View {
    var state: AppState
    /// 這個月裡任一天的日期鍵
    var monthKey: String
    var todayKey: String
    var onPickDay: (String) -> Void

    var body: some View {
        VStack(spacing: .zero) {
            HStack(spacing: .zero) {
                ForEach(Words.weekdayShort, id: \.self) { name in
                    Text(name)
                        .font(Tokens.Fonts.caption)
                        .foregroundStyle(Tokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            let weeks = RackCalendar.monthWeeks(state, key: monthKey, todayKey: todayKey)
            ForEach(weeks, id: \.weekStart) { week in
                HStack(alignment: .top, spacing: .zero) {
                    ForEach(week.days, id: \.key) { day in
                        cell(day, busy: week.busy)
                    }
                }
                .frame(
                    minHeight: week.busy ? Tokens.Rack.monthWeek : Tokens.Rack.monthWeekFlat,
                    alignment: .top
                )
                .overlay(alignment: .top) {
                    Tokens.Colors.separator.frame(height: Tokens.Shape.hairline)
                }
            }
        }
        .padding(.top, Tokens.Layout.group)
    }

    /// 一格：日期（今天有產品色淡底）＋那天的番茄。別的月份的日子只寫淡淡的日期；還沒到的日子不能點。
    private func cell(_ day: MonthDay, busy: Bool) -> some View {
        let isToday = day.key == todayKey
        let isDim = !day.inMonth || day.key > todayKey
        let ink = isDim ? Tokens.Colors.textTertiary : Tokens.Colors.textPrimary
        return Button {
            onPickDay(day.key)
        } label: {
            VStack(spacing: Tokens.Layout.tight) {
                Text(String(Int(day.key.suffix(2)) ?? 0))
                    .font(Tokens.Fonts.caption)
                    .foregroundStyle(isToday ? Tokens.Colors.accentText : ink)
                    .padding(.horizontal, Tokens.Layout.item)
                    .background(isToday ? Tokens.Colors.soft : .clear, in: Capsule())
                if busy, !day.beans.isEmpty {
                    dots(day.beans)
                }
                if busy, day.leaf {
                    LeafMark()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Layout.tight)
            .contentShape(Rectangle())
        }
        .buttonStyle(FadeStyle())
        .disabled(isDim)
        .accessibilityLabel(
            Words.monthDayA11y(day.key, beans: day.beans.count, leaf: busy && day.leaf)
        )
    }

    /// 那天的番茄：依時間排，最多畫 monthDotsMax 顆，再多寫「+N」。
    private func dots(_ beans: [Bean]) -> some View {
        let shown = beans.stableSorted { $0.keptAt }.prefix(Params.monthDotsMax)
        let more = beans.count - shown.count
        return FlowRow(spacing: Tokens.Rack.timelineLaneGap, centered: true) {
            ForEach(Array(shown.enumerated()), id: \.offset) { item in
                let type = Machine.typeOf(state, item.element.typeId)
                Circle()
                    .fill(Tokens.Tomato.body(type.color).color)
                    .overlay {
                        Circle().stroke(Tokens.Tomato.ink.color, lineWidth: Tokens.Shape.hairline)
                    }
                    .frame(width: Tokens.Rack.monthDot, height: Tokens.Rack.monthDot)
            }
            if more > 0 {
                Text(Words.moreBeans(more))
                    .font(Tokens.Fonts.tab)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
        }
    }
}
