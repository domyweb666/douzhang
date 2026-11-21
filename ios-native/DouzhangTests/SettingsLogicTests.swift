@testable import Douzhang
import XCTest

/// 標籤與休息刻度的改動。翻自 Expo 版 settings.test.js 還在用的條目。
final class SettingsLogicTests: XCTestCase {
    private let base = Moment.local(2026, 11, 1, 9)

    /// 只有一個標籤（紅色、25 分）的狀態。
    private func single() -> AppState {
        var state = Store.blank()
        state.settings.types = [Store.defaultType]
        return state
    }

    func test加一個標籤排在最後叫新標籤長度十五分選中的不變() throws {
        let state = SettingsLogic.addType(Store.blank(), now: base)
        XCTAssertEqual(state.settings.types.count, 6)
        let added = try XCTUnwrap(state.settings.types.last)
        XCTAssertEqual(added.name, "新標籤")
        XCTAssertEqual(added.len, 15)
        XCTAssertEqual(state.settings.typeId, "t1")
        XCTAssertFalse(Store.presetTypes.map(\.id).contains(added.id))
    }

    func test只有一個標籤時新加的拿第一個還沒人用的番茄色() {
        let state = SettingsLogic.addType(single(), now: base)
        XCTAssertEqual(state.settings.types.last?.color, .orange)
    }

    func test五色都用過新加的從頭輪() {
        let state = SettingsLogic.addType(Store.blank(), now: base)
        XCTAssertEqual(state.settings.types.last?.color, .red)
    }

    func test改名最多二十字空白變未命名() {
        let long = String(repeating: "字", count: 30)
        let renamed = SettingsLogic.renameType(Store.blank(), id: "t1", name: "  \(long)  ")
        XCTAssertEqual(renamed.settings.types[0].name.count, 20)
        let empty = SettingsLogic.renameType(Store.blank(), id: "t1", name: "   ")
        XCTAssertEqual(empty.settings.types[0].name, "未命名")
        XCTAssertEqual(empty.settings.types[1].name, "工作")
    }

    func test長度選刻度上的值會改刻度外的值不改() {
        let changed = SettingsLogic.setTypeLen(Store.blank(), id: "t1", len: 40)
        XCTAssertEqual(changed.settings.types[0].len, 40)
        let blank = Store.blank()
        XCTAssertEqual(SettingsLogic.setTypeLen(blank, id: "t1", len: 42), blank)
        XCTAssertEqual(SettingsLogic.setTypeLen(blank, id: "t1", len: 95), blank)
    }

    func test選標籤後下一顆的長度跟著變() {
        let picked = SettingsLogic.pickType(Store.blank(), typeId: "t2")
        let run = Machine.start(picked, now: base).focusRun
        XCTAssertEqual(run?.typeId, "t2")
        XCTAssertEqual(run?.len, 50)
    }

    func test選不存在的標籤什麼都不變() {
        let blank = Store.blank()
        XCTAssertEqual(SettingsLogic.pickType(blank, typeId: "gone"), blank)
    }

    func test只剩一個時不能刪刪掉選中的就退回第一個() {
        let one = single()
        XCTAssertEqual(SettingsLogic.removeType(one, id: "t1"), one)
        let picked = SettingsLogic.pickType(Store.blank(), typeId: "t2")
        let removed = SettingsLogic.removeType(picked, id: "t2")
        XCTAssertEqual(removed.settings.types.count, 4)
        XCTAssertEqual(removed.settings.typeId, "t1")
        let other = SettingsLogic.removeType(picked, id: "t3")
        XCTAssertEqual(other.settings.typeId, "t2")
        XCTAssertEqual(SettingsLogic.removeType(picked, id: "gone"), picked)
    }

    func test換番茄色只換那一個標籤() {
        let state = SettingsLogic.setTypeColor(Store.blank(), id: "t1", color: .pink)
        XCTAssertEqual(state.settings.types[0].color, .pink)
        XCTAssertEqual(state.settings.types[1].color, .purple)
    }

    func test短休息與長休息只收刻度上的值() {
        let blank = Store.blank()
        let short = SettingsLogic.setRestShort(blank, value: .minutes(10))
        XCTAssertEqual(short.settings.restShort, .minutes(10))
        XCTAssertEqual(SettingsLogic.setRestShort(blank, value: .minutes(7)), blank)
        XCTAssertEqual(SettingsLogic.setRestLongEvery(blank, every: 0).settings.restLongEvery, 0)
        XCTAssertEqual(SettingsLogic.setRestLongEvery(blank, every: 6), blank)
        let long = SettingsLogic.setRestLongMinutes(blank, minutes: 30)
        XCTAssertEqual(long.settings.restLongMinutes, 30)
        XCTAssertEqual(SettingsLogic.setRestLongMinutes(blank, minutes: 25), blank)
    }
}
