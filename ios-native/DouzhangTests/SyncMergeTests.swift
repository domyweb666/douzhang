@testable import Douzhang
import XCTest

/// 合併番茄與作廢（.vibe/QC-0003/J-規格.md 包 A）。
final class SyncMergeTests: XCTestCase {
    private let minute = Moment.minute
    private let base = Moment.local(2026, 11, 24, 9)
    private let key = "2026-11-24"
    private let taipei = "Asia/Taipei"

    private func kept(_ state: AppState, at start: Millis, text: String = "") -> AppState {
        let running = Machine.start(state, now: start, zone: taipei)
        return Machine.backFromRest(Machine.keep(running, now: start + 25 * minute, text: text))
    }

    private func merged(_ one: AppState, _ two: AppState) -> AppState {
        SyncMerge.merged(one, SyncSample.remote(two))
    }

    /// 同編號的兩份合起來剩一份，兩個方向要一樣。
    private func single(_ one: Bean, _ two: Bean) throws -> Bean {
        let left = SyncSample.state(key, one)
        let right = SyncSample.state(key, two)
        XCTAssertEqual(merged(left, right).days, merged(right, left).days)
        let beans = SyncSample.beans(merged(left, right))
        XCTAssertEqual(beans.count, 1)
        return try XCTUnwrap(beans.first)
    }

    // MARK: 聯集與順序

    func test離線各收一顆合完兩台一樣順序跟只在一台收的一樣() {
        let one = kept(Store.blank(), at: base + 60 * minute)
        let two = kept(Store.blank(), at: base)
        let both = kept(kept(Store.blank(), at: base), at: base + 60 * minute)
        XCTAssertEqual(merged(one, two).days, both.days)
        XCTAssertEqual(merged(two, one).days, both.days)
    }

    func test沒有別台就原封不動() {
        let state = SyncSample.state([key: DayRecord(), "2026-11-23": DayRecord()])
        XCTAssertEqual(SyncMerge.merged(state, []), state)
    }

    func test合自己那份什麼都不變時刻帶小數也一樣() {
        var state = Machine.start(Store.blank(), now: base + 0.437, zone: taipei)
        state = Machine.markDone(state, now: base + 12 * minute + 0.81)
        state = Machine.keep(state, now: base + 25 * minute + 0.659, text: "寫完")
        state = SettingsLogic.renameType(state, id: "t2", name: "閱讀", now: base + 0.5)
        state = SettingsLogic.removeType(state, id: "t3", now: base + 0.7)
        XCTAssertEqual(merged(state, state), state)
    }

    func test進行中那顆與偏好不動() {
        var local = Machine.start(Store.blank(), now: base, zone: taipei)
        local.doing = "寫稿"
        local.lastLine = 2
        local.settings.sound = false
        var away = kept(Store.blank(), at: base - 60 * minute)
        away.doing = "別的"
        away.settings.ambience = .rain
        let result = merged(local, away)
        XCTAssertEqual(SyncSample.beans(result).count, 1)
        XCTAssertEqual(result.current, local.current)
        XCTAssertEqual(result.doing, "寫稿")
        XCTAssertEqual(result.lastLine, 2)
        XCTAssertEqual(result.settings, local.settings)
    }

    func test沒有編號的別台不收本機留著() {
        let local = SyncSample.state(key, SyncSample.bean("", at: base))
        let away = SyncFiles.Remote(
            device: SyncSample.other,
            days: [key: DayRecord(beans: [SyncSample.bean("", at: base + minute)])]
        )
        XCTAssertEqual(SyncMerge.merged(local, [away]).days, local.days)
    }

    // MARK: 哪一天

    func test有開始時刻與時區就照開始那天不照檔裡的鍵() {
        var bean = SyncSample.bean("r1", at: base + 25 * minute)
        bean.start = base
        bean.zone = taipei
        let away = SyncFiles.Remote(
            device: SyncSample.other,
            days: ["2026-10-01": DayRecord(beans: [bean])]
        )
        let days = SyncMerge.merged(Store.blank(), [away]).days
        XCTAssertEqual(Array(days.keys), [Store.dayKey(base, zone: taipei)])
    }

    func test算不出哪一天的照檔裡的鍵兩邊不同取較早的() {
        let bean = SyncSample.bean("r1", at: base)
        let early = SyncSample.state("2026-11-23", bean)
        let late = SyncSample.state(key, bean)
        for result in [merged(early, late), merged(late, early)] {
            XCTAssertEqual(result.days["2026-11-23"]?.beans, [bean])
            XCTAssertEqual(result.days[key]?.beans ?? [], [])
        }
    }

    // MARK: 同編號內容不同

