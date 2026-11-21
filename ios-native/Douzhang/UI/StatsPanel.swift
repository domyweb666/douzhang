import SwiftUI

/// 番茄架的分析：這一段專注多久、收了幾顆、每天一根依標籤分色的長條、各標籤占多少。
/// 只陳述，不跟上一段比：沒有「比上週少幾 %」的箭頭，也沒有紅字。
/// 數字都是 Core/Stats.swift 算的，這裡只畫。日＝那天的番茄排一排；週＝七根；月＝一天一根細的。
struct StatsPanel: View {
    var state: AppState
    var range: StatsRange
    /// 這一段裡的任一天
    var selected: String

    var body: some View {
        let result = Stats.stats(state, keys: Stats.rangeDays(range, selected: selected))
        if result.beans == 0 {
            // 這一段沒有番茄就只寫一句
            Text(Words.statsEmpty)
                .font(Tokens.Fonts.sub)
                .foregroundStyle(Tokens.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.Space.xl)
        } else {
            VStack(spacing: Tokens.Space.m) {
                numbers(result).modifier(StatsCard())
                chart(result).modifier(StatsCard())
                VStack(spacing: .zero) {
                    ForEach(result.tags, id: \.type.id) { tag in tagRow(tag) }
                }
                .modifier(StatsCard())
            }
            .padding(.top, Tokens.Space.m)
        }
    }

    /// 上面那張：左邊專注多久，右邊收了幾顆。
    private func numbers(_ result: StatsResult) -> some View {
        HStack(spacing: .zero) {
            numberCell(Words.statsFocus, Words.duration(result.minutes))
            numberCell(Words.statsKept, Words.beansCount(result.beans))
        }
    }

    private func numberCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            Text(label)
                .font(Tokens.Fonts.caption)
                .foregroundStyle(Tokens.Colors.textSecondary)
            Text(value)
                .font(Tokens.Fonts.title3)
                .foregroundStyle(Tokens.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func chart(_ result: StatsResult) -> some View {
        if range == .day {
            // 那天收下的番茄依時間排一排，顏色跟標籤
            FlowRow(spacing: Tokens.Space.xs) {
                ForEach(Array(result.list.enumerated()), id: \.offset) { item in
                    TomatoView(color: item.element.type.color, size: Tokens.Shape.celebrateDot)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
        } else {
            VStack(spacing: Tokens.Space.xs) {
                StatsBars(days: result.days, thin: range == .month)
                barLabels(result.days)
            }
        }
    }

    /// 長條圖下面那排字：週是一二三四五六日；月只寫頭、中、尾三個日期。
    @ViewBuilder
    private func barLabels(_ days: [StatsDay]) -> some View {
        if range == .month {
            HStack {
                barLabel(dayNumber(days.first))
                Spacer()
                barLabel(dayNumber(days.isEmpty ? nil : days[days.count / 2]))
                Spacer()
                barLabel(dayNumber(days.last))
            }
        } else {
            HStack(spacing: Tokens.Space.s) {
                ForEach(Words.weekdayShort, id: \.self) { name in
                    barLabel(name).frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func dayNumber(_ day: StatsDay?) -> String {
        String(Int(day?.key.suffix(2) ?? "") ?? 0)
    }

    private func barLabel(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Fonts.tab)
            .foregroundStyle(Tokens.Colors.textSecondary)
    }

    /// 一個標籤一列：小番茄、名字、占比的橫槓、多久。
    private func tagRow(_ tag: StatsTag) -> some View {
        let fill = Tokens.Tomato.body(tag.type.color).color
        let time = Words.duration(tag.minutes)
        return HStack(spacing: Tokens.Space.s) {
            TomatoView(color: tag.type.color, size: Tokens.Shape.blockIcon * 1.5)
            Text(tag.type.name)
                .font(Tokens.Fonts.sub)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .lineLimit(1)
                .frame(width: Tokens.Rack.statsName, alignment: .leading)
            GeometryReader { proxy in
                Capsule().fill(Tokens.Colors.fillButton)
                Capsule().fill(fill).frame(width: proxy.size.width * CGFloat(tag.share))
            }
            .frame(height: Tokens.Rack.statsShare)
            Text(time)
                .font(Tokens.Fonts.caption)
                .foregroundStyle(Tokens.Colors.textSecondary)
        }
        .frame(minHeight: Tokens.Shape.buttonCompact)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tag.type.name)，\(time)，\(Words.beansCount(tag.beans))")
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

/// 一天一根：由下往上疊各標籤的分鐘數，最高那天頂到 statsBars。沒番茄的日子那一格空著。
struct StatsBars: View {
    var days: [StatsDay]
    /// 月檢視：一天一根細的
    var thin: Bool

    var body: some View {
        let tallest = max(1, days.map(\.minutes).max() ?? 1)
        let gap = thin ? Tokens.Rack.timelineLaneGap : Tokens.Space.s
        let radius = thin ? Tokens.Rack.timelineLaneGap : Tokens.Space.xs
        HStack(alignment: .bottom, spacing: gap) {
            ForEach(days, id: \.key) { day in
                VStack(spacing: .zero) {
                    ForEach(day.parts.reversed(), id: \.type.id) { part in
                        Tokens.Tomato.body(part.type.color).color
                            .frame(height: CGFloat(part.minutes / tallest) * Tokens.Rack.statsBars)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: radius))
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: Tokens.Rack.statsBars, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
