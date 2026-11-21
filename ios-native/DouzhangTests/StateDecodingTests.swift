@testable import Douzhang
import XCTest

/// 讀外部來的狀態：壞檔、PWA 舊檔、型別不對的欄位。翻自 Expo 版 store.test.js。
final class StateDecodingTests: XCTestCase {
    private func settings(_ inner: String) throws -> AppSettings {
        try StateDecoding.parse(#"{"settings":{\#(inner)},"days":{}}"#).settings
    }

    func test壞掉的字與不是番茄帳的檔都讀不懂() {
        XCTAssertThrowsError(try StateDecoding.parse("{這不是 JSON"))
        XCTAssertThrowsError(try StateDecoding.parse(#"{"hello":"world"}"#))
        XCTAssertThrowsError(try StateDecoding.parse("[]"))
    }

    func test舊檔缺的設定欄位補成預設() throws {
        let text = """
        {"v":1,"settings":{"types":[{"id":"t1","name":"一般","len":25}],"typeId":"t1"},
         "days":{"2026-10-30":{"beans":[{"t":1,"len":25}],"voids":[]}}}
        """
        let state = try StateDecoding.parse(text)
        XCTAssertTrue(state.settings.sound)
        XCTAssertTrue(state.settings.tilt)
        XCTAssertFalse(state.settings.shield)
        XCTAssertFalse(state.settings.autoNext)
        XCTAssertEqual(state.settings.restMode, .auto)
        XCTAssertEqual(state.settings.ambience, .off)
        XCTAssertEqual(state.settings.ambienceVolume, .mid)
        XCTAssertEqual(state.days["2026-10-30"]?.beans.count, 1)
        XCTAssertEqual(state.lastLine, -1)
        XCTAssertNil(state.current)
    }

    func test測試模式開發版照存檔讀不是布林就關() throws {
        // 測試跑的是開發版（DEBUG）；正式 build 這一欄一律關
        XCTAssertTrue(try settings(#""demo":true"#).demo)
        XCTAssertFalse(try settings(#""demo":"yes""#).demo)
        XCTAssertFalse(try settings(#""demo":1"#).demo)
    }

    func test舊檔選的標籤已經不存在時退回第一個() throws {
        let inner = #""types":[{"id":"tX","name":"寫作","len":50}],"typeId":"gone""#
        XCTAssertEqual(try settings(inner).typeId, "tX")
    }

    func test沒有標籤或標籤缺名字時補回預設的五個() throws {
        XCTAssertEqual(try settings(#""types":[]"#).types, Store.presetTypes)
        XCTAssertEqual(try settings(#""types":[{"id":"t9"}]"#).types, Store.presetTypes)
    }

    func test顆的長度不是數字時補成二十五() throws {
        let text = """
        {"settings":{},"days":{"2026-10-30":{"beans":
         [{"t":1,"len":"abc"},{"t":2},{"t":3,"len":50}]}}}
        """
        let beans = try XCTUnwrap(StateDecoding.parse(text).days["2026-10-30"]).beans
        XCTAssertEqual(beans.map { Store.units($0.len) }, [1, 1, 2])
    }

    func test欄位型別不對時用預設不信任外部型別() throws {
        let text = """
        {"settings":{"types":[{"id":"t1","name":"一般","len":"25"}],"sound":"on"},
         "days":{"2026-10-30":{"beans":"not an array"},"2026-10-31":"oops"}}
        """
        let state = try StateDecoding.parse(text)
        XCTAssertEqual(state.settings.types[0].len, 25)
        XCTAssertTrue(state.settings.sound)
        XCTAssertEqual(state.days["2026-10-30"], DayRecord())
        XCTAssertNil(state.days["2026-10-31"])
    }

    func test舊檔沒有顏色依序分配() throws {
        let inner = #""types":[{"id":"a","name":"甲"},{"id":"b","name":"乙","color":"pink"},"#
            + #"{"id":"c","name":"丙","color":"teal"}]"#
        let colors = try settings(inner).types.map(\.color)
        XCTAssertEqual(colors, [.red, .pink, .yellow])
    }

    func test休息的三欄沒有就補預設() throws {
        let read = try settings(#""types":[]"#)
        XCTAssertEqual(read.restShort, .auto)
        XCTAssertEqual(read.restLongEvery, 4)
        XCTAssertEqual(read.restLongMinutes, 15)
    }

    func test休息的三欄塞了刻度以外的值一律退回預設() throws {
        let inner = #""restShort":"7","restLongEvery":-1,"restLongMinutes":999"#
        let read = try settings(inner)
        XCTAssertEqual(read.restShort, .auto)
        XCTAssertEqual(read.restLongEvery, 4)
        XCTAssertEqual(read.restLongMinutes, 15)
        XCTAssertEqual(try settings(#""restShort":7"#).restShort, .auto)
    }

    func test休息的三欄刻度上的值讀得進來() throws {
        let inner = #""restShort":10,"restLongEvery":0,"restLongMinutes":30"#
        let read = try settings(inner)
        XCTAssertEqual(read.restShort, .minutes(10))
        XCTAssertEqual(read.restLongEvery, 0)
        XCTAssertEqual(read.restLongMinutes, 30)
    }

    func test白噪音兩欄值亂掉時補成不播與音量中() throws {
        let read = try settings(#""ambience":"storm","ambienceVolume":3"#)
        XCTAssertEqual(read.ambience, .off)
        XCTAssertEqual(read.ambienceVolume, .mid)
        let good = try settings(#""ambience":"rain","ambienceVolume":"high""#)
        XCTAssertEqual(good.ambience, .rain)
        XCTAssertEqual(good.ambienceVolume, .high)
    }

    func test擋其他軟體的開關不是布林的值當關() throws {
        XCTAssertTrue(try settings(#""shield":true"#).shield)
        XCTAssertFalse(try settings(#""shield":"yes""#).shield)
        XCTAssertFalse(try settings(#""shield":1"#).shield)
    }
}
