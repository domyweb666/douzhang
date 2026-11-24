@testable import Douzhang
import XCTest

/// 正在做什麼：待機先填、開始時抄進這顆、途中可改、收下與作廢抄進紀錄（QC-0003 第 16、22 筆）。
final class DoingTests: XCTestCase {
    private let base = Moment.local(2026, 11, 24, 9)
    private let minute = Moment.minute
    private let today = "2026-11-24"

    private func started(_ line: String = "寫第三節") -> AppState {
        Machine.start(Machine.setDoing(Store.blank(), text: line), now: base)
    }

    func test待機填的開始時抄進這顆() {
        XCTAssertEqual(started().focusRun?.doing, "寫第三節")
        XCTAssertEqual(Machine.start(Store.blank(), now: base).focusRun?.doing, "")
    }

    func test計時中改這一顆的同時留給下一顆() {
        let changed = Machine.setDoing(started(), text: "回編輯的信")
        XCTAssertEqual(changed.focusRun?.doing, "回編輯的信")
        XCTAssertEqual(changed.doing, "回編輯的信")
        // 只改那句，倒數不動
        XCTAssertEqual(changed.focusRun?.endAt, base + 25 * minute)
    }

    func test收下抄進番茄下一顆還留著同一句() throws {
        let kept = Machine.keep(started(), now: base + 25 * minute, text: "")
        XCTAssertEqual(try XCTUnwrap(kept.days[today]?.beans.first).doing, "寫第三節")
        XCTAssertEqual(kept.doing, "寫第三節")
        let next = Machine.start(Machine.backFromRest(kept), now: base + 40 * minute)
        XCTAssertEqual(next.focusRun?.doing, "寫第三節")
    }

    func test作廢抄進那一筆() throws {
        let state = Machine.voidBean(started(), now: base + 8 * minute)
        XCTAssertEqual(try XCTUnwrap(state.days[today]?.voids.first).doing, "寫第三節")
        XCTAssertEqual(state.doing, "寫第三節")
    }

    func test休息中改的是下一顆休息那筆不動() {
        let resting = Machine.keep(started(), now: base + 25 * minute, text: "")
        let changed = Machine.setDoing(resting, text: "校稿")
        XCTAssertEqual(changed.doing, "校稿")
        XCTAssertEqual(changed.restRun, resting.restRun)
    }

    func test頭尾空白去掉最多六十字空的就是清掉() {
        let long = String(repeating: "字", count: 70)
        XCTAssertEqual(Machine.setDoing(Store.blank(), text: "  \(long) ").doing.count, 60)
        XCTAssertEqual(Machine.setDoing(started(), text: "   ").focusRun?.doing, "")
    }

    func test存了再讀一模一樣() throws {
        var state = Machine.voidBean(started(), now: base + 8 * minute)
        state = Machine.keep(
            Machine.start(state, now: base + 10 * minute),
            now: base + 35 * minute,
            text: ""
        )
        state = Machine.start(Machine.backFromRest(state), now: base + 50 * minute)
        XCTAssertEqual(try StateDecoding.parse(StateEncoding.text(state)), state)
    }

    func test舊檔沒有這一欄就是空的不是字串也當空的() throws {
        let text = """
        {"doing":3,"settings":{},"current":{"phase":"focus","len":25,"startedAt":1,"endAt":2},
         "days":{"2026-10-30":{"beans":[{"t":1,"len":25}],"voids":[{"t":2,"minute":6}]}}}
        """
        let state = try StateDecoding.parse(text)
        XCTAssertEqual(state.doing, "")
        XCTAssertEqual(state.focusRun?.doing, "")
        XCTAssertEqual(state.days["2026-10-30"]?.beans.map(\.doing), [""])
        XCTAssertEqual(state.days["2026-10-30"]?.voids.map(\.doing), [""])
    }
}
