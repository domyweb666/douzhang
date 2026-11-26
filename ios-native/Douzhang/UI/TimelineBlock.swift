import SwiftUI

/// 時間軸上的一顆番茄或一次作廢。寫多少字看檢視：天＝一行做什麼與長度，3 天＝名字一行起與長度，週＝名字折行。
struct TimelineBlock: View {
    var block: DayBlock
    var view: RackView
    var type: TagType
    /// 畫多高（點）
    var height: Double
    var action: () -> Void

    @ScaledMetric(relativeTo: .caption) private var weekLine = Tokens.Rack.timelineLineWeek

    private var isVoid: Bool {
        block.item.kind == .voided
    }

    /// 天檢視：夠高（tall）字靠上、可以多寫一行那句；不夠高字置中。3 天、週一律靠上。
    private var isTall: Bool {
        view != .day || height >= Double(Tokens.Rack.timelineNoteMin)
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
            ZStack(alignment: isTall ? .topLeading : .leading) {
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
        Receipt.workName(block.item.doing, type: type)
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

    /// 天：沒有並排才寫完整的（做什麼・長度，夠高再加那句），並排只寫做什麼。
    private var dayText: some View {
        VStack(alignment: .leading, spacing: .zero) {
            if block.lanes > 1 {
                if !isVoid {
                    Text(name).lineLimit(1)
                }
            } else if isVoid {
                Text(voidLine).foregroundStyle(Tokens.Colors.textSecondary).lineLimit(1)
            } else {
                Text(title).fontWeight(.semibold).lineLimit(1)
                if isTall, !block.item.clue.isEmpty {
                    Text(block.item.clue).lineLimit(2)
                }
            }
        }
        .font(Tokens.Fonts.caption)
        .padding(.horizontal, Tokens.Layout.item)
        .padding(.top, isTall ? Tokens.Layout.tight : .zero)
    }

    /// 3 天：放得下多少寫多少。由多到少：名字兩行＋長度＋那句、名字兩行＋長度、名字一行＋長度、只有一行。
    private var threeText: some View {
        ViewThatFits(in: .vertical) {
            if !block.item.clue.isEmpty {
                threeLines(nameLines: 2, hasClue: true)
            }
            threeLines(nameLines: 2)
            threeLines(nameLines: 1)
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

    private func threeLines(nameLines: Int, hasClue: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            Text(name).fontWeight(.semibold).lineLimit(nameLines)
            Text(length).lineLimit(1)
            if hasClue {
                Text(block.item.clue).lineLimit(2)
            }
        }
    }

    /// 週：一格只有兩三個字寬，名字折行、放得下幾行就露幾行。
    /// 超出的整行裁掉，不用「…」：刪節號自己就佔一個字。
    private var weekText: some View {
        let inner = height - Double(Tokens.Rack.timelineLaneGap) * 2
        let lines = max(1, (inner / Double(weekLine)).rounded(.down))
        return Text(name)
            .font(Tokens.Fonts.tab)
            .fontWeight(.semibold)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                maxWidth: .infinity,
                maxHeight: lines * Double(weekLine),
                alignment: .topLeading
            )
            .clipped()
            .padding(Tokens.Rack.timelineLaneGap)
    }

    /// 讀屏念的那一句：番茄是「專注・25 分，那句」，作廢是「作廢，第幾分鐘…」。
    private var a11yLabel: String {
        if isVoid {
            return voidLine
        }
        return title + (block.item.clue.isEmpty ? "" : "，\(block.item.clue)")
    }
}
