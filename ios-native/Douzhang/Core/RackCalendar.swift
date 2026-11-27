import Foundation

/// 番茄架的檢視：天／3 天／週共用一條時間軸，月是一格一天。
enum RackView: CaseIterable {
    case day, three, week, month
}

/// 排好位置的一塊。單位是小時（從當天 0 點算）：from、upTo 是真的起訖，top、height 是畫在哪、畫多高
/// （太短的畫到最小高度、擠到的被推下來，所以不一定一樣）。
/// 時間真的重疊的分到不同欄（lane），同一群重疊的平分寬度（lanes＝這一群有幾欄）。
struct DayBlock: Equatable {
    var item: TimelineItem
    var from: Double
    var upTo: Double
    var top: Double
    var height: Double
    var lane: Int
    var lanes: Int

    var bottom: Double {
        top + height
    }
}

/// 時間軸從幾點畫到幾點。
struct AxisHours: Equatable {
    var from: Int
    var upTo: Int
}

/// 時間軸每個鐘頭多高（點）、幾點畫在哪。有番茄的鐘頭一樣高，空的收窄。
struct TimeScale: Equatable {
    var from: Int
    /// 有番茄的鐘頭多高
    var hour: Double
    /// 從 from 起每個鐘頭多高
    var heights: [Double]

    /// 幾點（小時，可以帶小數）離時間軸最上面多遠。超過最後一個鐘頭的照 hour 往下接。
    func offset(_ time: Double) -> Double {
        let passed = max(0, time - Double(from))
        let whole = min(heights.count, Int(passed))
        let before = heights.prefix(whole).reduce(0, +)
        let inside = (passed - Double(whole)) * hour
        return before + (whole < heights.count ? min(inside, heights[whole]) : inside)
    }
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
/// 真的重疊的並排、同一群平分欄寬；太短的畫到最小高度，擠到的往下推；
/// 跨過午夜的只畫到當天 24:00。
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

    /// 一天的方塊排好位置。minHours：再短也畫這麼高；roomyHours：下面有空的話長到這麼高；
    /// wordyHours：寫了在做什麼或筆記的番茄，下面有空的話長到這麼高（天檢視：有字才需要長）。
    /// 兩顆很短又很近的往下推、不並排（一次只做一顆，真的重疊的是兩台同時），欄寬整條留給字，
    /// 被推下來的那顆結尾照舊，所以隔一會兒就追回真的時刻。天檢視也一樣（多米 2026-11-27）。
    static func dayBlocks(
        _ day: DayRecord?,
        key: String,
        minHours: Double,
        roomyHours: Double = 0,
        wordyHours: Double = 0
    ) -> [DayBlock] {
        let base = DayKeys.start(key)
        var blocks: [DayBlock] = []
        var cluster: [Int] = []
        // 前面幾群畫到哪裡：這一群從那裡以下才有位子
        var taken = 0.0
        for item in Receipt.timeline(day) {
            let start = (item.start - base) / Params.msPerHour
            let from = topInDay(start, minHours: minHours)
            // 整顆在這天之後的（別的時區收的）都夾在同一個位子，不是真的重疊：不佔時間，往下推就不會並排
            let isAfter = start >= hoursPerDay
            let upTo = isAfter ? from : max(from, inDay((item.end - base) / Params.msPerHour))
            if isAfter || cluster.allSatisfy({ blocks[$0].upTo <= from }) {
                closeCluster(&blocks, cluster)
                taken = cluster.map { blocks[$0].bottom }.reduce(taken, max)
                cluster = []
            }
            let busyLanes = cluster.filter { blocks[$0].upTo > from }.map { blocks[$0].lane }
            var lane = 0
            while busyLanes.contains(lane) {
                lane += 1
            }
            let sameLane = cluster.filter { blocks[$0].lane == lane }.map { blocks[$0].bottom }
            let top = max(from, sameLane.reduce(taken, max))
            cluster.append(blocks.count)
            blocks.append(DayBlock(
                item: item,
                from: from,
                upTo: upTo,
                top: top,
                height: max(minHours, upTo - top),
                lane: lane,
                lanes: 1
            ))
        }
        closeCluster(&blocks, cluster)
        return stretched(blocks, roomyHours: roomyHours, wordyHours: wordyHours)
    }

