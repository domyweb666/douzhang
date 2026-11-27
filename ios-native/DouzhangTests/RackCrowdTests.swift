@testable import Douzhang
import XCTest

/// 時間軸擠在一起的那幾種：午夜前、別的時區收的、真的重疊。畫面上的高度在這裡用一小時 100 點算。
final class RackCrowdTests: XCTestCase {
    private let key = "2026-11-17"
    private let minHours = 0.25

    /// 畫出來：一塊接一塊不重疊、不在時間軸上面，最底下那塊也在撐高後的範圍裡。
    private func assertStacked(_ blocks: [DayBlock], line: UInt = #line) throws {
        let axis = try XCTUnwrap(RackCalendar.axisHours([blocks]), line: line)
        XCTAssertLessThan(axis.from, axis.upTo, line: line)
        let scale = RackCalendar.timeScale([blocks], axis: axis, hour: 100, flat: 20)
        XCTAssertEqual(Set(blocks.map(\.lanes)), [1], line: line)
        XCTAssertGreaterThanOrEqual(blocks.first?.top ?? -1, Double(axis.from), line: line)
        for (above, below) in zip(blocks, blocks.dropFirst()) {
            XCTAssertLessThanOrEqual(
                scale.offset(above.bottom),
                scale.offset(below.top) + 1e-9,
                line: line
            )
        }
        for block in blocks {
            let height = scale.offset(block.bottom) - scale.offset(block.top)
            XCTAssertGreaterThanOrEqual(height, minHours * 100 - 1e-9, line: line)
        }
    }

    func test午夜前擠的推到二十四點以下也不重疊() throws {
        let day = November.day(
            November.bean(17, 23, 50, len: 1),
            November.bean(17, 23, 53, len: 1),
            November.bean(17, 23, 56, len: 1)
        )
        let blocks = RackCalendar.dayBlocks(day, key: key, minHours: minHours)
        let first = 23 + 50.0 / 60
        for (index, block) in blocks.enumerated() {
            XCTAssertEqual(block.top, first + Double(index) * minHours, accuracy: 1e-9)
        }
        XCTAssertGreaterThan(blocks[2].bottom, 24)
        try assertStacked(blocks)
    }

    func test別的時區收的六顆都在這天之後往下排不擠成六欄() throws {
        var day = DayRecord()
        // 這天半夜前還有一顆真的
        day.beans = [November.bean(17, 23, 45, len: 15)]
            + (0 ..< 6).map { November.bean(18, 9 + $0, 0, len: 25) }
        let blocks = RackCalendar.dayBlocks(day, key: key, minHours: minHours, roomyHours: 0.5)
        XCTAssertEqual(blocks.count, 7)
        try assertStacked(blocks)
    }

    func test真的重疊的並排後面擠到的推到兩欄都空的地方() {
        let day = November.day(
            November.bean(17, 9, 0, len: 5),
            // 這顆跟下一顆真的重疊（兩台同時），又被上面那顆擠下來
            November.bean(17, 9, 6, len: 10),
            November.bean(17, 9, 10, len: 10),
            November.bean(17, 9, 25, len: 5)
        )
        let blocks = RackCalendar.dayBlocks(day, key: key, minHours: minHours)
        XCTAssertEqual(blocks.map(\.lanes), [1, 2, 2, 1])
        XCTAssertEqual(blocks.map(\.lane), [0, 0, 1, 0])
        XCTAssertEqual(blocks[1].top, 9 + minHours, accuracy: 1e-9)
        XCTAssertEqual(blocks[2].top, 9 + minHours, accuracy: 1e-9)
        XCTAssertEqual(blocks[3].top, 9 + minHours * 2, accuracy: 1e-9)
    }
}

/// 天檢視（多米 2026-11-27）：最矮放得下標籤名與長度，寫了字的下面有空才長。
final class RackDayTests: XCTestCase {
    private let key = "2026-11-17"

    func test天檢視最矮放得下標籤名與長度兩行() {
        let twoLines = Tokens.Layout.tight + Tokens.Rack.timelineLineDay * 2
        XCTAssertGreaterThanOrEqual(
            Tokens.Rack.timelineBlockMin,
            twoLines + Tokens.Rack.timelineLaneGap
        )
    }

    func test寫了在做什麼或筆記的下面有空才長到放得下沒寫的不長() {
        var wrote = November.bean(17, 9, 0, len: 5)
        wrote.clue = "寫完開頭"
        let plain = November.bean(17, 10, 0, len: 5)
        var squeezed = November.bean(17, 11, 0, len: 5)
        squeezed.doing = "寫稿"
        let next = November.bean(17, 11, 15, len: 25)
        let blocks = RackCalendar.dayBlocks(
            November.day(wrote, plain, squeezed, next),
            key: key,
            minHours: 0.25,
            wordyHours: 0.75
        )
        XCTAssertEqual(Array(blocks.map(\.height).prefix(2)), [0.75, 0.25])
        // 下一顆 15 分鐘後就開始：只長到碰到它為止
        XCTAssertEqual(blocks[2].height, 0.25, accuracy: 1e-9)
    }

    func test作廢有寫在做什麼也不跟著長() {
        var day = DayRecord()
        var voided = VoidEntry(
            voidedAt: Moment.local(2026, 11, 17, 10, 7),
            typeId: "t1",
            minute: 7,
            reason: "",
            text: ""
        )
        voided.doing = "寫稿"
        day.voids = [voided]
        let blocks = RackCalendar.dayBlocks(day, key: key, minHours: 0.25, wordyHours: 0.75)
        XCTAssertEqual(blocks.first?.height, 0.25)
    }
}
