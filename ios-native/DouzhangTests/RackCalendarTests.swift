@testable import Douzhang
import XCTest

/// 2026 年 11 月的測試資料：一顆番茄幾號、幾點幾分開始、多長、哪個標籤。
enum November {
    static func bean(
        _ day: Int,
        _ hour: Int,
        _ past: Int,
        len: Double,
        typeId: String = "t1",
        flow: Double = 0
    ) -> Bean {
        let start = Moment.local(2026, 11, day, hour, past)
        return Bean(
            keptAt: start + len * Moment.minute,
            typeId: typeId,
            len: len,
            clue: "",
            notes: [],
            pings: [],
            flow: flow,
            start: start
        )
    }

    static func day(_ beans: Bean...) -> DayRecord {
        DayRecord(beans: beans, voids: [])
    }
}

/// 番茄架行事曆的計算。翻自 Expo 版 calendar.test.js。
final class RackCalendarTests: XCTestCase {
    /// 畫面上最矮 28、一小時 64
    private let minHours = 28.0 / 64.0
    private let key = "2026-11-17"

    private func lanes(_ blocks: [DayBlock]) -> [[Int]] {
        blocks.map { [$0.lane, $0.lanes] }
    }

    func test天是那一天三天是那天與前兩天週是週一到週日() {
        XCTAssertEqual(RackCalendar.viewDays(.day, selected: key), [key])
        let three = ["2026-11-15", "2026-11-16", "2026-11-17"]
        XCTAssertEqual(RackCalendar.viewDays(.three, selected: key), three)
        let week = RackCalendar.viewDays(.week, selected: key)
        XCTAssertEqual(week.first, "2026-11-16")
        XCTAssertEqual(week.last, "2026-11-22")
    }

    func test換一段天動一天三天動三天週動一週月跳到一號() {
        XCTAssertEqual(RackCalendar.shiftPeriod(.day, selected: key, step: -1), "2026-11-16")
        XCTAssertEqual(RackCalendar.shiftPeriod(.three, selected: key, step: -1), "2026-11-14")
        XCTAssertEqual(RackCalendar.shiftPeriod(.week, selected: key, step: -1), "2026-11-09")
        XCTAssertEqual(RackCalendar.shiftPeriod(.month, selected: key, step: -1), "2026-10-01")
    }

    func test畫面上有今天就不能再往後翻() {
        let today = key
        XCTAssertTrue(RackCalendar.reachesToday(.day, selected: key, todayKey: today))
        XCTAssertFalse(RackCalendar.reachesToday(.day, selected: "2026-11-16", todayKey: today))
        XCTAssertTrue(RackCalendar.reachesToday(.week, selected: "2026-11-16", todayKey: today))
        XCTAssertFalse(RackCalendar.reachesToday(.week, selected: "2026-11-09", todayKey: today))
        XCTAssertTrue(RackCalendar.reachesToday(.month, selected: "2026-11-03", todayKey: today))
        XCTAssertFalse(RackCalendar.reachesToday(.month, selected: "2026-10-03", todayKey: today))
    }

    func test隔得開的各佔整欄位置與高度的單位是小時() {
        let day = November.day(November.bean(17, 9, 0, len: 30), November.bean(17, 11, 0, len: 60))
        let blocks = RackCalendar.dayBlocks(day, key: key, minHours: minHours)
        XCTAssertEqual(blocks.map(\.top), [9, 11])
        XCTAssertEqual(blocks.map(\.height), [0.5, 1])
        XCTAssertEqual(lanes(blocks), [[0, 1], [0, 1]])
    }

    func test兩顆很短又很近的左右並排各佔一半() {
        let day = November.day(November.bean(17, 5, 0, len: 5), November.bean(17, 5, 8, len: 5))
        let blocks = RackCalendar.dayBlocks(day, key: key, minHours: minHours)
        XCTAssertEqual(lanes(blocks), [[0, 2], [1, 2]])
        // 再短也畫到最小高度
        XCTAssertEqual(blocks[0].height, minHours)
    }

    func test空出來的欄會被後面的重疊補上都結束後回到整欄() {
        let day = November.day(
            November.bean(17, 9, 0, len: 60),
            November.bean(17, 9, 10, len: 20),
            November.bean(17, 9, 40, len: 20),
            November.bean(17, 11, 0, len: 25)
        )
        let blocks = RackCalendar.dayBlocks(day, key: key, minHours: minHours)
        XCTAssertEqual(lanes(blocks), [[0, 2], [1, 2], [1, 2], [0, 1]])
    }

    func test跨過午夜的只畫到當天二十四點延長算進長度() throws {
        let lateDay = November.day(November.bean(17, 23, 30, len: 50))
        let late = try XCTUnwrap(
            RackCalendar.dayBlocks(lateDay, key: key, minHours: minHours).first
        )
        XCTAssertEqual(late.top + late.height, 24)
        let flowedDay = November.day(November.bean(17, 9, 0, len: 25, flow: 15))
        let flowed = RackCalendar.dayBlocks(flowedDay, key: key, minHours: minHours)
        XCTAssertEqual(flowed[0].height, 40.0 / 60.0, accuracy: 1e-9)
    }

    func test作廢也排進去沒東西的日子是空的() {
        var day = DayRecord()
        let voidedAt = Moment.local(2026, 11, 17, 10, 7)
        day.voids = [VoidEntry(voidedAt: voidedAt, typeId: "t1", minute: 7, reason: "", text: "")]
        let blocks = RackCalendar.dayBlocks(day, key: key, minHours: minHours)
        XCTAssertEqual(blocks.first?.item.kind, .voided)
        XCTAssertEqual(RackCalendar.dayBlocks(nil, key: key, minHours: minHours), [])
    }

    func test共用的時間軸前後各多一小時幾天取聯集() {
        let first = RackCalendar.dayBlocks(
            November.day(November.bean(16, 9, 30, len: 25)),
            key: "2026-11-16",
            minHours: minHours
        )
        let second = RackCalendar.dayBlocks(
            November.day(November.bean(17, 14, 10, len: 50)),
            key: key,
            minHours: minHours
        )
        XCTAssertEqual(RackCalendar.axisHours([first, second]), AxisHours(from: 8, upTo: 16))
    }

    func test時間軸不會畫出零點以前二十四點以後都沒東西是空的() {
        let day = November.day(November.bean(17, 0, 10, len: 25), November.bean(17, 23, 0, len: 50))
        let blocks = RackCalendar.dayBlocks(day, key: key, minHours: minHours)
        XCTAssertEqual(RackCalendar.axisHours([blocks]), AxisHours(from: 0, upTo: 24))
        XCTAssertNil(RackCalendar.axisHours([[], []]))
    }
}
