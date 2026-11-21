@testable import Douzhang
import XCTest

/// 刪掉的標籤（.analytics/04-資料結構.md 邊界情況 15、16、17）：不丟、不併進別的標籤。
final class RemovedTagTests: XCTestCase {
    private let key = "2026-11-17"
    private let when = Moment.local(2026, 11, 17, 12)

    /// 第一個標籤一顆 25 分、第三個標籤一顆 50 分，然後把第三個標籤刪掉。
    private func removedThird() -> AppState {
        var state = Store.blank()
        state.days[key] = November.day(
            November.bean(17, 9, 0, len: 25),
            November.bean(17, 10, 0, len: 50, typeId: "t3")
        )
        return SettingsLogic.removeType(state, id: "t3", now: when)
    }

    func test刪掉的標籤搬到另一個清單名字與顏色都留著() throws {
        let third = Store.presetTypes[2]
        let state = removedThird()
        XCTAssertFalse(state.settings.types.contains { $0.id == "t3" })
        let removed = try XCTUnwrap(state.settings.removedTypes.first)
        XCTAssertEqual(removed.type, third)
        XCTAssertEqual(removed.removedAt, when)
        XCTAssertEqual(Machine.typeOf(state, "t3"), third)
    }

    func test已刪的標籤不會再開出新的一顆() {
        let state = removedThird()
        XCTAssertEqual(Machine.liveType(state, "t3").id, "t1")
        XCTAssertEqual(Machine.start(state, now: when, typeId: "t3").focusRun?.typeId, "t1")
    }

    func test升級前就刪掉的叫已刪除的標籤顏色沿用第一個() {
        let gone = Machine.typeOf(Store.blank(), "t-old")
        XCTAssertEqual(gone.id, Machine.goneTypeId)
        XCTAssertEqual(gone.name, Words.removedTag)
        XCTAssertEqual(gone.color, Store.defaultType.color)
    }

    func test很舊的資料沒有標籤照舊算在第一個() {
        XCTAssertEqual(Machine.typeOf(Store.blank(), "").id, "t1")
    }

    func test分析裡刪掉的標籤自己一列第一個標籤的時數不變() throws {
        let result = Stats.stats(removedThird(), keys: [key])
        XCTAssertEqual(result.minutes, 75)
        let first = try XCTUnwrap(result.tags.first(where: { $0.type.id == "t1" }))
        XCTAssertEqual(first.minutes, 25)
        XCTAssertFalse(first.removed)
        let third = try XCTUnwrap(result.tags.first(where: { $0.type.id == "t3" }))
        XCTAssertEqual(third.minutes, 50)
        XCTAssertTrue(third.removed)
        XCTAssertEqual(result.days.first?.parts.map(\.type.id), ["t1", "t3"])
    }

    func test升級前就刪掉的在分析裡合成一列() {
        var state = Store.blank()
        state.days[key] = November.day(
            November.bean(17, 9, 0, len: 25, typeId: "old-a"),
            November.bean(17, 10, 0, len: 25, typeId: "old-b"),
            November.bean(17, 11, 0, len: 25)
        )
        let result = Stats.stats(state, keys: [key])
        XCTAssertEqual(result.tags.map(\.type.id).sorted(), [Machine.goneTypeId, "t1"])
        let gone = result.tags.first(where: { $0.type.id == Machine.goneTypeId })
        XCTAssertEqual(gone?.minutes, 50)
        XCTAssertEqual(gone?.removed, false)
        XCTAssertEqual(result.days.first?.minutes, 75)
    }

    func test刪掉的標籤寫出去再讀回來還在() throws {
        let state = removedThird()
        let back = try StateDecoding.parse(StateEncoding.text(state))
        XCTAssertEqual(back.settings.removedTypes, state.settings.removedTypes)
    }

    func test跟現有標籤同編號的不當成刪掉的() throws {
        let clash = #"{"settings":{"removedTypes":[{"id":"t1","name":"撞號","len":25}]},"days":{}}"#
        XCTAssertTrue(try StateDecoding.parse(clash).settings.removedTypes.isEmpty)
    }

    func test清空之後刪掉的標籤也清掉() {
        XCTAssertTrue(Store.blank().settings.removedTypes.isEmpty)
    }
}
