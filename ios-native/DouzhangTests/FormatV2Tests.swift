@testable import Douzhang
import XCTest

/// 格式 v2（規格與邊界情況表在 .analytics/04-資料結構.md）：
/// 每顆的編號與時區、提早做完的時刻、作廢留下的東西、哪一天怎麼算、讀寫來回、舊檔升級。
final class FormatV2Tests: XCTestCase {
    private let minute = Moment.minute
    private let base = Moment.local(2026, 11, 17, 9)
    private let tokyo = "Asia/Tokyo"

    /// 世界標準時間 2026 年 11 月某日幾點：跟跑測試的機器在哪個時區無關。
    private func utc(_ day: Int, _ hour: Int, _ past: Int = 0) -> Millis {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let parts = DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: past)
        let date = calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
        return date.timeIntervalSince1970 * Params.msPerSecond
    }

    private func reread(_ state: AppState) throws -> AppState {
        try StateDecoding.parse(StateEncoding.text(state))
    }

    // MARK: 一顆身上帶的東西

    func test開始時定編號與時區收下時抄進番茄() throws {
        let started = Machine.start(Store.blank(), now: base, zone: tokyo)
        let run = try XCTUnwrap(started.focusRun)
        XCTAssertEqual(run.id, Store.recordId(base))
        XCTAssertEqual(run.zone, tokyo)
        let kept = Machine.keep(started, now: base + 25 * minute, text: "")
        let bean = try XCTUnwrap(kept.days[Machine.dayKey(of: run)]?.beans.first)
        XCTAssertEqual(bean.id, run.id)
        XCTAssertEqual(bean.zone, tokyo)
        XCTAssertFalse(bean.done)
        XCTAssertNil(bean.doneAt)
    }

    func test提早做完只記第一次按的時刻() throws {
        var state = Machine.start(Store.blank(), now: base)
        state = Machine.markDone(state, now: base + 12 * minute)
        state = Machine.markDone(state, now: base + 20 * minute)
        XCTAssertEqual(state.focusRun?.doneAt, base + 12 * minute)
        state = Machine.keep(state, now: base + 25 * minute, text: "")
        let bean = try XCTUnwrap(state.days[Store.dayKey(base)]?.beans.first)
        XCTAssertTrue(bean.done)
        XCTAssertEqual(bean.doneAt, base + 12 * minute)
    }

    func test作廢留下編號開始時刻原訂長度與記過的念頭() throws {
        var state = Machine.start(Store.blank(), now: base, zone: tokyo)
        state = Machine.jot(state, kind: .notes, text: "回信給編輯")
        state = Machine.jot(state, kind: .pings, text: "快遞")
        state = Machine.voidBean(state, now: base + 8 * minute, reason: "訊息", text: "")
        let entry = try XCTUnwrap(state.days.values.flatMap(\.voids).first)
        XCTAssertEqual(entry.id, Store.recordId(base))
        XCTAssertEqual(entry.start, base)
        XCTAssertEqual(entry.zone, tokyo)
        XCTAssertEqual(entry.len, Store.defaultType.len)
        XCTAssertEqual(entry.minute, 8)
        XCTAssertEqual(entry.notes, ["回信給編輯"])
        XCTAssertEqual(entry.pings, ["快遞"])
    }

    func test休息完自己開始的下一顆也有編號與時區() throws {
        var state = Store.blank()
        state.settings.autoNext = true
        state = Machine.start(state, now: base)
        state = Machine.keep(state, now: base + 25 * minute, text: "")
        let endAt = try XCTUnwrap(state.restRun?.endAt)
        let startAt = endAt + Params.autoNextDelayMs
        let next = try XCTUnwrap(Machine.settle(state, now: startAt + minute, zone: tokyo).focusRun)
        XCTAssertEqual(next.id, Store.recordId(startAt))
        XCTAssertEqual(next.zone, tokyo)
    }

    // MARK: 哪一天

    func test出國那顆照當地的日期算() {
        // 世界標準時間 11 月 5 日 15:30＝東京 6 日 00:30＝洛杉磯 5 日 07:30
        let time = utc(5, 15, 30)
        XCTAssertEqual(Store.dayKey(time, zone: tokyo), "2026-11-06")
        XCTAssertEqual(Store.dayKey(time, zone: "America/Los_Angeles"), "2026-11-05")
    }

    func test認不得的時區照手機現在的時區算() {
        let time = utc(5, 15, 30)
        XCTAssertEqual(Store.dayKey(time, zone: "Not/AZone"), Store.dayKey(time))
    }

    func test讀檔時每筆照開始那天歸位沒有時區的留在原本的格子() throws {
        let begin = Int(utc(5, 15, 30))
        let kept = begin + Int(25 * minute)
        let text = """
        {"v":2,"settings":{},"days":{"2026-11-05":{"beans":[
         {"t":\(kept),"start":\(begin),"tz":"Asia/Tokyo","len":25},
         {"t":\(kept),"start":\(begin),"len":25}],"voids":[]}}}
        """
        let days = try StateDecoding.parse(text).days
        XCTAssertEqual(days["2026-11-06"]?.beans.map(\.zone), [tokyo])
        XCTAssertEqual(days["2026-11-05"]?.beans.map(\.zone), [nil])
    }

    // MARK: 讀寫來回、舊檔

    func test新欄位寫出去再讀回來一模一樣() throws {
        var state = Machine.start(Store.blank(), now: base, zone: tokyo)
        state = Machine.jot(state, kind: .notes, text: "念頭")
        state = Machine.voidBean(state, now: base + 8 * minute, reason: "卡住", text: "")
        state = Machine.start(state, now: base + 10 * minute, zone: tokyo)
        state = Machine.markDone(state, now: base + 20 * minute)
        XCTAssertEqual(try reread(state), state)
        state = Machine.keep(state, now: base + 35 * minute, text: "寫完")
        state = SettingsLogic.removeType(state, id: "t3", now: base)
        XCTAssertEqual(try reread(state), state)
    }

    func test舊檔讀進來補編號不補時區讀幾次都一樣() throws {
        let text = """
        {"v":1,"settings":{},"days":{"2026-10-30":{
         "beans":[{"t":5000,"start":1000,"len":25},{"t":9000,"len":25},{"t":9000,"len":25}],
         "voids":[{"t":7000,"typeId":"t1","minute":6,"reason":"","text":""}]}}}
        """
        let day = try XCTUnwrap(StateDecoding.parse(text).days["2026-10-30"])
        XCTAssertEqual(day.beans.map(\.id), ["r1000", "r9000", "r9000-2"])
        XCTAssertEqual(day.voids.map(\.id), ["r7000"])
        XCTAssertEqual(day.beans.map(\.zone), [nil, nil, nil])
        XCTAssertNil(day.voids.first?.len)
        XCTAssertEqual(try StateDecoding.parse(text), try StateDecoding.parse(text))
    }
}
