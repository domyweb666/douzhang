@testable import Douzhang
import XCTest

/// 鈴響收據下面的念頭與有人找：一筆一列，沒寫字的合成一列。
final class JottedTests: XCTestCase {
    func test有寫字的一筆一列沒寫字的合成最後一列() {
        let rows = Jotted.rows(.pings, ["去買早餐", "", ""])
        XCTAssertEqual(rows.map(\.label), [Words.notePing, Words.jotTimes(.pings, 2)])
        XCTAssertEqual(rows.map(\.text), ["去買早餐", ""])
        XCTAssertEqual(Set(rows.map(\.kind)), [.pings])
    }

    func test清單空就一列都沒有() {
        XCTAssertTrue(Jotted.rows(.notes, []).isEmpty)
    }
}