    /// 沒有並排的那些，下面空著就長高一點，字多放幾行；不會碰到下一塊。
    /// 作廢只寫一行，不跟著有字的長。
    private static func stretched(
        _ blocks: [DayBlock],
        roomyHours: Double,
        wordyHours: Double
    ) -> [DayBlock] {
        var result = blocks
        for index in result.indices where result[index].lanes == 1 {
            let item = result[index].item
            let hasWords = item.kind == .bean && !(item.doing.isEmpty && item.clue.isEmpty)
            let reach = hasWords ? max(roomyHours, wordyHours) : roomyHours
            let next = index + 1 < result.count ? result[index + 1].top : hoursPerDay
            let room = min(reach, next - result[index].top)
            result[index].height = max(result[index].height, room)
        }
        return result
    }

    /// 在別的時區收的那顆（格子照當地那天、時刻照這支手機現在的時區）與壞檔，
    /// 算出來會在這天外面：夾進這天裡，畫面照樣畫得出來。
    private static func inDay(_ hours: Double) -> Double {
        min(hoursPerDay, max(0, hours))
    }

    /// 整顆在這天之後的，留一個最小高度的位子在最底下，不會畫到時間軸外面。
    private static func topInDay(_ hours: Double, minHours: Double) -> Double {
        inDay(hours >= hoursPerDay ? hoursPerDay - minHours : hours)
    }

    private static func closeCluster(_ blocks: inout [DayBlock], _ cluster: [Int]) {
        let lanes = (cluster.map { blocks[$0].lane }.max() ?? 0) + 1
        for index in cluster {
            blocks[index].lanes = lanes
        }
    }

    /// 幾天共用的時間軸：最早那顆的整點前一小時，到最晚那顆結束的整點後一小時。
    /// columns：每天排好的方塊。都沒有東西回 nil（畫面就空著，不寫 0）。
    /// 先夾進 0 到 24 點再算，from 一定小於 upTo（畫面拿這兩個做範圍，反過來會當掉）。
    static func axisHours(_ columns: [[DayBlock]]) -> AxisHours? {
        let blocks = columns.flatMap { $0 }
        guard let first = blocks.map({ inDay($0.top) }).min() else { return nil }
        let last = blocks.map { inDay($0.top + $0.height) }.max() ?? first
        return AxisHours(
            from: max(0, Int(first.rounded(.down)) - 1),
            upTo: min(Int(hoursPerDay), Int(last.rounded(.up)) + 1)
        )
    }

    /// 時間軸的每個鐘頭多高：真的有番茄的鐘頭是 hour，空的收成 flat，不用捲很久。
    /// 短方塊畫到最小高度、伸進空鐘頭的那一截照 hour 的比例放，方塊才不會被壓扁。
    static func timeScale(
        _ columns: [[DayBlock]],
        axis: AxisHours,
        hour: Double,
        flat: Double
    ) -> TimeScale {
        let blocks = columns.flatMap { $0 }
        let heights = (axis.from ..< axis.upTo).map { index -> Double in
            let start = Double(index)
            let isBusy = blocks.contains { block in
                Int(block.from) == index || (block.from < start && block.upTo > start)
            }
            if isBusy {
                return hour
            }
            let reach = blocks.filter { $0.top < start + 1 }.map { $0.bottom - start }.max() ?? 0
            return max(flat, min(1, reach) * hour)
        }
        return TimeScale(from: axis.from, hour: hour, heights: heights)
    }

    /// 這個月的格子：一週一列（週一開頭）。
    /// 葉子只掛在這個月裡的日子，哪天掛看 MonthBoard.hasLeaf。
    static func monthWeeks(_ state: AppState, key: String, todayKey: String) -> [MonthWeek] {
        guard DayKeys.dateOf(key) != nil else { return [] }
        let firstOfMonth = DayKeys.shiftMonth(key, months: 0)
        let lastKey = DayKeys.shift(DayKeys.shiftMonth(key, months: 1), days: -1)
        let monthPrefix = String(firstOfMonth.dropLast(2))
        let since = MonthBoard.firstKept(state)
        var weeks: [MonthWeek] = []
        var weekStart = DayKeys.weekStart(firstOfMonth)
        while weekStart <= lastKey {
            let days = DayKeys.weekDays(weekStart).map { dayKey in
                let inMonth = dayKey.hasPrefix(monthPrefix)
                let beans = inMonth ? state.days[dayKey]?.beans ?? [] : []
                let leaf = inMonth
                    && MonthBoard.hasLeaf(state, key: dayKey, todayKey: todayKey, since: since)
                return MonthDay(key: dayKey, inMonth: inMonth, beans: beans, leaf: leaf)
            }
            let busy = days.contains { !$0.beans.isEmpty }
            weeks.append(MonthWeek(weekStart: weekStart, days: days, busy: busy))
            weekStart = DayKeys.shiftWeek(weekStart, weeks: 1)
        }
        return weeks
    }
}
