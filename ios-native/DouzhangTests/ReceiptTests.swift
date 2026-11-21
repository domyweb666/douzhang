@testable import Douzhang
import XCTest

/// 日期鍵的加減、一天的收據、時間軸、小計。翻自 Expo 版 receipt.test.js 還在用的條目。
final class ReceiptTests: XCTestCase {
    private let minute = Moment.minute

    private func bean(_ time: Millis, len: Double, flow: Double = 0, start: Millis? = nil) -> Bean {
        Bean(
            keptAt: time,
            typeId: "t1",
            len: len,
            clue: "",
            notes: [],
            pings: [],
            flow: flow,
            start: start
        )
    }

    /// 10/26 那天：9 點收一顆（延長 15）、10 點收一顆 50 分的、11 點收一顆、12 點作廢一筆。
    private func monday() -> DayRecord {
        var day = DayRecord()
        day.beans = [
            bean(Moment.local(2026, 10, 26, 9), len: 25, flow: 15),
            bean(Moment.local(2026, 10, 26, 10), len: 50),
            bean(Moment.local(2026, 10, 26, 11), len: 25),
        ]
        let voided = VoidEntry(
            voidedAt: Moment.local(2026, 10, 26, 12),
            typeId: "t1",
            minute: 7,
            reason: "訊息",
            text: ""
        )
        day.voids = [voided]
        return day
    }

    func test週從週一起算() {
        XCTAssertEqual(DayKeys.weekStart("2026-10-26"), "2026-10-26")
        XCTAssertEqual(DayKeys.weekStart("2026-10-30"), "2026-10-26")
        XCTAssertEqual(DayKeys.weekStart("2026-11-01"), "2026-10-26")
        XCTAssertEqual(DayKeys.weekStart("2026-11-02"), "2026-11-02")
    }

    func test這週七天從週一排到週日換週各七天() {
        let expected = [
            "2026-10-26",
            "2026-10-27",
            "2026-10-28",
            "2026-10-29",
            "2026-10-30",
            "2026-10-31",
            "2026-11-01",
        ]
        XCTAssertEqual(DayKeys.weekDays("2026-10-26"), expected)
        XCTAssertEqual(DayKeys.shiftWeek("2026-10-26", weeks: 1), "2026-11-02")
        XCTAssertEqual(DayKeys.shiftWeek("2026-10-26", weeks: -1), "2026-10-19")
    }

    func test前後幾天與幾個月跨月跨年也對() {
        XCTAssertEqual(DayKeys.shift("2026-11-01", days: -1), "2026-10-31")
        XCTAssertEqual(DayKeys.shiftMonth("2026-12-31", months: 2), "2027-02-01")
        XCTAssertEqual(DayKeys.shiftMonth("2026-11-17", months: 0), "2026-11-01")
        XCTAssertEqual(DayKeys.weekdayIndex("2026-11-01"), 6)
    }

    func test讀不懂的日期鍵原樣回去不當掉() {
        XCTAssertEqual(DayKeys.shift("oops", days: 3), "oops")
        XCTAssertEqual(DayKeys.weekStart("2026-13"), "2026-13")
        XCTAssertEqual(DayKeys.start("oops"), 0)
    }

    func test空的一天沒有紀錄有番茄或作廢才算() {
        XCTAssertFalse(Receipt.hasRecord(DayRecord()))
        XCTAssertFalse(Receipt.hasRecord(nil))
        XCTAssertTrue(Receipt.hasRecord(monday()))
        var state = Store.blank()
        XCTAssertFalse(Receipt.hasAnyRecord(state))
        state.days["2026-10-26"] = monday()
        XCTAssertTrue(Receipt.hasAnyRecord(state))
    }

    func test番茄串上的格子依時間排五十分那顆兩單位() {
        let items = Receipt.podItems(monday())
        XCTAssertEqual(items.map(\.kind), [.bean, .bean, .bean, .voided])
        XCTAssertEqual(items.map(\.units), [1, 2, 1, 1])
    }

    func test一天的收據依時間排延長與雙番茄有標記() {
        let rows = Receipt.rows(monday())
        XCTAssertEqual(rows.map(\.kind), [.bean, .bean, .bean, .voided])
        XCTAssertEqual(rows[0].flow, 15)
        XCTAssertEqual(rows[0].clue, "")
        XCTAssertTrue(rows[1].isDouble)
        XCTAssertFalse(rows[2].isDouble)
        XCTAssertEqual(rows[3].minute, 7)
        XCTAssertEqual(rows[3].reason, "訊息")
    }

    func test時間軸番茄照開始排長度含延長作廢倒推() {
        let items = Receipt.timeline(monday())
        XCTAssertEqual(items.map(\.kind), [.bean, .bean, .bean, .voided])
        // 舊資料沒有開始時刻，用收下時刻倒推長度
        XCTAssertEqual(items[0].start, Moment.local(2026, 10, 26, 9) - 25 * minute)
        XCTAssertEqual(items[0].end - items[0].start, (25 + 15) * minute)
        XCTAssertEqual(items[3].start, Moment.local(2026, 10, 26, 12) - 7 * minute)
    }

    func test有開始時刻的用開始時刻空的日子沒有時間軸() {
        var day = DayRecord()
        let start = Moment.local(2026, 11, 2, 10)
        day.beans = [bean(Moment.local(2026, 11, 2, 15), len: 25, start: start)]
        XCTAssertEqual(Receipt.timeline(day).first?.start, start)
        XCTAssertEqual(Receipt.timeline(DayRecord()), [])
        XCTAssertEqual(Receipt.timeline(nil), [])
    }

    func test一天的小計含延長沒番茄不寫() {
        XCTAssertEqual(Receipt.daySum(monday()), DaySum(beans: 3, minutes: 115))
        XCTAssertNil(Receipt.daySum(DayRecord()))
        XCTAssertNil(Receipt.daySum(nil))
    }
}
