@testable import Douzhang
import XCTest

/// 資料層的算法：空白狀態、單位、休息長度、日期鍵。翻自 Expo 版 store.test.js。
final class StoreTests: XCTestCase {
    func test全新安裝有五個預設標籤選中第一個() {
        let state = Store.blank()
        let expected = [
            TagType(id: "t1", name: "專注", len: 25, color: .red),
            TagType(id: "t2", name: "工作", len: 50, color: .purple),
            TagType(id: "t3", name: "閱讀", len: 30, color: .orange),
            TagType(id: "t4", name: "學習", len: 45, color: .yellow),
            TagType(id: "t5", name: "運動", len: 10, color: .pink),
        ]
        XCTAssertEqual(state.settings.types, expected)
        XCTAssertEqual(state.settings.typeId, "t1")
        XCTAssertNil(state.current)
        XCTAssertTrue(state.days.isEmpty)
    }

    func test五十分算兩單位二十五分與十五分算一單位() {
        XCTAssertEqual(Store.units(50), 2)
        XCTAssertEqual(Store.units(25), 1)
        XCTAssertEqual(Store.units(15), 1)
    }

    func test跟著長度的休息最少三分() {
        XCTAssertEqual(Store.restMinutes(25), 5)
        XCTAssertEqual(Store.restMinutes(50), 10)
        XCTAssertEqual(Store.restMinutes(15), 3)
    }

    func test日期鍵用本地日期() {
        XCTAssertEqual(Store.dayKey(Moment.local(2026, 11, 1, 12)), "2026-11-01")
        XCTAssertEqual(Store.dayKey(Moment.local(2026, 1, 9, 0)), "2026-01-09")
        XCTAssertEqual(Store.dayKey(Moment.local(2026, 11, 1, 23, 59)), "2026-11-01")
    }

    func test預設第四顆與第八顆收下後是十五分的長休息() {
        let base = Store.blankSettings()
        let short = RestPlan(minutes: 5, long: false)
        let long = RestPlan(minutes: 15, long: true)
        XCTAssertEqual(Store.restAfter(base, len: 25, beansToday: 1), short)
        let ten = RestPlan(minutes: 10, long: false)
        XCTAssertEqual(Store.restAfter(base, len: 50, beansToday: 3), ten)
        XCTAssertEqual(Store.restAfter(base, len: 25, beansToday: 4), long)
        XCTAssertEqual(Store.restAfter(base, len: 25, beansToday: 5), short)
        XCTAssertEqual(Store.restAfter(base, len: 5, beansToday: 8), long)
    }

    func test短休息選固定十分不管番茄多長都休十分() {
        var settings = Store.blankSettings()
        settings.restShort = .minutes(10)
        XCTAssertEqual(Store.restAfter(settings, len: 5, beansToday: 1).minutes, 10)
        XCTAssertEqual(Store.restAfter(settings, len: 90, beansToday: 2).minutes, 10)
    }

    func test長休息關掉第四顆也只是短休息() {
        var settings = Store.blankSettings()
        settings.restLongEvery = 0
        let short = RestPlan(minutes: 5, long: false)
        XCTAssertEqual(Store.restAfter(settings, len: 25, beansToday: 4), short)
    }

    func test長休息改成每三顆三十分() {
        var settings = Store.blankSettings()
        settings.restLongEvery = 3
        settings.restLongMinutes = 30
        let long = RestPlan(minutes: 30, long: true)
        XCTAssertEqual(Store.restAfter(settings, len: 25, beansToday: 3), long)
        XCTAssertFalse(Store.restAfter(settings, len: 25, beansToday: 4).long)
    }
}
