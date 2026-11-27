@testable import Douzhang
import XCTest

/// 鎖定畫面與動態島那張卡：四態畫什麼、到點（過期）後自己換成哪一態、什麼時候收掉。
final class LivePlanTests: XCTestCase {
    private let base = Moment.local(2026, 11, 27, 9)
    private let minute = Moment.minute

    private func date(_ time: Millis) -> Date {
        Date(timeIntervalSince1970: time / Params.msPerSecond)
    }

    private func focusing(_ state: AppState = Store.blank()) -> AppState {
        Machine.start(state, now: base)
    }

    /// 25 分那顆在到點那一刻收下，進休息
    private func resting(_ state: AppState = Store.blank()) -> AppState {
        Machine.keep(focusing(state), now: base + 25 * minute, text: "")
    }

    // MARK: 四態

    func test計時中倒數到這顆的結束時刻到點過期() throws {
        let state = focusing()
        let run = try XCTUnwrap(state.focusRun)
        let card = LivePlan.card(state, now: base + minute)
        XCTAssertEqual(card.stage, .focus)
        XCTAssertEqual(card.typeId, run.typeId)
        XCTAssertEqual(card.endAt, date(run.endAt))
        XCTAssertEqual(LivePlan.staleDate(card), date(run.endAt))
        XCTAssertEqual(card.timerRange(for: .focus), date(run.startedAt) ... date(run.endAt))
        XCTAssertEqual(card.note(for: .focus), "")
        XCTAssertFalse(card.startsFrom(.focus))
    }

    func test響了還沒收寫熟了不倒數沒有開始鈕() {
        let card = LivePlan.card(focusing(), now: base + 26 * minute)
        XCTAssertEqual(card.stage, .bell)
        XCTAssertNil(card.timerRange(for: .bell))
        XCTAssertEqual(card.headline(for: .bell), Words.liveRipe)
        XCTAssertNil(LivePlan.staleDate(card))
        XCTAssertFalse(card.startsFrom(.bell))
    }

    func test休息中倒數到休息結束旁邊寫休息中() throws {
        let state = resting()
        let rest = try XCTUnwrap(state.restRun)
        let restEnd = try XCTUnwrap(rest.endAt)
        let card = LivePlan.card(state, now: base + 26 * minute)
        XCTAssertEqual(card.stage, .rest)
        XCTAssertEqual(card.endAt, date(restEnd))
        XCTAssertEqual(LivePlan.staleDate(card), date(restEnd))
        XCTAssertNotNil(card.timerRange(for: .rest))
        XCTAssertEqual(card.note(for: .rest), Words.liveResting)
        XCTAssertFalse(card.startsFrom(.rest))
    }

    func test我自己決定的休息不倒數也不會過期() {
        var state = Store.blank()
        state.settings.restMode = .own
        let card = LivePlan.card(resting(state), now: base + 26 * minute)
        XCTAssertEqual(card.stage, .rest)
        XCTAssertNil(card.endAt)
        XCTAssertNil(LivePlan.staleDate(card))
        XCTAssertNil(card.timerRange(for: .rest))
        XCTAssertEqual(card.headline(for: .rest), Words.liveResting)
        XCTAssertEqual(card.shown(at: date(base + 600 * minute), isStale: true), .rest)
    }

    func test待機開設定選中的標籤大字寫一顆多長() {
        let state = Store.blank()
        let card = LivePlan.card(state, now: base)
        let type = Machine.liveType(state, state.settings.typeId)
        XCTAssertEqual(card.stage, .idle)
        XCTAssertEqual(card.typeId, state.settings.typeId)
        XCTAssertEqual(card.name, type.name)
        XCTAssertEqual(card.headline(for: .idle), Words.typeLen(type.len))
        XCTAssertEqual(card.note(for: .idle), Words.restDone)
        XCTAssertTrue(card.startsFrom(.idle))
        XCTAssertEqual(card.tint, LivePlan.hex(Tokens.Tomato.body(type.color)))
    }

