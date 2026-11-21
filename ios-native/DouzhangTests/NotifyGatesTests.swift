@testable import Douzhang
import XCTest

/// 該排哪些通知、白噪音該不該播、其他 app 該不該擋。
/// 翻自 Expo 版 notify／ambience／shield 三份測試裡「什麼時候該」的條目；叫系統的部分等殼那一片。
final class NotifyGatesTests: XCTestCase {
    private let base = Moment.local(2026, 11, 1, 9)
    private let minute = Moment.minute

    private func blank(_ change: (inout AppSettings) -> Void = { _ in }) -> AppState {
        var state = Store.blank()
        change(&state.settings)
        return state
    }

    private func focusing(_ from: AppState) -> AppState {
        Machine.start(from, now: base)
    }

    private func resting(_ from: AppState) -> AppState {
        Machine.keep(focusing(from), now: base + 25 * minute, text: "x")
    }

    private var rang: Millis {
        base + 25 * minute
    }

    // MARK: 通知

    func test計時中排一則到點通知文案固定() {
        let plan = Notify.planned(focusing(blank()), now: base + minute)
        let expected = PlannedNotice(title: "響了。", body: "這顆熟了，回來收下。", fireAt: rang)
        XCTAssertEqual(plan, [expected])
    }

    func test休息中排一則休息完了時刻是休息結束() {
        let plan = Notify.planned(resting(blank()), now: rang + minute)
        let expected = PlannedNotice(
            title: "休息完了",
            body: "回來了，開始下一顆",
            fireAt: rang + 5 * minute
        )
        XCTAssertEqual(plan, [expected])
    }

    func test開了自動開始連下一顆的到點一起排() {
        let state = resting(blank { $0.autoNext = true })
        let plan = Notify.planned(state, now: rang + minute)
        let restEnd = rang + 5 * minute
        let nextEnd = restEnd + Params.autoNextDelayMs + 25 * minute
        XCTAssertEqual(plan.count, 2)
        XCTAssertEqual(plan.first?.body, "下一顆自己開始了。")
        XCTAssertEqual(plan.first?.fireAt, restEnd)
        XCTAssertEqual(plan.last?.title, "響了。")
        XCTAssertEqual(plan.last?.fireAt, nextEnd)
    }

    func test待機與到點已過什麼都不排() {
        XCTAssertEqual(Notify.planned(blank(), now: base), [])
        XCTAssertEqual(Notify.planned(focusing(blank()), now: rang), [])
        XCTAssertEqual(Notify.planned(resting(blank()), now: rang + 5 * minute), [])
    }

    func test我自己決定的休息不排通知() {
        let state = resting(blank { $0.restMode = .own })
        XCTAssertEqual(Notify.planned(state, now: rang + minute), [])
    }

    // MARK: 白噪音

    func test白噪音待機不播計時中播選的那種響了就停() {
        let state = blank { $0.ambience = .rain }
        XCTAssertEqual(Gates.ambience(state, now: base), .off)
        let running = focusing(state)
        XCTAssertEqual(Gates.ambience(running, now: base + minute), .rain)
        XCTAssertEqual(Gates.ambience(running, now: rang - 1), .rain)
        XCTAssertEqual(Gates.ambience(running, now: rang), .off)
    }

    func test白噪音再做一下又播休息與作廢都不播選關也不播() {
        let running = focusing(blank { $0.ambience = .fire })
        let more = Machine.flow(running, now: rang, minutes: 15)
        XCTAssertEqual(Gates.ambience(more, now: rang + minute), .fire)
        let rest = Machine.keep(running, now: rang, text: "x")
        XCTAssertEqual(Gates.ambience(rest, now: rang + minute), .off)
        let voided = Machine.voidBean(running, now: base + 10 * minute)
        XCTAssertEqual(Gates.ambience(voided, now: base + 11 * minute), .off)
        XCTAssertEqual(Gates.ambience(focusing(blank()), now: base + minute), .off)
    }

    func test音量三段由小到大() {
        XCTAssertLessThan(Params.ambienceVolume(.low), Params.ambienceVolume(.mid))
        XCTAssertLessThan(Params.ambienceVolume(.mid), Params.ambienceVolume(.high))
        XCTAssertLessThanOrEqual(Params.ambienceVolume(.high), 1)
    }

    // MARK: 擋其他 app

    func test開關關著的時候計時中也不擋() {
        XCTAssertFalse(Gates.shouldShield(focusing(blank()), now: base + minute))
    }

    func test開著待機不擋按開始就擋一路擋到響之前() {
        let state = blank { $0.shield = true }
        XCTAssertFalse(Gates.shouldShield(state, now: base))
        let running = focusing(state)
        XCTAssertTrue(Gates.shouldShield(running, now: base))
        XCTAssertTrue(Gates.shouldShield(running, now: rang - 1))
        XCTAssertFalse(Gates.shouldShield(running, now: rang))
    }

    func test再做一下又擋休息與作廢都不擋() {
        let running = focusing(blank { $0.shield = true })
        let more = Machine.flow(running, now: rang, minutes: 15)
        XCTAssertTrue(Gates.shouldShield(more, now: rang + minute))
        XCTAssertFalse(Gates.shouldShield(more, now: rang + 15 * minute))
        let rest = Machine.keep(running, now: rang, text: "x")
        XCTAssertFalse(Gates.shouldShield(rest, now: rang + minute))
        let voided = Machine.voidBean(running, now: base + 10 * minute)
        XCTAssertFalse(Gates.shouldShield(voided, now: base + 11 * minute))
    }

    func test計時中把開關關掉當下就不擋() {
        var running = focusing(blank { $0.shield = true })
        running.settings.shield = false
        XCTAssertFalse(Gates.shouldShield(running, now: base + minute))
    }
}
