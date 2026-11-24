import SwiftUI

/// 番茄架的分析：一張回答一題，標題就是那一題（.analytics/06-三層結構.md 的細查層）。
/// 第一張「這段時間花在哪」：每個標籤一條橫條，下面一行專注多久、收了幾顆；換這週、這個月的那排在卡片下面。
/// 第二張「這兩週記了什麼、作廢的原因」：固定看最近 14 天，兩句計數，下面一顆一段。
/// 只陳述：不跟上一段比、沒有百分比、沒有紅字。數字都是 Core 算的，這裡只畫。
struct StatsPanel<Footer: View>: View {
    var state: AppState
    var range: StatsRange
    /// 這一段裡的任一天
    var selected: String
    /// 這一段叫什麼：「這週」「這個月」，或某一段的名字
    var period: String
    /// 換這週、這個月與前後翻的那排
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: Tokens.Layout.group) {
            whereCard(Stats.stats(state, keys: Stats.rangeDays(range, selected: selected)))
            jotCard(Insights.jotTally(state, now: TimeText.nowMillis()))
        }
        .padding(.top, Tokens.Layout.section)
    }

    /// 第一張：這段時間花在哪幾種事上。
    private func whereCard(_ result: StatsResult) -> some View {
        let longest = max(1, result.tags.map(\.minutes).max() ?? 1)
        return VStack(alignment: .leading, spacing: Tokens.Space.m) {
            StatsTitle(text: Words.whereTitle(period))
            if result.tags.isEmpty {
                StatsNote(text: Words.statsEmpty)
            } else {
                ForEach(result.tags, id: \.type.id) { tag in
                    tagRow(tag, longest: longest)
                }
                let fact = Words.focusFact(period, minutes: result.minutes, beans: result.beans)
                StatsNote(text: fact)
                    .modifier(NumberChange(value: fact))
            }
            footer
        }
        .modifier(StatsCard())
    }

    /// 一個標籤一列：小番茄、名字、右邊多久與幾顆；下面一條橫條。
    /// 橫條的長度是專注時間，都從左邊開始，最長的那條頂到底；沒有底條（不是要填滿的進度）。
    private func tagRow(_ tag: StatsTag, longest: Double) -> some View {
        let name = tag.removed ? Words.removedName(tag.type.name) : tag.type.name
        let amount = Words.tagAmount(tag.minutes, beans: tag.beans)
        return VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack(spacing: Tokens.Space.s) {
                TomatoView(color: tag.type.color, size: Tokens.Shape.blockIcon * 1.5)
                Text(name)
                    .font(Tokens.Fonts.sub)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: Tokens.Space.s)
                Text(amount)
                    .font(Tokens.Fonts.caption)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(Tokens.Tomato.body(tag.type.color).color)
                    .frame(width: barWidth(tag.minutes / longest, room: proxy.size.width))
            }
            .frame(height: Tokens.Rack.statsShare)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name)，\(amount)")
    }

    /// 再短也留一個圓點那麼寬，才看得到是哪個顏色。
    private func barWidth(_ share: Double, room: CGFloat) -> CGFloat {
        max(Tokens.Rack.statsShare, room * CGFloat(share))
    }

    /// 第二張：計時中記了幾筆、作廢各是什麼原因，下面列出每一顆。
    /// 不到門檻只講總數、不分種類；清單照樣列，她點進來就是想看。
    private func jotCard(_ tally: JotTally) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            StatsTitle(text: Words.jotTitle)
            if tally.items.isEmpty {
                StatsNote(text: Words.jotNothing)
            }
            if tally.jots > 0 {
                StatsFact(text: Words.jotSum(tally))
            }
            if tally.voids > 0 {
                StatsFact(text: Words.voidSum(tally))
            }
            ForEach(Array(tally.items.enumerated()), id: \.offset) { entry in
                let item = entry.element
                JotRow(item: item, name: Machine.typeOf(state, item.typeId).name)
            }
        }
        .modifier(StatsCard())
    }
}

/// 分析卡片的標題：就是那一題。
struct StatsTitle: View {
    var text: String

    var body: some View {
        Text(text)
            .font(Tokens.Fonts.bodyStrong)
            .foregroundStyle(Tokens.Colors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 分析卡片裡的一句計數。
struct StatsFact: View {
    var text: String

    var body: some View {
        Text(text)
            .font(Tokens.Fonts.sub)
            .foregroundStyle(Tokens.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 分析卡片裡次要的一行：配角的事實、資料還沒有時那一句。
struct StatsNote: View {
    var text: String

    var body: some View {
        Text(text)
            .font(Tokens.Fonts.sub)
            .foregroundStyle(Tokens.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 清單上的一顆：星期幾、幾點開始、哪個標籤；下面是這顆記的每一筆，作廢的再多一行。
struct JotRow: View {
    var item: JotItem
    var name: String

    private var lines: [String] {
        var all = Words.jotLines(.notes, item.notes) + Words.jotLines(.pings, item.pings)
        if let entry = item.voided {
            all.append(Words.voidLine(minute: entry.minute, reason: entry.reason, text: entry.text))
        }
        return all
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Tokens.Colors.separator
                .frame(height: Tokens.Shape.hairline)
                .padding(.bottom, Tokens.Space.xs)
            Text(Words.jotItemTitle(dayKey: item.dayKey, start: item.start, name: name))
                .font(Tokens.Fonts.chip)
                .foregroundStyle(Tokens.Colors.textPrimary)
            ForEach(Array(lines.enumerated()), id: \.offset) { line in
                Text(line.element)
                    .font(Tokens.Fonts.sub)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 分析裡的白卡。
struct StatsCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.card)
            .background(
                Tokens.Colors.card,
                in: RoundedRectangle(cornerRadius: Tokens.Shape.radiusCard)
            )
    }
}
