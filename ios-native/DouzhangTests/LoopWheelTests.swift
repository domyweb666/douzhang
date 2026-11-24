@testable import Douzhang
import XCTest

/// 循環滾輪：90 下面接 1、值從外面改時走近的那邊。照蒜日子的 LoopWheelRules 測試，換成 90 格。
final class LoopWheelTests: XCTestCase {
    private let count = 90

    private func middle(_ index: Int) -> Int {
        LoopWheelRules.middleRow(index: index, count: count)
    }

    private func nearest(_ index: Int, from row: Int) -> Int {
        LoopWheelRules.nearestRow(toIndex: index, from: row, count: count)
    }

    func test最後一格下面接第一格第一格上面接最後一格() {
        let last = middle(89)
        XCTAssertEqual(LoopWheelRules.index(ofRow: last, count: count), 89)
        XCTAssertEqual(LoopWheelRules.index(ofRow: last + 1, count: count), 0)
        XCTAssertEqual(LoopWheelRules.index(ofRow: middle(0) - 1, count: count), 89)
        XCTAssertEqual(LoopWheelRules.index(ofRow: -1, count: count), 89)
    }

    func test打開時上下都還有好幾輪可以滾() {
        XCTAssertGreaterThan(middle(0), count * 3)
        XCTAssertLessThan(middle(89), LoopWheelRules.rowCount(count) - count * 3)
    }

    func test值從外面改時走近的那邊() {
        XCTAssertEqual(nearest(0, from: middle(89)), middle(89) + 1)
        XCTAssertEqual(nearest(88, from: middle(0)), middle(0) - 2)
        XCTAssertEqual(nearest(24, from: middle(24)), middle(24))
    }

    func test快到長條頭尾就回中間那一輪() {
        let end = LoopWheelRules.rowCount(count) - 1
        XCTAssertEqual(nearest(0, from: end), middle(0))
        XCTAssertEqual(nearest(89, from: 0), middle(89))
    }

    func test沒有值時不會除以零() {
        XCTAssertEqual(LoopWheelRules.index(ofRow: 5, count: 0), 0)
        XCTAssertEqual(LoopWheelRules.nearestRow(toIndex: 0, from: 5, count: 0), 0)
    }
}
