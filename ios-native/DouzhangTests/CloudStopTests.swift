@testable import Douzhang
import XCTest

/// iCloud 接頭停下來的時候：備份、停下來問、沒登入。
@MainActor
final class CloudStopTests: XCTestCase {
    // MARK: 先備份

    func test帳本是新的先備份一次之後不再備份() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        XCTAssertEqual(phone.host.backups, 1)
        await phone.wakeUp()
        XCTAssertEqual(phone.host.backups, 1)

        let reopened = try stage.phone("a", bean: "r1")
        await reopened.turnOn()
        XCTAssertEqual(reopened.host.backups, 0)
        XCTAssertEqual(reopened.device, phone.device)
    }

    func test備份不成就不同步而且說一句() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        await one.turnOn()
        let two = try stage.phone("b", bean: "r2")
        two.host.canBackUp = false
        await two.turnOn()
        XCTAssertEqual(two.link.problem, .backupFailed)
        XCTAssertEqual(two.host.ids, ["r2"])
        XCTAssertTrue(two.drive.written.isEmpty)
        XCTAssertNil(two.ledgerFile.load())

        two.host.canBackUp = true
        await two.wakeUp()
        XCTAssertNil(two.link.problem)
        XCTAssertEqual(two.host.ids, ["r1", "r2"])
    }

    func test清單列不出來也不會一直備份() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        phone.drive.isBroken = true
        await phone.turnOn()
        await phone.wakeUp()
        XCTAssertEqual(phone.host.backups, 1)
    }

    // MARK: 停下來問

    func test換了帳號停下來問放進去才合() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        let before = phone.drive.written.count
        let device = phone.device

        phone.drive.account = "someone"
        let bean = #"{"id":"r9","t":5000,"len":25,"typeId":"t1"}"#
        let month = #"{"v":3,"days":{"2026-11-20":{"beans":[\#(bean)]}}}"#
        try stage.put(month, at: "\(SyncSample.third)/2026-11.json")
        await phone.wakeUp()
        XCTAssertEqual(phone.link.question, .account)
        XCTAssertTrue(phone.link.asking)
        phone.host.keep("r2")
        await phone.wakeUp()
        XCTAssertEqual(phone.host.ids, ["r1", "r2"])
        XCTAssertEqual(phone.drive.written.count, before)

        phone.link.adopt()
        await phone.idle()
        XCTAssertFalse(phone.link.asking)
        XCTAssertEqual(phone.host.ids, ["r1", "r2", "r9"])
        XCTAssertNotEqual(phone.device, device)
        XCTAssertGreaterThan(phone.drive.written.count, before)
    }

    func test寫到一半換帳號後面的不會寫進去() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        phone.drive.onWrite = { [weak drive = phone.drive] in drive?.account = "someone" }
        await phone.turnOn()
        await CloudStage.until("停下來問") { phone.link.question == .account }
        XCTAssertEqual(phone.drive.written.count, 1)
    }

    func test先不要這次打開不再問下次打開再問() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        phone.drive.account = "someone"
        await phone.wakeUp()
        phone.link.decline()
        let before = phone.drive.calls
        await phone.wakeUp()
        XCTAssertFalse(phone.link.asking)
        XCTAssertEqual(phone.link.problem, .paused)
        XCTAssertEqual(phone.drive.calls, before)

        let reopened = try stage.phone("a", bean: "r1")
        reopened.drive.account = "someone"
        await reopened.turnOn()
        XCTAssertTrue(reopened.link.asking)
    }

    func test看過的雲端整個空了停下來問不自己補回去() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        try FileManager.default.removeItem(at: stage.cloud)
        phone.host.keep("r2")
        phone.link.enteredBackground()
        await phone.idle()
        XCTAssertFalse(stage.hasCloud)
        await phone.wakeUp()
        await CloudStage.until("停下來問") { phone.link.question == .emptied }
        XCTAssertFalse(stage.hasCloud)

        phone.link.adopt()
        await phone.idle()
        XCTAssertNotNil(stage.text("\(phone.device)/2026-11.json"))
    }

    // MARK: 沒登入

    func test沒登入持續一陣子才說登入就收掉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        phone.drive.account = nil
        await phone.turnOn()
        XCTAssertNil(phone.link.problem)
        await CloudStage.until("說一句") { phone.link.problem == .off }
        XCTAssertEqual(phone.host.backups, 0)

        phone.drive.account = "me"
        await phone.wakeUp()
        XCTAssertNil(phone.link.problem)
        XCTAssertFalse(phone.drive.written.isEmpty)
    }
}
