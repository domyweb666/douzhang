@testable import Douzhang
import XCTest

/// 狀態機：開始、到點、收下、休息、回來、休息完自動開始。翻自 Expo 版 machine.test.js 還在用的條目。
final class MachineStartKeepTests: XCTestCase {
    private let base = Moment.local(2026, 11, 1, 9)
    private let minute = Moment.minute
    private let today = "2026-11-01"

    private func started() -> AppState {
        Machine.start(Store.blank(), now: base)
    }

    private func kept(_ text: String = "x") -> AppState {
        Machine.keep(started(), now: base + 25 * minute, text: text)
    }

    func test一句都沒寫也能直接開始() {
        XCTAssertEqual(Machine.phaseOf(started(), now: base), .focus)
    }

    func test不寫字直接收下照樣進帳() throws {
        let state = kept("")
        let beans = try XCTUnwrap(state.days[today]).beans
        XCTAssertEqual(beans.count, 1)
        XCTAssertEqual(beans[0].clue, "")
        XCTAssertEqual(Machine.phaseOf(state, now: base + 25 * minute), .rest)
    }

    func test開始後結束時刻等於現在加標籤長度() throws {
        let run = try XCTUnwrap(started().focusRun)
        XCTAssertEqual(run.typeId, "t1")
        XCTAssertEqual(run.len, 25)
        XCTAssertEqual(run.endAt, base + 25 * minute)
        XCTAssertEqual(run.startedAt, base)
    }

    func test測試顆五秒() throws {
        let state = Machine.start(Store.blank(), now: base, typeId: Machine.devTypeId)
        let run = try XCTUnwrap(state.focusRun)
        XCTAssertEqual(run.endAt, base + 5000)
    }

    func test到點那一刻變鈴響不另外存() {
        let state = started()
        XCTAssertEqual(Machine.phaseOf(state, now: base + 24 * minute), .focus)
        XCTAssertEqual(Machine.phaseOf(state, now: base + 25 * minute), .bell)
        XCTAssertEqual(Machine.phaseOf(state, now: base + 60 * minute), .bell)
    }

    func test收下後進休息二十五分休五分() throws {
        let now = base + 25 * minute
        let state = kept("把第三節也改成問句")
        let rest = try XCTUnwrap(state.restRun)
        XCTAssertEqual(rest.endAt, now + 5 * minute)
        XCTAssertEqual(Machine.phaseOf(state, now: now), .rest)
    }

    func test收下的番茄記在開始那天帶著那句與長度() throws {
        let beans = try XCTUnwrap(kept("下一句").days[today]).beans
        XCTAssertEqual(beans.count, 1)
        XCTAssertEqual(beans[0].typeId, "t1")
        XCTAssertEqual(beans[0].len, 25)
        XCTAssertEqual(beans[0].clue, "下一句")
        XCTAssertEqual(beans[0].start, base)
    }

    func test只有空白的字收下後那句是空的() throws {
        let beans = try XCTUnwrap(kept("   ").days[today]).beans
        XCTAssertEqual(beans[0].clue, "")
    }

    func test測試顆收下後休息也只有五秒() throws {
        let now = base + 5000
        let dev = Machine.start(Store.blank(), now: base, typeId: Machine.devTypeId)
        let rest = try XCTUnwrap(Machine.keep(dev, now: now, text: "x").restRun)
        XCTAssertEqual(rest.endAt, now + 5000)
    }

    func test不在計時中按收下什麼都不變() {
        let idle = Store.blank()
        XCTAssertEqual(Machine.keep(idle, now: base, text: "x"), idle)
    }

    func test回來後回待機() {
        let state = Machine.backFromRest(kept())
        XCTAssertNil(state.current)
        XCTAssertEqual(Machine.phaseOf(state, now: base + 26 * minute), .idle)
    }

    func test休息到點沒按也算回待機() {
        let resting = kept()
        let later = base + 31 * minute
        XCTAssertEqual(Machine.phaseOf(resting, now: later), .idle)
        XCTAssertNil(Machine.settle(resting, now: later).current)
        XCTAssertEqual(Machine.settle(resting, now: base + 27 * minute), resting)
    }

    func test響了沒理拖超過休息長度才收直接待機() throws {
        let rang = base + 25 * minute
        let state = Machine.keep(started(), now: rang + 5 * minute, text: "拖很久才寫的")
        XCTAssertNil(state.current)
        XCTAssertEqual(Machine.phaseOf(state, now: rang + 5 * minute), .idle)
        XCTAssertEqual(try XCTUnwrap(state.days[today]).beans.count, 1)
    }

    func test鈴響後在休息長度內收下照常休息() throws {
        let rang = base + 25 * minute
        let state = Machine.keep(started(), now: rang + 4 * minute, text: "x")
        let rest = try XCTUnwrap(state.restRun)
        XCTAssertEqual(rest.endAt, rang + 4 * minute + 5 * minute)
    }

    func test測試顆拖到剛好五秒才收也是直接待機() {
        let dev = Machine.start(Store.blank(), now: base, typeId: Machine.devTypeId)
        XCTAssertNil(Machine.keep(dev, now: base + 5000 + 5000, text: "x").current)
    }

    // MARK: 休息完自動開始

    /// 開了自動開始、收下第一顆之後的休息；休息到 base + 30 分。
    private func autoResting(restMode: RestMode = .auto) -> AppState {
        var blank = Store.blank()
        blank.settings.autoNext = true
        blank.settings.restMode = restMode
        let focusing = Machine.start(blank, now: base)
        return Machine.keep(focusing, now: base + 25 * minute, text: "x")
    }

    func test自動開始前先回待機一下休息那筆還留著() {
        let state = autoResting()
        let restEnd = base + 30 * minute
        XCTAssertEqual(Machine.phaseOf(state, now: restEnd + 1), .idle)
        XCTAssertEqual(Machine.settle(state, now: restEnd + 1), state)
    }

    func test自動開始的那顆同一個標籤開始時刻是算的() throws {
        let state = autoResting()
        let startAt = base + 30 * minute + Params.autoNextDelayMs
        let later = Machine.settle(state, now: startAt + 3 * minute)
        let run = try XCTUnwrap(later.focusRun)
        XCTAssertEqual(run.typeId, try XCTUnwrap(state.restRun).typeId)
        XCTAssertEqual(run.startedAt, startAt)
        XCTAssertEqual(Machine.phaseOf(later, now: startAt + 3 * minute), .focus)
    }

    func test在背景待太久下一顆也到點回來就是鈴響() {
        let now = base + 30 * minute + Params.autoNextDelayMs + 40 * minute
        let later = Machine.settle(autoResting(), now: now)
        XCTAssertEqual(Machine.phaseOf(later, now: now), .bell)
    }

    func test沒開或自己決定的休息不自動開始() {
        let off = kept()
        let afterDelay = base + 30 * minute + Params.autoNextDelayMs + minute
        XCTAssertNil(Machine.settle(off, now: afterDelay).current)
        let own = autoResting(restMode: .own)
        XCTAssertEqual(Machine.settle(own, now: base + 3 * 60 * minute), own)
    }
}
