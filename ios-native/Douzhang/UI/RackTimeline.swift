import SwiftUI

/// 番茄架的時間軸：天、3 天、週共用這一個，差別只在一次排幾欄。
/// 左邊時刻，右邊一天一欄；每顆番茄是它標籤顏色的實心方塊，畫在開始的時刻、高度照長度，作廢是虛線框。
/// 時間重疊的並排、同一群平分欄寬（排法在 Core/RackCalendar.swift）。
/// 字的多寡跟著欄寬：天＝做什麼、長度、那句；3 天＝做什麼；週太窄，不寫字。
/// 「做什麼」是這顆寫的那句在做什麼，沒寫就是標籤名。
struct RackTimeline: View {
    var state: AppState
    /// 要畫的那幾天（1、3 或 7 個日期鍵）
    var keys: [String]
    var view: RackView
    /// 點了某一天的方塊
    var onOpen: (String) -> Void

    private let hourHeight = Double(Tokens.Rack.timelineHour)
    private let laneGap = Double(Tokens.Rack.timelineLaneGap)

    var body: some View {
        let isWeek = view == .week
        let floor = isWeek ? Tokens.Rack.timelineBlockMinWeek : Tokens.Rack.timelineBlockMin
        let minHours = Double(floor) / hourHeight
        let columns = keys.map { key in
            RackCalendar.dayBlocks(state.days[key], key: key, minHours: minHours)
        }
        // 這幾天都沒有番茄也沒有作廢就什麼都不畫（不寫 0、不畫空的時間軸）
        if let axis = RackCalendar.axisHours(columns) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(axis.from ... axis.upTo), id: \.self) { hour in
                    hourLine(hour).offset(y: Double(hour - axis.from) * hourHeight)
                }
                HStack(alignment: .top, spacing: .zero) {
                    ForEach(Array(keys.enumerated()), id: \.offset) { item in
                        column(item.element, blocks: columns[item.offset], from: axis.from)
                    }
                }
                .padding(.leading, Tokens.Rack.timelineGutter)
            }
            .frame(height: Double(axis.upTo - axis.from) * hourHeight, alignment: .top)
            .padding(.top, Tokens.Layout.group)
        }
    }

    /// 一條整點的線與左邊的時刻。
    private func hourLine(_ hour: Int) -> some View {
        HStack(spacing: .zero) {
            Text(Words.hourLabel(hour % 24))
                .font(Tokens.Fonts.caption)
                .foregroundStyle(Tokens.Colors.textSecondary)
                .frame(width: Tokens.Rack.timelineGutter, alignment: .leading)
            Tokens.Colors.separator.frame(height: Tokens.Shape.hairline)
        }
    }

    private func column(_ key: String, blocks: [DayBlock], from: Int) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { item in
                    let block = item.element
                    let width = Double(proxy.size.width) / Double(block.lanes)
                    TimelineBlock(block: block, view: view, type: type(of: block.item)) {
                        onOpen(key)
                    }
                    .frame(
                        width: max(0, width - laneGap),
                        height: max(0, block.height * hourHeight - laneGap)
                    )
                    .offset(
                        x: width * Double(block.lane),
                        y: (block.top - Double(from)) * hourHeight
                    )
                }
            }
        }
    }

    private func type(of item: TimelineItem) -> TagType {
        Machine.typeOf(state, item.typeId)
    }
}

/// 時間軸上的一顆番茄或一次作廢。週檢視欄太窄：圓角小、不寫字。
struct TimelineBlock: View {
    var block: DayBlock
    var view: RackView
    var type: TagType
    var action: () -> Void

    private var isVoid: Bool {
        block.item.kind == .voided
    }

    private var pixels: Double {
        block.height * Double(Tokens.Rack.timelineHour) - Double(Tokens.Rack.timelineLaneGap)
    }

    /// 夠高（tall）字靠上、可以多寫一行那句；不夠高字置中。
    private var isTall: Bool {
        pixels >= Double(Tokens.Rack.timelineNoteMin)
    }

    var body: some View {
        let radius = view == .week ? Tokens.Rack.timelineLaneGap * 2 : Tokens.Shape.radiusButton
        let shape = RoundedRectangle(cornerRadius: radius)
        Button(action: action) {
            ZStack(alignment: isTall ? .topLeading : .leading) {
                if isVoid {
                    // 作廢只畫虛線框，不靠顏色
                    shape.stroke(Tokens.Colors.textSecondary, style: Tokens.Rack.voidStroke)
                } else {
                    shape.fill(Tokens.Tomato.body(type.color).color)
                }
                if view != .week, pixels >= Double(Tokens.Rack.timelineTextMin) {
                    text
                        .padding(.horizontal, Tokens.Layout.item)
                        .padding(.top, isTall ? Tokens.Layout.tight : .zero)
                }
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

    /// 天檢視且沒有並排才寫完整的（做什麼・長度，夠高再加那句），其他只寫做什麼；作廢只在天檢視寫。
    @ViewBuilder private var text: some View {
        let isFull = view == .day && block.lanes == 1
        let ink = Tokens.Tomato.onBody(type.color).color
        VStack(alignment: .leading, spacing: .zero) {
            if isVoid {
                if isFull {
                    Text(voidLine).foregroundStyle(Tokens.Colors.textSecondary).lineLimit(1)
                }
            } else if isFull {
                Text(title).fontWeight(.semibold).lineLimit(1)
                if isTall, !block.item.clue.isEmpty {
                    Text(block.item.clue).lineLimit(2)
                }
            } else {
                Text(name).lineLimit(1)
            }
        }
        .font(Tokens.Fonts.caption)
        .foregroundStyle(ink)
    }

    /// 讀屏念的那一句：番茄是「專注・25 分，那句」，作廢是「作廢，第幾分鐘…」。
    private var a11yLabel: String {
        if isVoid {
            return voidLine
        }
        return title + (block.item.clue.isEmpty ? "" : "，\(block.item.clue)")
    }
}