    func test收下贏作廢念頭有人找與寫的字都併進來() throws {
        var bean = SyncSample.bean("r1", at: base)
        bean.notes = ["回信"]
        bean.clue = "寫完"
        var entry = SyncSample.voided("r1", at: base + minute)
        entry.notes = ["回信", "買牛奶"]
        entry.pings = ["快遞"]
        entry.text = "門鈴響"
        entry.doing = "寫稿"
        let left = SyncSample.state(key, bean)
        let right = SyncSample.state(key, entry)
        XCTAssertEqual(merged(left, right).days, merged(right, left).days)
        let result = merged(right, left)
        XCTAssertTrue(SyncSample.voids(result).isEmpty)
        let found = try XCTUnwrap(SyncSample.beans(result).first)
        XCTAssertEqual(found.keptAt, base)
        XCTAssertEqual(found.notes, ["回信", "買牛奶"])
        XCTAssertEqual(found.pings, ["快遞"])
        XCTAssertEqual(Set(found.clue.split(separator: "\n")), ["寫完", "門鈴響"])
        XCTAssertEqual(found.doing, "寫稿")
    }

    func test時刻取晚的其他欄位跟著晚收的那份提早做完有一邊就算() throws {
        var early = SyncSample.bean("r1", at: base)
        early.typeId = "t2"
        early.done = true
        early.doneAt = base - minute
        var late = SyncSample.bean("r1", at: base + minute)
        late.flow = 15
        late.doneAt = base - 2 * minute
        let found = try single(early, late)
        XCTAssertEqual(found.keptAt, base + minute)
        XCTAssertEqual(found.typeId, "t1")
        XCTAssertEqual(found.flow, 15)
        XCTAssertTrue(found.done)
        XCTAssertEqual(found.doneAt, base - minute)
    }

    func test兩句不同都留分兩行一邊包含另一邊就留多的() throws {
        var one = SyncSample.bean("r1", at: base)
        one.clue = "寫完"
        one.doing = "寫稿"
        var two = SyncSample.bean("r1", at: base)
        two.clue = "寫完第二章"
        two.doing = "改稿"
        let found = try single(one, two)
        XCTAssertEqual(found.clue, "寫完第二章")
        XCTAssertEqual(Set(found.doing.split(separator: "\n")), ["寫稿", "改稿"])
    }

    func test併過的兩行再遇到其中一句不會變三行() {
        let both = SyncJoin.lines("甲", "乙")
        XCTAssertEqual(SyncJoin.lines(both, "甲"), both)
        XCTAssertEqual(SyncJoin.lines("乙", both), both)
        XCTAssertEqual(SyncJoin.lines(both, ""), both)
    }

    func test念頭一邊多記的照那邊的順序空白的筆數不變少() {
        XCTAssertEqual(SyncJoin.union(["乙"], ["乙", "甲"]), ["乙", "甲"])
        XCTAssertEqual(SyncJoin.union(["", ""], [""]), ["", ""])
        XCTAssertEqual(SyncJoin.union(["b"], ["a"]), ["a", "b"])
    }

    /// 本機的字跟從檔案讀回來的字混在一起排，一句是另一句的開頭時也要同一個順序。
    func test念頭一句是另一句的開頭兩台排出來一樣() throws {
        var one = SyncSample.bean("r1", at: base)
        one.notes = ["寫完", "寫"]
        var two = SyncSample.bean("r1", at: base)
        two.notes = ["寫完第二章", "寫"]
        let expected = ["寫", "寫完", "寫完第二章"]
        let here = try single(one, two)
        let there = try single(two, one)
        XCTAssertEqual(here.notes, expected)
        XCTAssertEqual(there.notes, expected)
    }

    func test作廢兩份不同原因跟著晚的那行字都留() throws {
        var early = SyncSample.voided("r1", at: base)
        early.text = "門鈴"
        var late = SyncSample.voided("r1", at: base + minute)
        late.reason = "卡住"
        late.text = "電話"
        let result = merged(SyncSample.state(key, early), SyncSample.state(key, late))
        let found = try XCTUnwrap(SyncSample.voids(result).first)
        XCTAssertEqual(found.reason, "卡住")
        XCTAssertEqual(Set(found.text.split(separator: "\n")), ["門鈴", "電話"])
    }

    // MARK: 舊檔

    func test兩台匯入同一份舊檔補的編號一樣合完不會變兩倍() throws {
        let text = """
        {"v":1,"settings":{},"days":{"2026-10-30":{
         "beans":[{"t":5000,"start":1000,"len":25},{"t":9000,"len":25},{"t":9000,"len":25}],
         "voids":[{"t":7000,"typeId":"t1","minute":6,"reason":"","text":""}]}}}
        """
        let one = try StateDecoding.parseBackup(text)
        let two = try StateDecoding.parseBackup(text)
        XCTAssertEqual(SyncSample.beans(one).map(\.id), SyncSample.beans(two).map(\.id))
        XCTAssertEqual(merged(one, two).days, one.days)
    }
}
