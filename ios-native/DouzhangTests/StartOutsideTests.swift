@testable import Douzhang
import XCTest

/// 從捷徑、Siri、動作按鈕開始一顆：什麼時候真的開始、什麼時候只打開 app。
final class StartOutsideTests: XCTestCase {
    private let base = Moment.local(2026, 11, 25, 9)
    private let minute = Moment.minute

    private func outside(_ state: AppState, at time: Millis) -> AppState? {
        Machine.startFromOutside(state, now: time, zone: "Asia/Taipei")
    }

    func test待機用選中的標籤開始() throws {
        var state = Store.blank()
        state.settings.typeId = "t2"
        let run = try XCTUnwrap(outside(state, at: base)?.focusRun)
        XCTAssertEqual(run.typeId, "t2")
        XCTAssertEqual(run.startedAt, base)
        XCTAssertEqual(run.endAt, base + 50 * minute)
        XCTAssertEqual(run.zone, "Asia/Taipei")
    }

    func test正在計時不動那一顆() {
        let state = Machine.start(Store.blank(), now: base)
        XCTAssertNil(outside(state, at: base + minute))
    }

    func test響了還沒收不動那一顆() {
        let state = Machine.start(Store.blank(), now: base)
        XCTAssertNil(outside(state, at: base + 30 * minute))
    }

    func test休息中照選中的標籤開始番茄還在() throws {
        var kept = Machine.keep(
            Machine.start(Store.blank(), now: base),
            now: base + 25 * minute,
            text: ""
        )
        XCTAssertEqual(kept.restRun?.typeId, "t1")
        kept.settings.typeId = "t2"
        let next = try XCTUnwrap(outside(kept, at: base + 26 * minute))
        XCTAssertEqual(next.focusRun?.typeId, "t2")
        XCTAssertEqual(next.focusRun?.startedAt, base + 26 * minute)
        XCTAssertEqual(next.days, kept.days)
    }

    func test自動開始前的空檔開得起來開了以後不動() {
        var state = Store.blank()
        state.settings.autoNext = true
        let kept = Machine.keep(
            Machine.start(state, now: base),
            now: base + 25 * minute,
            text: ""
        )
        let restEnd = base + 30 * minute
        let gap = Machine.settle(kept, now: restEnd + 1)
        XCTAssertEqual(outside(gap, at: restEnd + 1)?.focusRun?.startedAt, restEnd + 1)
        let begun = Machine.settle(kept, now: restEnd + Params.autoNextDelayMs)
        XCTAssertNil(outside(begun, at: restEnd + Params.autoNextDelayMs))
    }

    func test我自己決定的休息也開得起來() {
        var state = Store.blank()
        state.settings.restMode = .own
        let kept = Machine.keep(
            Machine.start(state, now: base),
            now: base + 25 * minute,
            text: ""
        )
        XCTAssertNotNil(outside(kept, at: base + 90 * minute)?.focusRun)
    }

    @MainActor
    func test那張便條拿一次就沒了() {
        let ask = StartAsk()
        XCTAssertFalse(ask.take())
        ask.ask()
        ask.ask()
        XCTAssertTrue(ask.take())
        XCTAssertFalse(ask.take())
    }
}
