@testable import Douzhang
import XCTest

/// iCloud 接頭什麼時候拉、什麼時候傳：本機資料夾扮 iCloud，兩份資料扮兩支手機。
/// 合併規則本身在 SyncMergeTests、SyncLawsTests 測過，這裡不重測。
@MainActor
final class CloudLinkTests: XCTestCase {
    // MARK: 開關

    func test預設關什麼都不碰() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        phone.link.start(phone.host)
        phone.link.setPaid(true)
        phone.link.becameActive()
        phone.host.keep("r2")
        phone.link.enteredBackground()
        await CloudStage.moment()
        XCTAssertFalse(phone.link.isOn)
        XCTAssertEqual(phone.drive.calls, 0)
        XCTAssertEqual(phone.host.backups, 0)
    }

    func test沒買不同步退款就停買了接著動() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        phone.link.start(phone.host)
        phone.link.turnOn()
        await CloudStage.moment()
        XCTAssertEqual(phone.drive.calls, 0)

        phone.link.setPaid(true)
        await phone.idle()
        XCTAssertFalse(phone.drive.written.isEmpty)

        phone.link.setPaid(false)
        let before = phone.drive.calls
        phone.host.keep("r2")
        phone.link.becameActive()
        await CloudStage.moment()
        XCTAssertEqual(phone.drive.calls, before)
        XCTAssertTrue(phone.link.isOn)
    }

    func test開關記得住() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let first = try stage.phone("a")
        await first.turnOn()
        XCTAssertTrue(try stage.phone("a").link.isOn)
        first.link.turnOff()
        XCTAssertFalse(try stage.phone("a").link.isOn)
    }

    // MARK: 兩台

    func test兩台互相看得到() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        let two = try stage.phone("b", bean: "r2")
        await one.turnOn()
        await two.turnOn()
        XCTAssertEqual(two.host.ids, ["r1", "r2"])
        await one.wakeUp()
        XCTAssertEqual(one.host.ids, ["r1", "r2"])
    }

    func test離線各收一顆連上再合() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        let two = try stage.phone("b")
        await one.turnOn()
        await two.turnOn()
        one.drive.account = nil
        two.drive.account = nil
        one.host.keep("r2")
        two.host.keep("r3")
        await CloudStage.moment()

        one.drive.account = "me"
        two.drive.account = "me"
        await one.wakeUp()
        await two.wakeUp()
        await one.wakeUp()
        XCTAssertEqual(one.host.ids, ["r1", "r2", "r3"])
        XCTAssertEqual(two.host.ids, ["r1", "r2", "r3"])
    }

    func test只寫自己的資料夾() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        let two = try stage.phone("b", bean: "r2")
        await one.turnOn()
        await two.turnOn()
        await one.wakeUp()
        XCTAssertNotEqual(one.device, two.device)
        XCTAssertTrue(one.drive.written.allSatisfy { $0.hasPrefix("\(one.device)/") })
        XCTAssertTrue(two.drive.written.allSatisfy { $0.hasPrefix("\(two.device)/") })
    }

    func test雲端有動靜就自己拉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a")
        let two = try stage.phone("b")
        await one.turnOn()
        await two.turnOn()
        two.host.keep("r1")
        await CloudStage.until("傳上去") { two.drive.written.count > 1 }
        one.drive.tell()
        await CloudStage.until("自己拉下來") { one.host.ids == ["r1"] }
    }

    func test合進來的也會寫進自己的資料夾() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        let two = try stage.phone("b")
        await one.turnOn()
        await two.turnOn()
        let mine = stage.text("\(two.device)/2026-11.json") ?? ""
        XCTAssertTrue(mine.contains(#""r1""#))
    }

    // MARK: 讀不到的檔

    func test沒下載好的跳過下次補() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        await one.turnOn()
        let late = "\(one.device)/2026-11.json"

        let two = try stage.phone("b", bean: "r2")
        two.drive.pending = [late]
        await two.turnOn()
        XCTAssertEqual(two.host.ids, ["r2"])
        XCTAssertEqual(two.drive.asked, [late])
        XCTAssertFalse(two.drive.reads.contains(late))

        two.drive.pending = []
        await two.wakeUp()
        XCTAssertEqual(two.host.ids, ["r1", "r2"])
    }

    func test壞檔與比較新的檔跳過而且原封不動() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        await one.turnOn()
        let broken = "\(SyncSample.third)/2026-11.json"
        try stage.put("{這不是 JSON", at: broken)
        let newer = "\(SyncSample.third)/2026-10.json"
        let future = #"{"v":99,"days":{"2026-10-01":{"beans":[{"id":"r9","t":1,"len":25}]}}}"#
        try stage.put(future, at: newer)

        let two = try stage.phone("b", bean: "r2")
        await two.turnOn()
        XCTAssertEqual(two.host.ids, ["r1", "r2"])
        XCTAssertEqual(stage.text(broken), "{這不是 JSON")
        XCTAssertEqual(stage.text(newer), future)
    }
}