    func test今天收了幾顆() {
        let card = LivePlan.card(resting(), now: base + 26 * minute)
        XCTAssertEqual(card.kept, 1)
        XCTAssertEqual(LivePlan.card(Store.blank(), now: base).kept, 0)
    }

    // MARK: 到點、過期之後畫哪一態（app 不在前景時沒人換卡片）

    func test計時中到點或過期就畫成熟了() throws {
        let state = focusing()
        let endAt = try date(XCTUnwrap(state.focusRun).endAt)
        let card = LivePlan.card(state, now: base)
        XCTAssertEqual(card.shown(at: endAt.addingTimeInterval(-1), isStale: false), .focus)
        XCTAssertEqual(card.shown(at: endAt, isStale: false), .bell)
        XCTAssertEqual(card.shown(at: endAt.addingTimeInterval(-1), isStale: true), .bell)
        XCTAssertNil(card.timerRange(for: .bell))
        XCTAssertFalse(card.startsFrom(.bell))
    }

    func test休息到點就畫成休息完有開始鈕() throws {
        let state = resting()
        let endAt = try date(XCTUnwrap(XCTUnwrap(state.restRun).endAt))
        let card = LivePlan.card(state, now: base + 26 * minute)
        XCTAssertEqual(card.shown(at: endAt.addingTimeInterval(-1), isStale: false), .rest)
        let shown = card.shown(at: endAt, isStale: true)
        XCTAssertEqual(shown, .idle)
        XCTAssertNil(card.timerRange(for: shown))
        XCTAssertEqual(card.note(for: shown), Words.restDone)
        XCTAssertTrue(card.startsFrom(shown))
        XCTAssertEqual(card.typeId, state.restRun?.typeId)
    }

    func test休息完會自己開始下一顆的不放開始鈕() {
        var state = Store.blank()
        state.settings.autoNext = true
        let card = LivePlan.card(resting(state), now: base + 26 * minute)
        XCTAssertTrue(card.autoNext)
        XCTAssertFalse(card.startsFrom(card.shown(at: .distantFuture, isStale: true)))
    }

    func test倒數起點晚於終點也不會當掉() {
        var card = LivePlan.card(focusing(), now: base)
        card.startAt = card.endAt?.addingTimeInterval(60)
        let range = card.timerRange(for: .focus)
        XCTAssertEqual(range?.lowerBound, card.endAt)
    }

    // MARK: 什麼時候收掉

    func test從計時中或熟了直接回待機就收掉() {
        let idle = LivePlan.card(Store.blank(), now: base)
        let focus = LivePlan.card(focusing(), now: base)
        let bell = LivePlan.card(focusing(), now: base + 26 * minute)
        XCTAssertTrue(LivePlan.shouldEnd(shown: focus, next: idle, now: date(base)))
        XCTAssertTrue(LivePlan.shouldEnd(shown: bell, next: idle, now: date(base)))
        XCTAssertFalse(LivePlan.shouldEnd(shown: focus, next: bell, now: date(base)))
    }

    func test休息完回待機留著待機太久才收() {
        let rest = LivePlan.card(resting(), now: base + 26 * minute)
        var idle = LivePlan.card(Store.blank(), now: base)
        XCTAssertFalse(LivePlan.shouldEnd(shown: rest, next: idle, now: date(base)))
        idle.idleSince = date(base)
        let limitAt = base + Params.liveIdleHours * Params.msPerHour
        XCTAssertFalse(LivePlan.shouldEnd(shown: idle, next: idle, now: date(limitAt - minute)))
        XCTAssertTrue(LivePlan.shouldEnd(shown: idle, next: idle, now: date(limitAt)))
    }

    func test色碼換回來是同一個顏色() {
        XCTAssertEqual(LivePlan.hex(RGB(hex: 0xE4472F)), 0xE4472F)
        XCTAssertEqual(LivePlan.hex(RGB(hex: 0x6FAE52)), 0x6FAE52)
    }
}
