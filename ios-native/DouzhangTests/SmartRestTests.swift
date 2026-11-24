@testable import Douzhang
import XCTest

/// 智能調節的休息：專注 ÷ 5，今天每跨過 100 分再加 10，最少 3、最多 30（QC-0003 第 15 筆）。
final class SmartRestTests: XCTestCase {
    private let base = Moment.local(2026, 11, 24, 9)
    private let minute = Moment.minute

    private func smart(len: Double = 25) -> AppState {
        var state = Store.blank()
        state.settings.restMode = .smart
        // 智能調節不看這三個：故意設成別的值
        state.settings.restShort = .minutes(15)
        state.settings.restLongEvery = 3
        state.settings.restLongMinutes = 20
        return SettingsLogic.setTypeLen(state, id: "t1", len: len)
    }

    /// 連續收 count 顆，響了就收、隔 40 分再開始；回最後一次收下後的休息與收下那一刻。
    private func restAfter(
        _ from: AppState,
        _ count: Int
    ) throws -> (rest: RestRun, keptAt: Millis) {
        var state = from
        var clock = base
        var keptAt = base
        for _ in 0 ..< count {
            state = Machine.start(Machine.backFromRest(state), now: clock)
            keptAt = try XCTUnwrap(state.focusRun).endAt
            state = Machine.keep(state, now: keptAt, text: "")
            clock = keptAt + 40 * minute
        }
        return try (XCTUnwrap(state.restRun), keptAt)
    }

    // MARK: 公式

    func test二十五分休五分五十分休十分() {
        XCTAssertEqual(Store.smartRest(focused: 25, before: 0).minutes, 5)
        XCTAssertEqual(Store.smartRest(focused: 50, before: 0).minutes, 10)
        XCTAssertEqual(Store.smartRest(focused: 37, before: 0).minutes, 7)
        XCTAssertFalse(Store.smartRest(focused: 50, before: 0).long)
    }

    func test剛好滿一百就算跨過跨過的那次是長休息() {
        let crossed = RestPlan(minutes: 15, long: true)
        XCTAssertEqual(Store.smartRest(focused: 25, before: 75), crossed)
        XCTAssertFalse(Store.smartRest(focused: 24, before: 75).long)
        // 停在 100 上再做一顆：還沒到下一個 100
        XCTAssertFalse(Store.smartRest(focused: 25, before: 100).long)
        XCTAssertTrue(Store.smartRest(focused: 25, before: 175).long)
    }

    func test最少三分最多三十分() {
        XCTAssertEqual(Store.smartRest(focused: 1, before: 0).minutes, 3)
        // 90 分延長 30：24 分，跨過兩個 100 再加 20，夾在 30
        let capped = RestPlan(minutes: 30, long: true)
        XCTAssertEqual(Store.smartRest(focused: 120, before: 90), capped)
    }

    // MARK: 收下

    func test二十五分的第三顆休五分第四顆休十五分() throws {
        let third = try restAfter(smart(), 3)
        XCTAssertFalse(third.rest.long)
        XCTAssertEqual(third.rest.endAt, third.keptAt + 5 * minute)
        let fourth = try restAfter(smart(), 4)
        XCTAssertTrue(fourth.rest.long)
        XCTAssertEqual(fourth.rest.endAt, fourth.keptAt + 15 * minute)
    }

    func test五十分的第二顆就跨過一百() throws {
        let second = try restAfter(smart(len: 50), 2)
        XCTAssertTrue(second.rest.long)
        XCTAssertEqual(second.rest.endAt, second.keptAt + 20 * minute)
    }

    func test延長的分鐘算專注() throws {
        let rang = base + 25 * minute
        let more = Machine.flow(Machine.start(smart(), now: base), now: rang, minutes: 30)
        let keptAt = rang + 30 * minute
        let rest = try XCTUnwrap(Machine.keep(more, now: keptAt, text: "").restRun)
        XCTAssertEqual(rest.endAt, keptAt + 11 * minute)
    }

    func test跨日從頭數() throws {
        let today = Machine.backFromRest(Machine.keep(
            Machine.start(smart(len: 90), now: base),
            now: base + 90 * minute,
            text: ""
        ))
        let tomorrow = base + 24 * 60 * minute
        let next = Machine.start(today, now: tomorrow)
        let kept = Machine.keep(next, now: tomorrow + 90 * minute, text: "")
        XCTAssertFalse(try XCTUnwrap(kept.restRun).long)
    }

    // MARK: 通知、自動開始、存檔

    func test休息到點照排通知開了自動開始就接下一顆() throws {
        var state = smart()
        state.settings.autoNext = true
        let rang = base + 25 * minute
        let resting = Machine.keep(Machine.start(state, now: base), now: rang, text: "")
        let plan = Notify.planned(resting, now: rang + minute)
        XCTAssertEqual(plan.count, 2)
        XCTAssertEqual(plan.first?.fireAt, rang + 5 * minute)
        let startAt = rang + 5 * minute + Params.autoNextDelayMs
        let next = Machine.settle(resting, now: startAt + minute)
        XCTAssertEqual(try XCTUnwrap(next.focusRun).startedAt, startAt)
    }

    func test休息的模式存了再讀一樣不認得的退回到點提醒() throws {
        let saved = try StateDecoding.parse(restStateText())
        XCTAssertEqual(saved.settings.restMode, .smart)
        XCTAssertNotNil(saved.restRun?.endAt)
        let cases: [(String, RestMode)] = [("self", .own), ("auto", .auto), ("zen", .auto)]
        for (raw, mode) in cases {
            let text = #"{"settings":{"restMode":"\#(raw)"},"days":{}}"#
            XCTAssertEqual(try StateDecoding.parse(text).settings.restMode, mode)
        }
    }

    private func restStateText() throws -> String {
        let focusing = Machine.start(smart(), now: base)
        return try StateEncoding.text(Machine.keep(focusing, now: base + 25 * minute, text: ""))
    }
}
