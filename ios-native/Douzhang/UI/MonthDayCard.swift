import SwiftUI

/// 番茄架的月檢視：上面一格一天的格子，下面選中那一天做了什麼。
struct RackMonth: View {
    var state: AppState
    /// 選中的日子：格子畫它那個月，下面那塊寫它那天
    var selected: String
    var todayKey: String
    /// 點了格子裡的某一天
    var onPickDay: (String) -> Void
    /// 點了下面那塊的一列
    var onOpen: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Layout.section) {
            MonthGrid(state: state, selected: selected, todayKey: todayKey, onPickDay: onPickDay)
            MonthDayCard(state: state, dayKey: selected, todayKey: todayKey) { onOpen(selected) }
        }
    }
}

/// 選中那一天的一張卡：日期與幾顆多久，下面一顆番茄一列，由早到晚。
/// 今天還沒有番茄就只有日期，不寫 0、不催；格子上掛葉子的日子照收據上那句，還沒開始用的日子也只有日期。
/// 樣式照蒜日子點開某一天的那張卡。
struct MonthDayCard: View {
    var state: AppState
    var dayKey: String
    var todayKey: String
    var onOpen: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let beans = MonthBoard.beans(state, key: dayKey)
        VStack(alignment: .leading, spacing: Tokens.Layout.group) {
            heading
            if beans.isEmpty {
                if MonthBoard.hasLeaf(
                    state,
                    key: dayKey,
                    todayKey: todayKey,
                    since: MonthBoard.firstKept(state)
                ) {
                    Text(Words.leafDay)
                        .font(Tokens.Fonts.body)
                        .foregroundStyle(Tokens.Colors.textSecondary)
                }
            } else {
                VStack(spacing: Tokens.Layout.item) {
                    ForEach(Array(beans.enumerated()), id: \.offset) { entry in
                        let item = entry.element
                        MonthBeanRow(
                            item: item,
                            type: Machine.typeOf(state, item.typeId),
                            action: onOpen
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Layout.cardPad)
        .background(
            Tokens.Colors.card,
            in: RoundedRectangle(cornerRadius: Tokens.Shape.radiusCard)
        )
    }

    /// 日期與幾顆多久。字放到無障礙那幾級時一列排不下，改成上下兩行。
    private var heading: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Tokens.Layout.tight))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Tokens.Layout.item))
        return layout {
            Text(Words.dayHead(dayKey))
                .font(Tokens.Fonts.title3)
                .foregroundStyle(Tokens.Colors.textPrimary)
            if let sum = Receipt.daySum(state.days[dayKey]) {
                Text(Words.daySumLine(sum.beans, sum.minutes))
                    .font(Tokens.Fonts.sub)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 那天的一顆番茄：標籤色底，左邊開始的時刻，中間標籤名、在做什麼、專注筆記，右邊多長。
/// 跟時間軸的方塊一樣以標籤名為主（多米 2026-11-27）。
struct MonthBeanRow: View {
    var item: TimelineItem
    var type: TagType
    var action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var name: String {
        type.name
    }

    var body: some View {
        // 字放到無障礙那幾級時三樣排不進一列，改成上下排
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Tokens.Layout.tight))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Tokens.Layout.group))
        let shape = RoundedRectangle(cornerRadius: Tokens.Shape.radiusButton)
        Button(action: action) {
            layout {
                Text(TimeText.hhmm(item.start))
                    .font(Tokens.Fonts.sub.monospacedDigit())
                    .fixedSize()
                words
                Text(Words.lenWithFlow(item.len, flow: item.flow))
                    .font(Tokens.Fonts.sub)
                    .fixedSize()
            }
            .foregroundStyle(Tokens.Tomato.onBody(type.color).color)
            .padding(.vertical, Tokens.Layout.rowPadV)
            .padding(.horizontal, Tokens.Layout.cardPad)
            .frame(maxWidth: .infinity, minHeight: Tokens.Shape.tapMin, alignment: .leading)
            .background(Tokens.Tomato.body(type.color).color, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Words.monthBeanA11y(item, name: name))
    }

    /// 每樣最多兩行，筆記再長也只露兩行，結尾「…」。
    private var words: some View {
        VStack(alignment: .leading, spacing: Tokens.Layout.tight) {
            Text(name).font(Tokens.Fonts.bodyStrong)
            if !item.doing.isEmpty {
                Text(item.doing).font(Tokens.Fonts.sub)
            }
            if !item.clue.isEmpty {
                Text(item.clue).font(Tokens.Fonts.caption)
            }
        }
        .multilineTextAlignment(.leading)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
