@testable import Douzhang
import XCTest

/// 格式 v3（規格在 .analytics/04-資料結構.md）：標籤帶「幾時改過」。舊檔怎麼補、哪些動作會寫、讀寫來回。
final class FormatV3Tests: XCTestCase {
    private let base = Moment.local(2026, 11, 24, 9)
    private let minute = Moment.minute

    /// 一份 v2 的檔，標籤換成要測的那幾個。
    private func types(_ inner: String) throws -> [TagType] {
        let text = #"{"v":2,"settings":{"types":[\#(inner)]},"days":{}}"#
        return try StateDecoding.parse(text).settings.types
    }

    /// 一個標籤：欄位後面要接的（例如 mod）放 more，開頭帶逗號。
    private func tag(_ id: String, _ name: String = "剪片", more: String = "") -> String {
        #"{"id":"\#(id)","name":"\#(name)","len":25,"color":"red"\#(more)}"#
    }

    private func reread(_ state: AppState) throws -> AppState {
        try StateDecoding.parse(StateEncoding.text(state))
    }

    private func mods(_ state: AppState) -> [Millis] {
        state.settings.types.map(\.mod)
    }

    // MARK: 寫出去

    func test寫出去的版本號是三標籤帶幾時改過() throws {
        let object = StateEncoding.object(Store.blank())
        XCTAssertEqual(object["v"] as? Int, 3)
        var type = Store.defaultType
        type.mod = base
        XCTAssertEqual(StateEncoding.writeTagType(type)["mod"] as? Double, base)
        let removed = StateEncoding.writeRemoved(RemovedTag(type: type, removedAt: base + minute))
        XCTAssertEqual(removed["mod"] as? Double, base)
        XCTAssertEqual(removed["removedAt"] as? Double, base + minute)
    }

    func test全新安裝的預設標籤都是沒動過() {
        XCTAssertEqual(mods(Store.blank()), [0, 0, 0, 0, 0])
    }

    // MARK: 舊檔沒有幾時改過

    func test跟預設一模一樣的補零() throws {
        XCTAssertEqual(try types(tag("t1", "專注")), [Store.defaultType])
    }

    func test改過的預設補一不會把編號當成時刻() throws {
        let purple = #"{"id":"t2","name":"工作","len":40,"color":"purple"}"#
        let read = try types([tag("t1", "寫稿"), purple].joined(separator: ","))
        XCTAssertEqual(read.map(\.mod), [1, 1])
    }

    func test自己加的照編號裡的毫秒() throws {
        XCTAssertEqual(try types(tag("t1795262400000")).map(\.mod), [1_795_262_400_000])
    }

    func test其他寫法的編號補一() throws {
        let odd = [
            "t", "t9", "x1795262400000", "t179526240000", "t17952624000000", "t-795262400000",
        ]
        let read = try types(odd.map { tag($0) }.joined(separator: ","))
        XCTAssertEqual(read.map(\.mod), [1, 1, 1, 1, 1, 1])
    }

    func test刪掉的標籤照同一套補() throws {
        let removed = [tag("t1", "專注"), tag("t3"), tag("t1795262400000")].joined(separator: ",")
        let settings = #"{"types":[\#(tag("t8"))],"removedTypes":[\#(removed)]}"#
        let text = #"{"v":2,"settings":\#(settings),"days":{}}"#
        let read = try StateDecoding.parse(text).settings.removedTypes
        XCTAssertEqual(read.map(\.type.mod), [0, 1, 1_795_262_400_000])
    }

    func test補出來的讀幾次都一樣寫出去再讀回來也一樣() throws {
        let inner = [tag("t1", "專注"), tag("t2", "改過"), tag("t1795262400000")]
            .joined(separator: ",")
        let text = #"{"v":1,"settings":{"types":[\#(inner)]},"days":{}}"#
        let state = try StateDecoding.parse(text)
        XCTAssertEqual(try StateDecoding.parse(text), state)
        XCTAssertEqual(try reread(state), state)
    }

    // MARK: 檔裡有幾時改過

