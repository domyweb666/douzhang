@testable import Douzhang
import XCTest

/// 狀態機：草稿、再做一下、記一筆、提早做完、作廢。翻自 Expo 版 machine.test.js。
final class MachineMidwayTests: XCTestCase {
    private let base = Moment.local(2026, 11, 1, 9)
    private let minute = Moment.minute
    private let today = "2026-11-01"

    private func started() -> AppState {
        Machine.start(Store.blank(), now: base)
    }

    private var rang: Millis {
        base + 25 * minute
    }

    // MARK: 草稿

    func test收下後草稿跟著這顆一起消失() {
        let drafted = Machine.setDraft(started(), text: "把第三節")
        XCTAssertEqual(drafted.focusRun?.draft, "把第三節")
        let state = Machine.keep(drafted, now: rang, text: "把第三節也改")
        XCTAssertNil(state.focusRun)
    }

    func test不在計時中存草稿什麼都不變() {
        let resting = Machine.keep(started(), now: rang, text: "x")
        XCTAssertEqual(Machine.setDraft(resting, text: "y"), resting)
    }

    // MARK: 再做一下

    func test鈴響後再做十五分結束時刻往後這顆標記已延長() throws {
        let state = Machine.flow(started(), now: rang + minute, minutes: 15)
        let run = try XCTUnwrap(state.focusRun)
        XCTAssertEqual(run.endAt, rang + minute + 15 * minute)
        XCTAssertTrue(run.flowed)
        XCTAssertEqual(run.flowMin, 15)
        XCTAssertEqual(Machine.phaseOf(state, now: rang + 2 * minute), .focus)
    }

    func test一顆只能再做一次() {
        let once = Machine.flow(started(), now: rang, minutes: 15)
        let again = Machine.flow(once, now: rang + 15 * minute, minutes: 30)
        XCTAssertEqual(again, once)
    }

    func test還沒響就不能再做() {
        let state = started()
        XCTAssertEqual(Machine.flow(state, now: base + 10 * minute, minutes: 15), state)
    }

    func test再做過的顆收下時記延長分鐘長度不變() throws {
        let more = Machine.flow(started(), now: rang, minutes: 30)
        let state = Machine.keep(more, now: rang + 30 * minute, text: "下一句")
        let bean = try XCTUnwrap(state.days[today]?.beans.first)
        XCTAssertEqual(bean.flow, 30)
        XCTAssertEqual(bean.len, 25)
    }

    func test沒再做過的顆收下時延長是零() throws {
        let state = Machine.keep(started(), now: rang, text: "x")
        XCTAssertEqual(try XCTUnwrap(state.days[today]?.beans.first).flow, 0)
    }

    // MARK: 記一筆

    func test計時中記一個念頭結束時刻不變() throws {
        let before = try XCTUnwrap(started().focusRun)
        let after = try XCTUnwrap(
            Machine.jot(started(), kind: .notes, text: "要回信給出版社").focusRun
        )
        XCTAssertEqual(after.notes, ["要回信給出版社"])
        XCTAssertEqual(after.endAt, before.endAt)
    }

    func test有人找記進另一欄跟念頭分開() throws {
        let pinged = Machine.jot(started(), kind: .pings, text: "小美：下午的會")
        let run = try XCTUnwrap(Machine.jot(pinged, kind: .notes, text: "x").focusRun)
        XCTAssertEqual(run.pings, ["小美：下午的會"])
        XCTAssertEqual(run.notes, ["x"])
    }

    func test點了種類沒寫字也算一筆不在計時中不記() {
        XCTAssertEqual(Machine.jot(started(), kind: .pings).focusRun?.pings, [""])
        XCTAssertEqual(Machine.jot(started(), kind: .notes, text: "   ").focusRun?.notes, [""])
        let idle = Store.blank()
        XCTAssertEqual(Machine.jot(idle, kind: .notes, text: "x"), idle)
    }

    func test改點另一種是改種類不會記成兩筆() throws {
        let picked = Machine.jot(started(), kind: .notes)
        let run = try XCTUnwrap(
            Machine.amendJot(picked, from: .notes, into: .pings, text: "").focusRun
        )
        XCTAssertEqual(run.notes, [])
        XCTAssertEqual(run.pings, [""])
    }

    func test補上那一行是改剛記的那一筆前面的不動() throws {
        let first = Machine.jot(started(), kind: .notes, text: "a")
        let picked = Machine.jot(first, kind: .notes)
        let run = try XCTUnwrap(
            Machine.amendJot(picked, from: .notes, into: .notes, text: " 回信 ").focusRun
        )
        XCTAssertEqual(run.notes, ["a", "回信"])
    }

    func test沒有剛記的那一筆可改就什麼都不變() {
        let state = started()
        XCTAssertEqual(Machine.amendJot(state, from: .pings, into: .notes, text: "x"), state)
    }

    func test記的念頭跟著番茄進帳() throws {
        let jotted = Machine.jot(started(), kind: .notes, text: "a")
        let state = Machine.keep(jotted, now: rang, text: "x")
        XCTAssertEqual(try XCTUnwrap(state.days[today]?.beans.first).notes, ["a"])
    }

    // MARK: 結束這顆

    func test提早做完了只標記倒數照常到點才響() {
        let state = Machine.markDone(started())
        XCTAssertEqual(state.focusRun?.done, true)
        XCTAssertEqual(Machine.phaseOf(state, now: base + 10 * minute), .focus)
        XCTAssertEqual(Machine.phaseOf(state, now: rang), .bell)
    }

    func test作廢記第幾分鐘原因與那一行番茄不加() throws {
        let now = base + 7 * minute + 30 * 1000
        let state = Machine.voidBean(started(), now: now, reason: "訊息", text: "去看留言")
        XCTAssertNil(state.current)
        let day = try XCTUnwrap(state.days[today])
        XCTAssertTrue(day.beans.isEmpty)
        XCTAssertEqual(day.voids.count, 1)
        XCTAssertEqual(day.voids[0].typeId, "t1")
        XCTAssertEqual(day.voids[0].minute, 7)
        XCTAssertEqual(day.voids[0].reason, "訊息")
        XCTAssertEqual(day.voids[0].text, "去看留言")
    }

    func test開始不到五分鐘就停什麼都不記() {
        let state = Machine.voidBean(started(), now: base + 4 * minute)
        XCTAssertNil(state.current)
        XCTAssertNil(state.days[today])
    }

    func test剛好五分鐘算作廢會記一筆() {
        let state = Machine.voidBean(started(), now: base + 5 * minute)
        XCTAssertEqual(state.days[today]?.voids.count, 1)
    }

    func test過了午夜才作廢記在開始那天() {
        let late = Moment.local(2026, 11, 1, 23, 55)
        let focusing = Machine.start(Store.blank(), now: late)
        let state = Machine.voidBean(focusing, now: late + 8 * minute)
        XCTAssertEqual(state.days[today]?.voids.count, 1)
        XCTAssertNil(state.days["2026-11-02"])
    }

    func test打開半頁時是停下來過了五分鐘才按也不記() {
        let now = base + 5 * minute + 2000
        let state = Machine.voidBean(started(), now: now, early: true)
        XCTAssertNil(state.current)
        XCTAssertNil(state.days[today])
    }
}
