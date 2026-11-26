import SwiftUI

/// 番茄架的時間軸：天、3 天、週共用這一個，差別只在一次排幾欄。
/// 左邊時刻，右邊一天一欄；每顆番茄是它標籤顏色的實心方塊，畫在開始的時刻，作廢是虛線框。
/// 高度照長度，但太短的會長到放得下字，3 天、週空的鐘頭收窄，所以不是處處照比例。
/// 短又近的：天照舊左右並排；3 天、週往下推、不並排，欄寬整條留給字，時間真的重疊才並排
/// （排法在 Core/RackCalendar.swift）。
/// 3 天、週一小時拉得比天檢視高，一顆 25 分放得下兩行字；沒番茄的鐘頭收成一條，不用捲很久。
/// 「做什麼」是這顆寫的那句在做什麼，沒寫就是標籤名。
struct RackTimeline: View {
    var state: AppState
    /// 要畫的那幾天（1、3 或 7 個日期鍵）
    var keys: [String]
    var view: RackView
    /// 點了某一天的方塊
    var onOpen: (String) -> Void

    var body: some View {
        // 3 天、週的欄寬是死的：字再放大一行只剩一個字，到這一級為止（要看大字有天檢視）
        let largest: DynamicTypeSize = view == .day ? .accessibility5 : .xxxLarge
        TimelineGrid(state: state, keys: keys, view: view, onOpen: onOpen)
            .dynamicTypeSize(DynamicTypeSize.xSmall ... largest)
    }
}

/// 時間軸本體。另外一層是因為拉高的高度要讀到上面夾過的字級。
struct TimelineGrid: View {
    var state: AppState
    var keys: [String]
    var view: RackView
    var onOpen: (String) -> Void

    @ScaledMetric(relativeTo: .footnote) private var tall = Tokens.Rack.timelineHourTall

    private let gap = Double(Tokens.Rack.timelineLaneGap)

    private var hourHeight: Double {
        view == .day ? Double(Tokens.Rack.timelineHour) : Double(tall)
    }

    /// 天檢視每個鐘頭一樣高
    private var flatHeight: Double {
        view == .day ? hourHeight : Double(Tokens.Rack.timelineHourFlat)
    }

    var body: some View {
        let columns = keys.map(blocks)
        // 這幾天都沒有番茄也沒有作廢就什麼都不畫（不寫 0、不畫空的時間軸）
        if let axis = RackCalendar.axisHours(columns) {
            let scale = RackCalendar.timeScale(
                columns,
                axis: axis,
                hour: hourHeight,
                flat: flatHeight
            )
            // 午夜前擠好幾顆短的會推到 24 點以下，跟著長高才捲得到
            let last = columns.flatMap { $0 }.map(\.bottom).max() ?? 0
            let height = scale.offset(max(last, Double(axis.upTo)))
            ZStack(alignment: .topLeading) {
                ForEach(Array(axis.from ... axis.upTo), id: \.self) { hour in
                    hourLine(hour).offset(y: scale.offset(Double(hour)))
                }
                HStack(alignment: .top, spacing: .zero) {
                    ForEach(Array(keys.enumerated()), id: \.offset) { item in
                        column(item.element, blocks: columns[item.offset], scale: scale)
                    }
                }
                .frame(height: height)
                .padding(.leading, Tokens.Rack.timelineGutter)
            }
            .frame(height: height, alignment: .top)
            .padding(.top, Tokens.Layout.group)
        }
    }

    /// 一塊最小多高
    private var least: CGFloat {
        switch view {
        case .week: Tokens.Rack.timelineBlockMinWeek
        case .three: Tokens.Rack.timelineBlockMinThree
        case .day, .month: Tokens.Rack.timelineBlockMin
        }
    }

    /// 下面有空可以長到多高；天檢視不長
    private var room: CGFloat {
        switch view {
        case .week: Tokens.Rack.timelineRoomWeek
        case .three: Tokens.Rack.timelineRoomThree
        case .day, .month: .zero
        }
    }

    /// 一天的方塊。最小高度、長到多高是畫面上的點，換成小時給 Core 排；字級放大時跟一小時的高一起放大。
    private func blocks(_ key: String) -> [DayBlock] {
        let hour = view == .day ? Tokens.Rack.timelineHour : Tokens.Rack.timelineHourTall
        return RackCalendar.dayBlocks(
            state.days[key],
            key: key,
            minHours: Double(least / hour),
            roomyHours: Double(room / hour),
            sideBySide: view == .day
        )
    }

    /// 一條整點的線與左邊的時刻。線要落在那個整點上，所以用這一列的中線對齊，不是上緣。
    /// 3 天、週的時刻一行放完（字級有上限）：折成兩行的話線跟方塊會差半行，收窄的鐘頭也放不下。
    private func hourLine(_ hour: Int) -> some View {
        HStack(spacing: .zero) {
            Text(Words.hourLabel(hour % 24))
                .font(Tokens.Fonts.caption)
                .foregroundStyle(Tokens.Colors.textSecondary)
                .lineLimit(view == .day ? nil : 1)
                .minimumScaleFactor(view == .day ? 1 : Tokens.Bell.shrink)
                .dynamicTypeSize(...(view == .day ? DynamicTypeSize.accessibility5 : .xLarge))
                .frame(width: Tokens.Rack.timelineGutter, alignment: .leading)
            Tokens.Colors.separator.frame(height: Tokens.Shape.hairline)
        }
        .alignmentGuide(.top) { $0[VerticalAlignment.center] }
    }

    private func column(_ key: String, blocks: [DayBlock], scale: TimeScale) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { item in
                    let block = item.element
                    let width = Double(proxy.size.width) / Double(block.lanes)
                    let top = scale.offset(block.top)
                    let height = max(0, scale.offset(block.bottom) - top - gap)
                    TimelineBlock(
                        block: block,
                        view: view,
                        type: Machine.typeOf(state, block.item.typeId),
                        height: height
                    ) {
                        onOpen(key)
                    }
                    .frame(width: max(0, width - gap), height: height)
                    .offset(x: width * Double(block.lane), y: top)
                }
            }
        }
    }
}
