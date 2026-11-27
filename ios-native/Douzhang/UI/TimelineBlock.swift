import SwiftUI

/// 時間軸上的一顆番茄或一次作廢。第一行一律是標籤名，再來長度、在做什麼、筆記，放得下多少寫多少
/// （多米 2026-11-27，照 FocusPomo）。天全寫；3 天每樣一行、放得下才加；週只露名字一行。
struct TimelineBlock: View {
    var block: DayBlock
    var view: RackView
    var type: TagType
    /// 畫多高（點）
    var height: Double
    var action: () -> Void

    @ScaledMetric(relativeTo: .caption) private var weekLine = Tokens.Rack.timelineLineWeek
    @ScaledMetric(relativeTo: .footnote) private var dayLine = Tokens.Rack.timelineLineDay

    private var isVoid: Bool {
        block.item.kind == .voided
    }

    /// 天檢視的作廢只寫一行，字置中；其他一律靠上。
    private var alignTop: Bool {
        view != .day || !isVoid
    }

    private var radius: CGFloat {
        switch view {
        case .week: Tokens.Rack.timelineRadiusWeek
        case .three: Tokens.Rack.timelineRadius
        case .day, .month: Tokens.Shape.radiusButton
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        Button(action: action) {
            ZStack(alignment: alignTop ? .topLeading : .leading) {
                if isVoid {
                    // 作廢只畫虛線框，不靠顏色
                    shape.stroke(Tokens.Colors.textSecondary, style: Tokens.Rack.voidStroke)
                } else {
                    shape.fill(Tokens.Tomato.body(type.color).color)
                }
                text.foregroundStyle(Tokens.Tomato.onBody(type.color).color)
            }
            .clipShape(shape)
            .contentShape(shape)
        }
        .buttonStyle(FadeStyle())
        .accessibilityLabel(a11yLabel)
    }

    private var name: String {
        type.name
    }

    private var length: String {
        Words.lenWithFlow(block.item.len, flow: block.item.flow)
    }

    private var title: String {
        Words.blockTitle(name, len: block.item.len, flow: block.item.flow)
    }

    private var voidLine: String {
        let item = block.item
        return Words.voidLine(
            minute: item.minute,
            reason: item.reason,
            text: item.text,
            doing: item.doing
        )
    }

    /// 作廢只在天檢視寫字。
    @ViewBuilder private var text: some View {
        switch view {
        case .day, .month:
            dayText
        case .three:
            if !isVoid {
                threeText
            }
        case .week:
            if !isVoid {
                weekText
            }
        }
    }

    /// 天放得下幾行：扣掉上緣留白，一行 dayLine。行數用算的、不用 ViewThatFits：
    /// 筆記要寫到剛好放滿再接「…」，試排只分得出全部放得下或放不下。
    private var dayFit: Int {
        max(1, Int((height - Double(Tokens.Layout.tight)) / Double(dayLine)))
    }

    /// 天：標籤名、長度、在做什麼、筆記，照這個順序有幾行寫幾行，筆記放不下結尾「…」。
    /// 時間真的重疊的並排，欄窄，只寫標籤名。
    private var dayText: some View {
        let item = block.item
        let fit = dayFit
        let hasDoing = !item.doing.isEmpty && fit > 2
        let clueLines = fit - 2 - (hasDoing ? 1 : 0)
        return VStack(alignment: .leading, spacing: .zero) {
            if block.lanes > 1 {
                if !isVoid {
                    Text(name).fontWeight(.semibold).lineLimit(1)
                }
            } else if isVoid {
                Text(voidLine).foregroundStyle(Tokens.Colors.textSecondary).lineLimit(1)
            } else {
                Text(name).fontWeight(.semibold).lineLimit(1)
                if fit > 1 {
                    Text(length).lineLimit(1)
                }
                if hasDoing {
                    Text(item.doing).lineLimit(1)
                }
                if clueLines > 0, !item.clue.isEmpty {
                    Text(item.clue)
                        .opacity(Tokens.Notebook.blockFade)
                        .lineLimit(clueLines)
                }
            }
        }
        .font(Tokens.Fonts.caption)
        .padding(.horizontal, Tokens.Layout.item)
        .padding(.top, alignTop ? Tokens.Layout.tight : .zero)
    }

    /// 3 天：每樣只佔一行，太長結尾「…」（多米 2026-11-26：長名字折兩行太擠）。
    /// 放得下多少寫多少：連筆記、連在做什麼、標籤名＋長度、只有一行。
    private var threeText: some View {
        let item = block.item
        return ViewThatFits(in: .vertical) {
            if !item.doing.isEmpty || !item.clue.isEmpty {
                threeLines(hasDoing: true, hasClue: true)
            }
            if !item.doing.isEmpty, !item.clue.isEmpty {
                threeLines(hasDoing: true)
            }
            threeLines()
            // 一行：長度放不下就只寫名字，名字比長度重要
            ViewThatFits(in: .horizontal) {
                Text(title).fontWeight(.semibold).lineLimit(1)
                Text(name).fontWeight(.semibold).lineLimit(1)
            }
        }
        .font(Tokens.Fonts.caption)
        .padding(.horizontal, Tokens.Layout.tight)
        .padding(.vertical, Tokens.Rack.timelineLaneGap)
    }

    private func threeLines(hasDoing: Bool = false, hasClue: Bool = false) -> some View {
        let item = block.item
        return VStack(alignment: .leading, spacing: .zero) {
            Text(name).fontWeight(.semibold).lineLimit(1)
            Text(length).lineLimit(1)
            if hasDoing, !item.doing.isEmpty {
                Text(item.doing).lineLimit(1)
            }
            if hasClue, !item.clue.isEmpty {
                Text(item.clue).opacity(Tokens.Notebook.blockFade).lineLimit(2)
            }
        }
    }

    /// 週：一格只有兩三個字寬，名字折行但只露第一行（多米 2026-11-26：長名字別佔滿整格）。
    /// 第二行起整行裁掉，不用「…」：刪節號自己就佔一個字。
    private var weekText: some View {
        Text(name)
            .font(Tokens.Fonts.tab)
            .fontWeight(.semibold)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                maxWidth: .infinity,
                maxHeight: weekLine,
                alignment: .topLeading
            )
            .clipped()
            .padding(Tokens.Rack.timelineLaneGap)
    }

    /// 讀屏念的那一句：番茄是「專注，25 分，寫第三節，寫完開頭」，作廢是「作廢，第幾分鐘…」。
    private var a11yLabel: String {
        isVoid ? voidLine : Words.blockA11y(block.item, name: name)
    }
}
