@testable import Douzhang
import XCTest

/// 卡格計的算法：幾格、最長一格、掉幾格。
final class FrameTallyTests: XCTestCase {
    func test每一格都準時就沒有掉格() {
        var tally = FrameTally()
        for _ in 0 ..< 10 {
            tally.add(gap: 1.0 / 60, expected: 1.0 / 60)
        }
        XCTAssertEqual(tally.frames, 10)
        XCTAssertEqual(tally.dropped, 0)
        XCTAssertEqual(tally.longest, 1.0 / 60, accuracy: 1e-9)
    }

    func test隔了三格的時間才畫下一格算掉兩格() {
        var tally = FrameTally()
        tally.add(gap: 1.0 / 120, expected: 1.0 / 120)
        tally.add(gap: 3.0 / 120, expected: 1.0 / 120)
        XCTAssertEqual(tally.dropped, 2)
        XCTAssertEqual(tally.longest, 3.0 / 120, accuracy: 1e-9)
    }

    func test時刻晚一點點不算掉格() {
        var tally = FrameTally()
        tally.add(gap: 0.0175, expected: 1.0 / 60)
        XCTAssertEqual(tally.dropped, 0)
    }

    func test時間沒走的不記() {
        var tally = FrameTally()
        tally.add(gap: 0, expected: 1.0 / 60)
        XCTAssertEqual(tally, FrameTally())
    }
}
