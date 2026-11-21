@testable import Douzhang
import XCTest

/// 月檢視的格子與葉子。翻自 Expo 版 calendar.test.js。
final class MonthGridTests: XCTestCase {
    private let key = "2026-11-17"

    private func sample() -> AppState {
        var state = Store.blank()
        state.days["2026-11-03"] = November.day(November.bean(3, 9, 0, len: 25))
        state.days["2026-11-12"] = November.day(
            November.bean(12, 9, 0, len: 25),
            November.bean(12, 10, 0, len: 50, typeId: "t2")
        )
        // 上個月的，跟 11 月第一週同一列
        var october = November.bean(1, 9, 0, len: 25)
        october.start = Moment.local(2026, 10, 30, 9)
        state.days["2026-10-30"] = November.day(october)
        return state
    }

    func test十一月一號是星期日一共六列每列七格週一開頭() {
        let weeks = RackCalendar.monthWeeks(sample(), key: key, todayKey: key)
        XCTAssertEqual(weeks.count, 6)
        XCTAssertEqual(weeks.map(\.days.count), [7, 7, 7, 7, 7, 7])
        XCTAssertEqual(weeks[0].days[6].key, "2026-11-01")
        XCTAssertTrue(weeks[0].days[6].inMonth)
        XCTAssertEqual(weeks[0].days[0].key, "2026-10-26")
        XCTAssertFalse(weeks[0].days[0].inMonth)
        XCTAssertEqual(weeks[5].days[0].key, "2026-11-30")
        XCTAssertTrue(weeks[5].days[0].inMonth)
    }

    func test沒番茄的週壓扁別的月份的番茄不算() {
        let weeks = RackCalendar.monthWeeks(sample(), key: key, todayKey: key)
        XCTAssertEqual(weeks.map(\.busy), [false, true, true, false, false, false])
        // 11/12 星期四
        XCTAssertEqual(weeks[2].days[3].beans.count, 2)
        // 10/30 在別的月份
        XCTAssertTrue(weeks[0].days[4].beans.isEmpty)
    }

    func test葉子只掛在過完又沒番茄的日子() {
        var state = Store.blank()
        state.days["2026-11-03"] = November.day(November.bean(3, 9, 0, len: 25))
        state.days["2026-11-12"] = November.day(November.bean(12, 9, 0, len: 25))
        let days = RackCalendar.monthWeeks(state, key: key, todayKey: key).flatMap(\.days)
        let leafKeys = Set(days.filter(\.leaf).map(\.key))
        // 過完、沒番茄
        XCTAssertTrue(leafKeys.contains("2026-11-04"))
        XCTAssertTrue(leafKeys.contains("2026-11-16"))
        // 有番茄、第一顆以前、今天、以後、別的月份
        XCTAssertFalse(leafKeys.contains("2026-11-03"))
        XCTAssertFalse(leafKeys.contains("2026-11-02"))
        XCTAssertFalse(leafKeys.contains("2026-11-17"))
        XCTAssertFalse(leafKeys.contains("2026-11-20"))
        XCTAssertFalse(leafKeys.contains("2026-10-30"))
    }

    func test一顆都還沒有整個月都不掛葉子() {
        let weeks = RackCalendar.monthWeeks(Store.blank(), key: key, todayKey: key)
        XCTAssertFalse(weeks.flatMap(\.days).contains { $0.leaf })
    }
}

/// 分析：總分鐘、顆數、各標籤。翻自 Expo 版 calendar.test.js 的「分析」。
final class StatsTests: XCTestCase {
    private let key = "2026-11-17"

    private func sample() -> AppState {
        var state = Store.blank()
        state.days["2026-11-16"] = November.day(
            November.bean(16, 9, 0, len: 25),
            November.bean(16, 10, 0, len: 50, typeId: "t2")
        )
        state.days["2026-11-17"] = November.day(
            November.bean(17, 9, 0, len: 25, flow: 15),
            November.bean(17, 11, 0, len: 30, typeId: "t3")
        )
        return state
    }

    private func week() -> StatsResult {
        Stats.stats(sample(), keys: Stats.rangeDays(.week, selected: key))
    }

    func test一段包含哪幾天日一天週七天月整個月() {
        XCTAssertEqual(Stats.rangeDays(.day, selected: key), [key])
        XCTAssertEqual(Stats.rangeDays(.week, selected: key).count, 7)
        let month = Stats.rangeDays(.month, selected: key)
        XCTAssertEqual(month.count, 30)
        XCTAssertEqual(month.first, "2026-11-01")
        XCTAssertEqual(month.last, "2026-11-30")
    }

    func test一週總分鐘含延長幾顆各標籤由多到少與占比() {
        let result = week()
        XCTAssertEqual(result.minutes, 25 + 50 + 40 + 30)
        XCTAssertEqual(result.beans, 4)
        XCTAssertEqual(result.tags.map(\.type.name), ["專注", "工作", "閱讀"])
        XCTAssertEqual(result.tags.map(\.minutes), [65, 50, 30])
        XCTAssertEqual(result.tags.map(\.beans), [2, 1, 1])
        XCTAssertEqual(result.tags.reduce(0) { $0 + $1.share }, 1, accuracy: 1e-9)
    }

    func test每天一筆沒番茄的日子是零有番茄的照設定裡的順序() {
        let result = week()
        XCTAssertEqual(result.days.map(\.minutes), [75, 70, 0, 0, 0, 0, 0])
        XCTAssertEqual(result.days[1].parts.map(\.type.id), ["t1", "t3"])
        XCTAssertEqual(result.days[1].parts.map(\.minutes), [40, 30])
        XCTAssertTrue(result.days[2].parts.isEmpty)
    }

    func test標籤被刪掉的舊番茄算在第一個標籤() {
        var gone = Store.blank()
        gone.days[key] = November.day(November.bean(17, 9, 0, len: 25, typeId: "deleted"))
        XCTAssertEqual(Stats.stats(gone, keys: [key]).tags.first?.type.id, "t1")
    }

    func test整段都沒番茄時全部是零不會除以零() {
        let none = Stats.stats(Store.blank(), keys: Stats.rangeDays(.week, selected: key))
        XCTAssertEqual(none.minutes, 0)
        XCTAssertEqual(none.beans, 0)
        XCTAssertTrue(none.tags.isEmpty)
        XCTAssertTrue(none.list.isEmpty)
    }

    func test一天的清單依收下的時間排() {
        let result = Stats.stats(sample(), keys: [key])
        XCTAssertEqual(result.list.map(\.type.id), ["t1", "t3"])
    }
}
