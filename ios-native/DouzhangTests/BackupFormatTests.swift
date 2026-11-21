@testable import Douzhang
import XCTest

/// 匯入備份、進行中那顆的轉換、存了再讀。翻自 Expo 版 store.test.js 與 machine.test.js。
final class BackupFormatTests: XCTestCase {
    private let base = Moment.local(2026, 11, 1, 9)
    private let minute = Moment.minute

    /// PWA 匯出的備份：current 換成要測的那顆。
    private func pwa(_ current: String, restMode: String = "auto") -> String {
        let types = #"[{"id":"t1","name":"一般","len":25}]"#
        let settings = #"{"types":\#(types),"typeId":"t1","restMode":"\#(restMode)"}"#
        return #"{"v":1,"settings":\#(settings),"days":{},"current":\#(current)}"#
    }

    private func reread(_ state: AppState) throws -> AppState {
        try StateDecoding.parse(StateEncoding.text(state))
    }

    // MARK: 匯入

    func test讀不懂的備份都丟例外() {
        XCTAssertThrowsError(try StateDecoding.parseBackup("{壞"))
        XCTAssertThrowsError(try StateDecoding.parseBackup("[]"))
        XCTAssertThrowsError(try StateDecoding.parseBackup(#"{"v":1,"days":{}}"#))
        XCTAssertThrowsError(try StateDecoding.parseBackup(#"{"settings":{},"days":{}}"#))
        let textVersion = #"{"v":"1","settings":{},"days":{}}"#
        XCTAssertThrowsError(try StateDecoding.parseBackup(textVersion))
    }

    func test延長中的舊寫法轉成計時中加已延長() throws {
        let current = #"{"phase":"flow","len":25,"startedAt":1,"endAt":2,"flowMin":15}"#
        let run = try XCTUnwrap(StateDecoding.parseBackup(pwa(current)).focusRun)
        XCTAssertTrue(run.flowed)
        XCTAssertEqual(run.flowMin, 15)
        XCTAssertEqual(run.notes, [])
        XCTAssertEqual(run.pings, [])
    }

    func test響了的舊寫法存成計時中由結束時刻算出鈴響() throws {
        let current = #"{"phase":"bell","len":25,"startedAt":1,"endAt":2,"notes":["x"]}"#
        let state = try StateDecoding.parseBackup(pwa(current))
        let run = try XCTUnwrap(state.focusRun)
        XCTAssertFalse(run.flowed)
        XCTAssertEqual(run.notes, ["x"])
        XCTAssertEqual(Machine.phaseOf(state, now: 3), .bell)
    }

    func test我自己決定的休息舊檔有結束時刻轉成沒有() throws {
        let current = #"{"phase":"rest","typeId":"t1","restStart":1,"endAt":2}"#
        let ownText = pwa(current, restMode: "self")
        let own = try XCTUnwrap(StateDecoding.parseBackup(ownText).restRun)
        XCTAssertNil(own.endAt)
        let auto = try XCTUnwrap(StateDecoding.parseBackup(pwa(current)).restRun)
        XCTAssertEqual(auto.endAt, 2)
    }

    func test進行中那顆的時刻不是數字或不認得就整顆不要() throws {
        let badStart = #"{"phase":"focus","len":25,"startedAt":"x","endAt":2}"#
        XCTAssertNil(try StateDecoding.parseBackup(pwa(badStart)).current)
        XCTAssertNil(try StateDecoding.parseBackup(pwa(#"{"phase":"dance"}"#)).current)
        let badRest = #"{"phase":"rest","restStart":1,"endAt":"x"}"#
        XCTAssertNil(try StateDecoding.parseBackup(pwa(badRest)).current)
    }

    func test會畫上畫面的字只留字串() throws {
        let focus = """
        {"phase":"focus","len":25,"startedAt":1,"endAt":2,
         "notes":["a",{"x":1}],"pings":[3],"draft":5}
        """
        let run = try XCTUnwrap(StateDecoding.parseBackup(pwa(focus)).focusRun)
        XCTAssertEqual(run.notes, ["a"])
        XCTAssertEqual(run.pings, [])
        XCTAssertEqual(run.draft, "")
        let rest = #"{"phase":"rest","restStart":1,"endAt":2,"msg":{"y":1}}"#
        XCTAssertEqual(try XCTUnwrap(StateDecoding.parseBackup(pwa(rest)).restRun).msg, "")
    }

    // MARK: 存了再讀

    func test計時中存了再讀停在同一態剩餘時間照時間差算() throws {
        let saved = try reread(Machine.start(Store.blank(), now: base))
        XCTAssertEqual(Machine.phaseOf(saved, now: base + 10 * minute), .focus)
        let run = try XCTUnwrap(saved.focusRun)
        XCTAssertEqual(run.endAt - (base + 10 * minute), 15 * minute)
        XCTAssertEqual(Machine.phaseOf(saved, now: base + 40 * minute), .bell)
    }

    func test草稿與記的那幾筆存了再讀還在() throws {
        var state = Machine.start(Store.blank(), now: base)
        state = Machine.jot(state, kind: .notes, text: "回信")
        state = Machine.jot(state, kind: .pings, text: "小美")
        state = Machine.setDraft(state, text: "把第三節")
        XCTAssertEqual(try reread(state), state)
    }

    func test我自己決定的休息存了再讀還是休息() throws {
        var blank = Store.blank()
        blank.settings.restMode = .own
        let focusing = Machine.start(blank, now: base)
        let resting = Machine.keep(focusing, now: base + 25 * minute, text: "x")
        let saved = try reread(resting)
        XCTAssertEqual(saved, resting)
        XCTAssertEqual(Machine.phaseOf(saved, now: base + 85 * minute), .rest)
    }

    func test收下的番茄與作廢與改過的設定存了再讀一模一樣() throws {
        var state = Store.blank()
        state.settings.restShort = .minutes(10)
        state.settings.shield = true
        state.settings.ambience = .fire
        state = SettingsLogic.addType(state, now: base)
        state = Machine.start(state, now: base)
        state = Machine.voidBean(state, now: base + 8 * minute, reason: "訊息", text: "看留言")
        state = Machine.start(state, now: base + 10 * minute)
        state = Machine.keep(state, now: base + 35 * minute, text: "寫完第二節")
        XCTAssertEqual(try reread(state), state)
    }

    func test寫出去的檔帶版本號舊版也收得下() throws {
        let text = try StateEncoding.text(Store.blank())
        XCTAssertEqual(try StateDecoding.parseBackup(text), Store.blank())
    }
}
