@testable import Douzhang
import XCTest

/// 狀態機：休息的兩種模式、收下後那句、長休息。翻自 Expo 版 machine.test.js。
final class MachineRestTests: XCTestCase {
    private let base = Moment.local(2026, 11, 1, 9)
    private let minute = Moment.minute
    private let today = "2026-11-01"

    private func blank(restMode: RestMode = .auto, longEvery: Int = 4) -> AppState {
        var state = Store.blank()
        state.settings.restMode = restMode
        state.settings.restLongEvery = longEvery
        return state
    }

    private func keptOnce(_ from: AppState) -> AppState {
        Machine.keep(Machine.start(from, now: base), now: base + 25 * minute, text: "x")
    }

    /// 連續收 count 顆 25 分的，每顆之間休息 5 分就回來；回最後一次收下後的狀態與收下那一刻。
    private func keepMany(_ from: AppState, _ count: Int) -> (state: AppState, lastKeep: Millis) {
        var state = from
        var clock = base
        for index in 0 ..< count {
            if index > 0 {
                state = Machine.backFromRest(state)
            }
            let focusing = Machine.start(state, now: clock)
            state = Machine.keep(focusing, now: clock + 25 * minute, text: "x")
            clock += 30 * minute
        }
        return (state, clock - 5 * minute)
    }

    // MARK: 兩種休息

    func test到點提醒的休息有結束時刻到點自己回待機() throws {
        let state = keptOnce(blank())
        XCTAssertEqual(try XCTUnwrap(state.restRun).endAt, base + 30 * minute)
        XCTAssertEqual(Machine.phaseOf(state, now: base + 31 * minute), .idle)
    }

    func test我自己決定的休息放一小時還是休息按回來才結束() throws {
        let state = keptOnce(blank(restMode: .own))
        XCTAssertNil(try XCTUnwrap(state.restRun).endAt)
        XCTAssertEqual(Machine.phaseOf(state, now: base + 85 * minute), .rest)
        XCTAssertEqual(Machine.settle(state, now: base + 85 * minute), state)
        XCTAssertNil(Machine.backFromRest(state).current)
    }

    func test收下後那句從詞彙表裡抽記進上次那句() throws {
        let state = keptOnce(blank())
        let rest = try XCTUnwrap(state.restRun)
        XCTAssertTrue(Words.restLines.contains(rest.msg))
        XCTAssertEqual(Words.restLines[state.lastLine], rest.msg)
    }

    func test抽到跟上一次同一句時改抽下一句() {
        XCTAssertEqual(Machine.pickLine(after: -1, roll: 9), 9)
        XCTAssertEqual(Machine.pickLine(after: 9, roll: 9), 10)
        let last = Words.restLines.count - 1
        XCTAssertEqual(Machine.pickLine(after: last, roll: last), 0)
    }

    func test連續收兩顆不會抽到同一句() {
        for _ in 0 ..< 50 {
            let first = keptOnce(blank())
            let second = keptOnce(Machine.backFromRest(first))
            XCTAssertNotEqual(first.lastLine, second.lastLine)
        }
    }

    // MARK: 長休息

    func test今天第三顆是短休息第四顆是十五分的長休息() throws {
        let third = keepMany(blank(), 3)
        let thirdRest = try XCTUnwrap(third.state.restRun)
        XCTAssertFalse(thirdRest.long)
        XCTAssertEqual(thirdRest.endAt, third.lastKeep + 5 * minute)
        let fourth = keepMany(blank(), 4)
        let fourthRest = try XCTUnwrap(fourth.state.restRun)
        XCTAssertTrue(fourthRest.long)
        XCTAssertEqual(fourthRest.endAt, fourth.lastKeep + 15 * minute)
    }

    func test作廢的不算顆數() throws {
        var state = Machine.backFromRest(keepMany(blank(), 3).state)
        state = Machine.start(state, now: base + 120 * minute)
        state = Machine.voidBean(state, now: base + 130 * minute, reason: "訊息")
        state = Machine.start(state, now: base + 140 * minute)
        state = Machine.keep(state, now: base + 165 * minute, text: "x")
        XCTAssertEqual(state.days[today]?.beans.count, 4)
        // 作廢那次沒佔名額，這顆才是第 4 顆
        XCTAssertTrue(try XCTUnwrap(state.restRun).long)
    }

    func test跨日從頭數昨天三顆今天第一顆不是長休息() throws {
        let yesterday = Machine.backFromRest(keepMany(blank(), 3).state)
        let tomorrow = base + 24 * 60 * minute
        let focusing = Machine.start(yesterday, now: tomorrow)
        let next = Machine.keep(focusing, now: tomorrow + 25 * minute, text: "x")
        XCTAssertFalse(try XCTUnwrap(next.restRun).long)
    }

    func test我自己決定的休息沒有長短() throws {
        let rest = try XCTUnwrap(keepMany(blank(restMode: .own), 4).state.restRun)
        XCTAssertFalse(rest.long)
        XCTAssertNil(rest.endAt)
    }

    func test長休息關掉第四顆照短休息() throws {
        let fourth = keepMany(blank(longEvery: 0), 4)
        let rest = try XCTUnwrap(fourth.state.restRun)
        XCTAssertFalse(rest.long)
        XCTAssertEqual(rest.endAt, fourth.lastKeep + 5 * minute)
    }

    func test響了沒理拖超過長休息的十五分才收直接待機() throws {
        let three = Machine.backFromRest(keepMany(blank(), 3).state)
        let clock = base + 120 * minute
        let focusing = Machine.start(three, now: clock)
        let late = Machine.keep(focusing, now: clock + 25 * minute + 15 * minute, text: "x")
        XCTAssertNil(late.current)
        let inTime = Machine.keep(focusing, now: clock + 25 * minute + 14 * minute, text: "x")
        XCTAssertTrue(try XCTUnwrap(inTime.restRun).long)
    }

    func test測試顆輪到長休息還是五秒但標成長休息() throws {
        let three = Machine.backFromRest(keepMany(blank(), 3).state)
        let clock = base + 120 * minute
        let focusing = Machine.start(three, now: clock, typeId: Machine.devTypeId)
        let rest = try XCTUnwrap(Machine.keep(focusing, now: clock + 5000, text: "x").restRun)
        XCTAssertTrue(rest.long)
        XCTAssertEqual(rest.endAt, clock + 5000 + 5000)
    }
}
