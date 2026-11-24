import Foundation

/// 番茄架的檢視：天／3 天／週共用一條時間軸，月是一格一天。
enum RackView: CaseIterable {
    case day, three, week, month
}

/// 排好位置的一塊。top、height 的單位是小時（從當天 0 點算）；
/// 重疊的分到不同欄（lane），同一群重疊的平分寬度（lanes＝這一群有幾欄）。
struct DayBlock: Equatable {
    var item: TimelineItem
    var top: Double
    var height: Double
    var lane: Int
    var lanes: Int
}

/// 時間軸從幾點畫到幾點。
struct AxisHours: Equatable {
    var from: Int
    var upTo: Int
}

/// 月檢視的一格。不屬於這個月的格子不帶番茄。
struct MonthDay: Equatable {
    var key: String
    var inMonth: Bool
    var beans: [Bean]
    var leaf: Bool
}

/// 月檢視的一列。busy＝這週在這個月裡有沒有番茄，沒有的週畫面壓扁成一行。
struct MonthWeek: Equatable {
    var weekStart: String
    var days: [MonthDay]
    var busy: Bool
}

/// 番茄帳 番茄架的行事曆。純函式，只讀不寫。翻自 Expo 版 core/calendar.js。
/// 規則沿用蒜日子：重疊的並排、同一群平分欄寬；太短的畫到最小高度；跨過午夜的只畫到當天 24:00。
enum RackCalendar {
    private static let hoursPerDay = 24.0
    private static let threeDays = 3

    /// 這個檢視畫哪幾天：天＝選中那天；3 天＝選中那天與前兩天；週＝那一週七天。月不走這裡。
    static func viewDays(_ view: RackView, selected: String) -> [String] {
        if view == .week {
            return DayKeys.weekDays(DayKeys.weekStart(selected))
        }
        let count = view == .three ? threeDays : 1
        return (0 ..< count).map { DayKeys.shift(selected, days: $0 - (count - 1)) }
    }

    /// 按 ‹ › 換一段之後選哪一天：天動一天、3 天動三天、週動一週、月跳到那個月的 1 號。
    static func shiftPeriod(_ view: RackView, selected: String, step: Int) -> String {
        switch view {
        case .month: DayKeys.shiftMonth(selected, months: step)
        case .week: DayKeys.shiftWeek(DayKeys.weekStart(selected), weeks: step)
        case .three: DayKeys.shift(selected, days: step * threeDays)
        case .day: DayKeys.shift(selected, days: step)
        }
    }

    /// 畫面上這一段有沒有包含今天或更晚的日子（有的話不給往後翻）。
    static func reachesToday(_ view: RackView, selected: String, todayKey: String) -> Bool {
        if view == .month {
            return DayKeys.shiftMonth(selected, months: 1) > todayKey
        }
        let last = viewDays(view, selected: selected).last ?? selected
        return last >= todayKey
    }

    /// 一天的方塊排好位置。minHours：再短也畫這麼高，
    /// 所以兩顆很短又很近的會被當成重疊、排成左右並排，不會疊在一起。
    static func dayBlocks(_ day: DayRecord?, key: String, minHours: Double) -> [DayBlock] {
        let base = DayKeys.start(key)
        var blocks: [DayBlock] = []
        var cluster: [Int] = []
        var clusterEnd = -1.0
        for item in Receipt.timeline(day) {
            let top = (item.start - base) / Params.msPerHour
            let end = min(hoursPerDay, (item.end - base) / Params.msPerHour)
            let height = max(minHours, end - top)
            if !cluster.isEmpty, top >= clusterEnd {
                closeCluster(&blocks, cluster)
                cluster = []
                clusterEnd = -1
            }
            let busy = cluster.filter { blocks[$0].top + blocks[$0].height > top }
            let busyLanes = busy.map { blocks[$0].lane }
            var lane = 0
            while busyLanes.contains(lane) {
                lane += 1
            }
            cluster.append(blocks.count)
            blocks.append(DayBlock(item: item, top: top, height: height, lane: lane, lanes: 1))
            clusterEnd = max(clusterEnd, top + height)
        }
        closeCluster(&blocks, cluster)
        return blocks
    }

    private static func closeCluster(_ blocks: inout [DayBlock], _ cluster: [Int]) {
        let lanes = (cluster.map { blocks[$0].lane }.max() ?? 0) + 1
        for index in cluster {
            blocks[index].lanes = lanes
        }
    }

    /// 幾天共用的時間軸：最早那顆的整點前一小時，到最晚那顆結束的整點後一小時。
    /// columns：每天排好的方塊。都沒有東西回 nil（畫面就空著，不寫 0）。
    static func axisHours(_ columns: [[DayBlock]]) -> AxisHours? {
        let blocks = columns.flatMap { $0 }
        guard let first = blocks.map(\.top).min() else { return nil }
        let last = blocks.map { $0.top + $0.height }.max() ?? first
        return AxisHours(
            from: max(0, Int(first.rounded(.down)) - 1),
            upTo: min(Int(hoursPerDay), Int(last.rounded(.up)) + 1)
        )
    }

    /// 這個月的格子：一週一列（週一開頭）。
    /// 葉子：這個月裡、已經過完、沒有番茄的日子掛一片，不算缺。
    /// 今天與以後不掛（今天還沒過完）；第一顆番茄那天以前也不掛（那時還沒在用，不是「沒做」）。
    static func monthWeeks(_ state: AppState, key: String, todayKey: String) -> [MonthWeek] {
        guard DayKeys.dateOf(key) != nil else { return [] }
        let firstOfMonth = DayKeys.shiftMonth(key, months: 0)
        let lastKey = DayKeys.shift(DayKeys.shiftMonth(key, months: 1), days: -1)
        let monthPrefix = String(firstOfMonth.dropLast(2))
        let firstBeanKey = state.days.filter { !$0.value.beans.isEmpty }.keys.min()
        var weeks: [MonthWeek] = []
        var weekStart = DayKeys.weekStart(firstOfMonth)
        while weekStart <= lastKey {
            let days = DayKeys.weekDays(weekStart).map { dayKey in
                let inMonth = dayKey.hasPrefix(monthPrefix)
                let beans = inMonth ? state.days[dayKey]?.beans ?? [] : []
                let started = firstBeanKey.map { dayKey >= $0 } ?? false
                let leaf = inMonth && started && dayKey < todayKey && beans.isEmpty
                return MonthDay(key: dayKey, inMonth: inMonth, beans: beans, leaf: leaf)
            }
            let busy = days.contains { !$0.beans.isEmpty }
            weeks.append(MonthWeek(weekStart: weekStart, days: days, busy: busy))
            weekStart = DayKeys.shiftWeek(weekStart, weeks: 1)
        }
        return weeks
    }
}