    func test檔裡有就照檔裡的跟預設一樣也不歸零() throws {
        XCTAssertEqual(try types(tag("t1", "專注", more: #","mod":5000"#)).map(\.mod), [5000])
        let own = tag("t1795262400000", more: #","mod":1795262460000"#)
        XCTAssertEqual(try types(own).map(\.mod), [1_795_262_460_000])
    }

    func test幾時改過不是零以上的數字就當沒有() throws {
        for bad in [#""5000""#, "true", "null", "[]", "-1"] {
            let read = try types(tag("t1", "寫稿", more: #","mod":\#(bad)"#))
            XCTAssertEqual(read.map(\.mod), [1], bad)
        }
    }

    func test改過與刪掉的標籤寫出去再讀回來一模一樣() throws {
        var state = SettingsLogic.addType(Store.blank(), now: base)
        state = SettingsLogic.renameType(state, id: "t2", name: "寫書", now: base + minute)
        state = SettingsLogic.removeType(state, id: "t2", now: base + 2 * minute)
        XCTAssertEqual(state.settings.removedTypes.first?.type.mod, base + minute)
        XCTAssertEqual(try reread(state), state)
    }

    // MARK: 哪些動作會寫

    func test新增的標籤記下加的時刻() {
        XCTAssertEqual(mods(SettingsLogic.addType(Store.blank(), now: base)), [0, 0, 0, 0, 0, base])
    }

    func test改名改長度改顏色都記下時刻別的標籤不動() {
        let blank = Store.blank()
        let expected: [Millis] = [0, base, 0, 0, 0]
        let renamed = SettingsLogic.renameType(blank, id: "t2", name: "寫書", now: base)
        XCTAssertEqual(mods(renamed), expected)
        let longer = SettingsLogic.setTypeLen(blank, id: "t2", len: 40, now: base)
        XCTAssertEqual(mods(longer), expected)
        let pink = SettingsLogic.setTypeColor(blank, id: "t2", color: .pink, now: base)
        XCTAssertEqual(mods(pink), expected)
    }

    func test再改一次換成後來的時刻() {
        var state = SettingsLogic.setTypeLen(Store.blank(), id: "t1", len: 30, now: base)
        state = SettingsLogic.setTypeLen(state, id: "t1", len: 25, now: base + minute)
        // 改回跟預設一樣也是動過
        XCTAssertEqual(state.settings.types[0].mod, base + minute)
    }

    func test這台時鐘比較慢時改的還是比上一次晚() {
        let ahead = base + 5 * minute
        var state = SettingsLogic.setTypeLen(Store.blank(), id: "t1", len: 30, now: ahead)
        state = SettingsLogic.renameType(state, id: "t1", name: "寫書", now: base)
        XCTAssertEqual(state.settings.types[0].mod, ahead + 1)
        state = SettingsLogic.setTypeColor(state, id: "t1", color: .pink, now: base)
        XCTAssertEqual(state.settings.types[0].mod, ahead + 2)
    }

    func test這台時鐘比較慢時刪的還是比上一次改晚() {
        let ahead = base + 5 * minute
        var state = SettingsLogic.setTypeLen(Store.blank(), id: "t2", len: 40, now: ahead)
        state = SettingsLogic.removeType(state, id: "t2", now: base)
        XCTAssertEqual(state.settings.removedTypes.map(\.removedAt), [ahead + 1])
        XCTAssertEqual(state.settings.removedTypes.map(\.type.mod), [ahead])
    }

    func test沒動過的預設標籤時刻是零也刪得掉() {
        let state = SettingsLogic.removeType(Store.blank(), id: "t2", now: 0)
        XCTAssertEqual(state.settings.removedTypes.map(\.removedAt), [1])
    }

    func test值沒變不算改過() {
        let blank = Store.blank()
        let same = SettingsLogic.renameType(blank, id: "t1", name: "  專注 ", now: base)
        XCTAssertEqual(same, blank)
        XCTAssertEqual(SettingsLogic.setTypeLen(blank, id: "t1", len: 25, now: base), blank)
        XCTAssertEqual(SettingsLogic.setTypeColor(blank, id: "t1", color: .red, now: base), blank)
        let gone = SettingsLogic.renameType(blank, id: "gone", name: "寫書", now: base)
        XCTAssertEqual(gone, blank)
    }
}
