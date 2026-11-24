@testable import Douzhang
import XCTest

/// 合併標籤（.vibe/QC-0003/J-規格.md 包 A）。
final class SyncTagsTests: XCTestCase {
    private let base = Moment.local(2026, 11, 24, 9)

    private func merged(_ one: AppState, _ two: AppState) -> AppState {
        SyncMerge.merged(one, SyncSample.remote(two))
    }

    private func name(_ state: AppState, _ id: String) -> String? {
        state.settings.types.first { $0.id == id }?.name
    }

    private func renamed(_ name: String, at now: Millis) -> AppState {
        SettingsLogic.renameType(Store.blank(), id: "t2", name: name, now: now)
    }

    func test改得晚的贏兩個方向一樣() {
        let early = renamed("早", at: base)
        let late = renamed("晚", at: base + 1)
        XCTAssertEqual(name(merged(early, late), "t2"), "晚")
        XCTAssertEqual(name(merged(late, early), "t2"), "晚")
    }

    func test同一刻改的內容不同兩台挑到同一個() {
        let one = renamed("甲", at: base)
        let two = renamed("乙", at: base)
        XCTAssertEqual(name(merged(one, two), "t2"), name(merged(two, one), "t2"))
    }

    func test全新安裝帶來的預設標籤蓋不掉改過的() {
        let local = renamed("讀書", at: base)
        XCTAssertEqual(merged(local, Store.blank()), local)
        XCTAssertEqual(name(merged(Store.blank(), local), "t2"), "讀書")
    }

    func test本機刪掉的預設標籤全新安裝帶不回來() {
        let local = SettingsLogic.removeType(Store.blank(), id: "t2", now: base)
        XCTAssertEqual(merged(local, Store.blank()), local)
        let fresh = merged(Store.blank(), local)
        XCTAssertNil(name(fresh, "t2"))
        XCTAssertEqual(fresh.settings.removedTypes.map(\.type.id), ["t2"])
    }

    func test沒記到刪除時刻的舊資料也維持刪本機記的零不動() {
        var local = Store.blank()
        local.settings.types.removeAll { $0.id == "t2" }
        let gone = RemovedTag(type: Store.presetTypes[1], removedAt: 0)
        local.settings.removedTypes = [gone]
        XCTAssertEqual(merged(local, Store.blank()), local)
        XCTAssertEqual(merged(local, local), local)
        let fresh = merged(Store.blank(), local)
        XCTAssertNil(name(fresh, "t2"))
        XCTAssertEqual(fresh.settings.removedTypes.map(\.type.id), ["t2"])
    }

    /// v1 刪標籤沒有留紀錄：還在、刪掉兩邊都沒有 t3。
    private func withoutThird() -> AppState {
        var state = Store.blank()
        state.settings.types.removeAll { $0.id == "t3" }
        return state
    }

    func test全新安裝帶來的預設標籤這台沒有又沒人用就不收() {
        XCTAssertEqual(merged(withoutThird(), Store.blank()), withoutThird())
    }

    func test這台沒有的預設標籤有紀錄掛在上面或動過就收() {
        var bean = SyncSample.bean("r1", at: base)
        bean.typeId = "t3"
        let used = merged(withoutThird(), SyncSample.state("2026-11-24", bean))
        XCTAssertNotNil(name(used, "t3"))
        let edited = SettingsLogic.renameType(Store.blank(), id: "t3", name: "讀書", now: base)
        XCTAssertEqual(name(merged(withoutThird(), edited), "t3"), "讀書")
    }

    func test刪掉後又改過的復活() {
        let gone = SettingsLogic.removeType(Store.blank(), id: "t2", now: base)
        let edited = renamed("讀書", at: base + 1)
        for result in [merged(gone, edited), merged(edited, gone)] {
            XCTAssertEqual(name(result, "t2"), "讀書")
            XCTAssertTrue(result.settings.removedTypes.isEmpty)
        }
    }

    func test改了之後才刪的算刪名字留改過的() {
        let edited = renamed("讀書", at: base)
        let gone = SettingsLogic.removeType(Store.blank(), id: "t2", now: base + 1)
        for result in [merged(gone, edited), merged(edited, gone)] {
            XCTAssertNil(name(result, "t2"))
            XCTAssertEqual(result.settings.removedTypes.map(\.type.name), ["讀書"])
        }
    }

    func test選中的標籤被別台刪掉就退回第一個() {
        let local = SettingsLogic.pickType(Store.blank(), typeId: "t3")
        let away = SettingsLogic.removeType(Store.blank(), id: "t3", now: base)
        XCTAssertEqual(merged(local, away).settings.typeId, "t1")
    }

    func test順序照本機新來的接在後面照編號排顏色不變() {
        var away = SettingsLogic.addType(Store.blank(), now: base + 2)
        away = SettingsLogic.addType(away, now: base + 1)
        let result = merged(Store.blank(), away).settings.types
        let added = away.settings.types.suffix(2)
        XCTAssertEqual(Array(result.prefix(5)), Store.presetTypes)
        XCTAssertEqual(result.suffix(2).map(\.id), added.map(\.id).sorted())
        XCTAssertEqual(Set(result.suffix(2).map(\.color)), Set(added.map(\.color)))
    }

    func test同名不同編號的兩個都留() {
        let one = SettingsLogic.addType(Store.blank(), now: base)
        let two = SettingsLogic.addType(Store.blank(), now: base + 1)
        let names = merged(one, two).settings.types.map(\.name)
        XCTAssertEqual(names.filter { $0 == Words.newTypeName }.count, 2)
    }

    func test合起來全被刪就救回本機選中的那個別台也跟著回來() {
        var one = Store.blank()
        one.settings.types = Array(Store.presetTypes.prefix(2))
        var two = one
        one = SettingsLogic.removeType(one, id: "t1", now: base)
        two = SettingsLogic.removeType(two, id: "t2", now: base)
        let result = merged(one, two)
        XCTAssertEqual(result.settings.types.map(\.id), ["t2"])
        XCTAssertEqual(result.settings.typeId, "t2")
        XCTAssertEqual(result.settings.removedTypes.map(\.type.id), ["t1"])
        XCTAssertEqual(merged(result, two), result)
        XCTAssertNotNil(name(merged(two, result), "t2"))
        // 救回來之後加新標籤，再合也不會不見
        let added = SettingsLogic.addType(result, now: base + 5)
        XCTAssertNotNil(name(merged(added, two), "t2"))
    }

    func test沒有標籤檔的那台不影響本機標籤() {
        let local = renamed("讀書", at: base)
        let away = SyncFiles.Remote(device: SyncSample.other)
        XCTAssertEqual(SyncMerge.merged(local, [away]), local)
    }
}
