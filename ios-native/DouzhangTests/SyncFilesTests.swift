@testable import Douzhang
import XCTest

/// 雲端檔案的路徑、寫法、讀法（.vibe/QC-0003/J-規格.md 包 A）。
final class SyncFilesTests: XCTestCase {
    private let base = Moment.local(2026, 11, 24, 9)
    private let key = "2026-11-24"
    private let device = SyncSample.other

    private func read(_ files: [String: String]) -> [SyncFiles.Remote] {
        SyncFiles.remotes(files.mapValues { Data($0.utf8) }, except: SyncSample.phone)
    }

    /// 那個月的檔：一天一顆。
    private func month(version: Int = Store.formatVersion, day: String, bean: String) -> String {
        #"{"v":\#(version),"days":{"\#(day)":{"beans":[\#(bean)],"voids":[]}},"gone":{}}"#
    }

    private let oneBean = #"{"id":"r1","t":5000,"len":25,"typeId":"t1"}"#

    // MARK: 路徑

    func test只認月份檔與標籤檔() {
        let month = SyncFiles.Place(device: device, month: "2026-11")
        XCTAssertEqual(SyncFiles.locate("\(device)/2026-11.json"), month)
        let tags = SyncFiles.Place(device: device, month: nil)
        XCTAssertEqual(SyncFiles.locate("\(device)/tags.json"), tags)
    }

    func test其他路徑一律不認() {
        let bad = [
            "tags.json",
            "\(device)",
            "\(device)/",
            "\(device)/2026-13.json",
            "\(device)/2026-00.json",
            "\(device)/2026-1.json",
            "\(device)/0001-01.json",
            "\(device)/2026-11.json\n",
            "\(device)/2026-11.txt",
            "\(device)/../tags.json",
            "\(device)/a/tags.json",
            "/\(device)/tags.json",
            "../tags.json",
            "phone/tags.json",
            "\(device)x/tags.json",
        ]
        for path in bad {
            XCTAssertNil(SyncFiles.locate(path), path)
        }
    }

    // MARK: 寫

    func test寫出去再讀回來一樣() throws {
        var state = Machine.start(Store.blank(), now: base, zone: "Asia/Taipei")
        state = Machine.jot(state, kind: .notes, text: "念頭")
        state = Machine.markDone(state, now: base + Moment.minute)
        state = Machine.keep(state, now: base + 25 * Moment.minute, text: "寫完")
        state = SettingsLogic.removeType(state, id: "t3", now: base)
        let remote = try XCTUnwrap(SyncSample.remote(state).first)
        XCTAssertEqual(remote.device, device)
        XCTAssertEqual(remote.days, state.days)
        XCTAssertEqual(remote.types, state.settings.types)
        XCTAssertEqual(remote.removed, state.settings.removedTypes)
    }

    func test同樣的內容每次寫出來一樣() {
        var state = SyncSample.state(key, SyncSample.bean("r1", at: base))
        state.days["2026-11-25"] = DayRecord(beans: [SyncSample.bean("r2", at: base + 1)])
        let first = SyncFiles.outgoing(state, device: device)
        XCTAssertEqual(first, SyncFiles.outgoing(state, device: device))
        XCTAssertEqual(first.keys.sorted(), ["\(device)/2026-11.json", "\(device)/tags.json"])
    }

    func test一個月一個檔空的月份不寫() {
        var state = SyncSample.state(key, SyncSample.bean("r1", at: base))
        state.days["2026-10-01"] = DayRecord()
        state.days["2026-09-30"] = DayRecord(voids: [SyncSample.voided("r2", at: base)])
        let paths = SyncFiles.outgoing(state, device: device).keys.sorted()
        let names = ["2026-09.json", "2026-11.json", "tags.json"]
        XCTAssertEqual(paths, names.map { "\(device)/\($0)" })
    }

    func test進行中那顆與偏好不寫出去() throws {
        var state = Machine.start(Store.blank(), now: base)
        state.doing = "祕密的事"
        let files = SyncFiles.outgoing(state, device: device)
        XCTAssertEqual(files.keys.sorted(), ["\(device)/tags.json"])
        let text = try XCTUnwrap(files["\(device)/tags.json"])
        XCTAssertFalse(text.contains("祕密的事"))
        XCTAssertFalse(text.contains("ambience"))
        XCTAssertFalse(text.contains("\"typeId\""))
    }

    func test測試顆與沒有編號的不寫也不收() {
        var dev = SyncSample.bean("r1", at: base)
        dev.typeId = Machine.devTypeId
        let state = SyncSample.state([
            key: DayRecord(beans: [dev, SyncSample.bean("", at: base)]),
        ])
        let paths = SyncFiles.outgoing(state, device: device).keys.sorted()
        XCTAssertEqual(paths, ["\(device)/tags.json"])
        let devText = #"{"id":"r1","t":5000,"len":25,"typeId":"dev-test"}"#
        for bean in [devText, #"{"t":5000,"len":25,"typeId":"t1"}"#] {
            let remote = read(["\(device)/2026-11.json": month(day: key, bean: bean)]).first
            XCTAssertEqual(remote?.days[key], DayRecord())
        }
    }

    func test雲端檔的時刻都是整毫秒() {
        let state = SyncSample.state(key, SyncSample.bean("r1", at: 5000.75))
        let day = SyncSample.remote(state).first?.days[key]
        XCTAssertEqual(day?.beans.map(\.keptAt), [5000])
    }

    // MARK: 讀

    func test自己寫的不讀別台的照編號排() {
        let text = month(day: key, bean: oneBean)
        let remotes = read([
            "\(SyncSample.phone)/2026-11.json": text,
            "\(SyncSample.third)/2026-11.json": text,
            "\(device)/2026-11.json": text,
        ])
        XCTAssertEqual(remotes.map(\.device), [device, SyncSample.third])
    }

    func test自己的編號大小寫不同也認得() {
        let own = "ABCDEF00-1111-4111-8111-111111111111"
        let text = month(day: key, bean: oneBean)
        let files = ["\(own.lowercased())/2026-11.json": Data(text.utf8)]
        XCTAssertTrue(SyncFiles.remotes(files, except: own).isEmpty)
    }

    func test壞檔新版本太大的整檔跳過別的照讀() {
        let newer = month(version: Store.formatVersion + 1, day: "2026-09-01", bean: oneBean)
        var files = [
            "\(device)/2026-08.json": "{壞",
            "\(device)/2026-09.json": newer,
            "\(device)/2026-10.json": #"{"days":{}}"#,
            "\(device)/2026-11.json": month(day: key, bean: oneBean),
            "\(device)/tags.json": "[]",
        ].mapValues { Data($0.utf8) }
        files["\(device)/2026-07.json"] = Data(count: Params.importMaxBytes + 1)
        let remotes = SyncFiles.remotes(files, except: SyncSample.phone)
        XCTAssertEqual(remotes.count, 1)
        XCTAssertEqual(remotes.first?.days.keys.sorted(), [key])
        XCTAssertEqual(remotes.first?.types, [])
    }

    func test日期鍵不對的那天跳過() {
        let days = ["2026-11-31", "2026-11-4", "2026-12-01", "abc", "2026-11-24x"]
            .map { #""\#($0)":{"beans":[\#(oneBean)]}"# }
            .joined(separator: ",")
        let good = #""\#(key)":{"beans":[\#(oneBean)]}"#
        let text = #"{"v":\#(Store.formatVersion),"days":{\#(days),\#(good)}}"#
        let remote = read(["\(device)/2026-11.json": text]).first
        XCTAssertEqual(remote?.days.keys.sorted(), [key])
    }

    func test欄位型別不對的照讀檔那套補() throws {
        let bean = #"{"id":"r1","t":"x","len":"25","notes":"x","typeId":7,"done":1}"#
        let remote = read(["\(device)/2026-11.json": month(day: key, bean: bean)]).first
        let found = try XCTUnwrap(remote?.days[key]?.beans.first)
        XCTAssertEqual(found.keptAt, 0)
        XCTAssertEqual(found.len, Store.defaultType.len)
        XCTAssertEqual(found.notes, [])
        XCTAssertEqual(found.typeId, "")
        XCTAssertFalse(found.done)
    }
}
