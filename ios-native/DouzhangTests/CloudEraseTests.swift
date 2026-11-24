@testable import Douzhang
import XCTest

/// iCloud 那份要刪的時候：關掉選了也刪掉、清除所有資料。
@MainActor
final class CloudEraseTests: XCTestCase {
    // MARK: 刪雲端

    func test關掉選也刪掉雲端就沒有了另一台停下來問() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        let two = try stage.phone("b", bean: "r2")
        await one.turnOn()
        await two.turnOn()
        let isErased = await one.link.eraseCloud()
        XCTAssertTrue(isErased)
        XCTAssertFalse(one.link.isOn)
        XCTAssertFalse(stage.hasCloud)
        XCTAssertNil(one.ledgerFile.load())
        XCTAssertEqual(one.host.ids, ["r1"])

        await two.wakeUp()
        await CloudStage.until("停下來問") { two.link.question == .emptied }
        XCTAssertEqual(two.host.ids, ["r1", "r2"])
    }

    func test關掉選留著雲端還在再打開接著用() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        let device = phone.device
        phone.link.turnOff()
        XCTAssertNotNil(stage.text("\(device)/2026-11.json"))
        await phone.turnOn()
        XCTAssertEqual(phone.device, device)
        XCTAssertFalse(phone.link.asking)
    }

    func test傳到一半刪雲端不會寫回來() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        phone.drive.writePause = 0.2
        phone.link.start(phone.host)
        phone.link.setPaid(true)
        phone.link.turnOn()
        await CloudStage.until("正在寫") { phone.drive.calls > 4 }
        let isErased = await phone.link.eraseCloud()
        XCTAssertTrue(isErased)
        await CloudStage.moment()
        XCTAssertFalse(stage.hasCloud)
        XCTAssertNil(phone.ledgerFile.load())
        XCTAssertEqual(phone.drive.busiest, 1)
    }

    func test刪的時候又打開是刪完才開工() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        phone.drive.writePause = 0.2
        phone.link.start(phone.host)
        phone.link.setPaid(true)
        phone.link.turnOn()
        await CloudStage.until("正在寫") { phone.drive.calls > 4 }
        let erasing = Task { await phone.link.eraseCloud() }
        await CloudStage.until("正在刪") { phone.link.isErasing }
        phone.link.turnOn()
        let isErased = await erasing.value
        XCTAssertTrue(isErased)
        await phone.idle()
        XCTAssertFalse(phone.link.asking)
        XCTAssertNotNil(stage.text("\(phone.device)/2026-11.json"))
        XCTAssertEqual(phone.drive.busiest, 1)
    }

    func test刪不成說一句再按一次就刪掉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        phone.drive.account = nil
        let first = await phone.link.eraseCloud()
        XCTAssertFalse(first)
        XCTAssertEqual(phone.link.problem, .eraseFailed)
        XCTAssertTrue(phone.link.hasCopy)

        // 登入的是別的帳號：不准刪到別人的
        phone.drive.account = "someone"
        let second = await phone.link.eraseCloud()
        XCTAssertFalse(second)
        XCTAssertEqual(phone.link.problem, .eraseOther)
        XCTAssertTrue(stage.hasCloud)

        phone.drive.account = "me"
        let third = await phone.link.eraseCloud()
        XCTAssertTrue(third)
        XCTAssertNil(phone.link.problem)
        XCTAssertFalse(phone.link.hasCopy)
    }

    // MARK: 沒刪成，關掉再打開

    func test沒刪成重開那句還在再按就刪掉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        phone.drive.account = nil
        let first = await phone.link.eraseCloud()
        XCTAssertFalse(first)

        let reopened = try stage.phone("a", bean: "r1")
        await reopened.open()
        XCTAssertEqual(reopened.link.problem, .eraseFailed)
        XCTAssertTrue(reopened.link.hasCopy)
        // 不自動重刪，等人按
        XCTAssertEqual(reopened.drive.calls, 0)
        let second = await reopened.link.eraseCloud()
        XCTAssertTrue(second)
        XCTAssertFalse(stage.hasCloud)
        XCTAssertNil(reopened.link.problem)
        XCTAssertFalse(reopened.link.hasCopy)
        XCTAssertNil(try stage.phone("a").link.lastingProblem)
    }

    func test沒刪成後親手再打開就不刪了() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        phone.drive.account = nil
        await phone.link.eraseCloud()
        phone.drive.account = "me"
        await phone.turnOn()
        XCTAssertNil(phone.link.problem)
        XCTAssertNil(phone.link.erasePending)
        XCTAssertFalse(phone.link.asking)
        XCTAssertTrue(stage.hasCloud)

        let reopened = try stage.phone("a", bean: "r1")
        await reopened.open()
        XCTAssertNil(reopened.link.problem)
    }

    func test清除時沒刪成帳本忘了重開還刪得掉也不刪別人的() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        phone.drive.account = nil
        phone.link.wipe(erasing: true)
        await CloudStage.until("說沒刪成") { phone.link.problem == .eraseFailed }
        XCTAssertNil(phone.ledgerFile.load())

        let reopened = try stage.phone("a")
        reopened.drive.account = "someone"
        await reopened.open()
        XCTAssertTrue(reopened.link.hasCopy)
        let first = await reopened.link.eraseCloud()
        XCTAssertFalse(first)
        XCTAssertEqual(reopened.link.problem, .eraseOther)
        XCTAssertTrue(stage.hasCloud)

        reopened.drive.account = "me"
        let second = await reopened.link.eraseCloud()
        XCTAssertTrue(second)
        XCTAssertFalse(stage.hasCloud)
    }

    func test沒刪成之後清除選留著就連那句也收掉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        phone.drive.account = nil
        await phone.link.eraseCloud()
        phone.link.wipe(erasing: false)
        XCTAssertNil(phone.link.problem)
        XCTAssertFalse(phone.link.hasCopy)
        XCTAssertTrue(stage.hasCloud)
        XCTAssertNil(try stage.phone("a").link.lastingProblem)
    }

    // MARK: 要不要問

    func test退款之後還問得到也刪得掉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        XCTAssertFalse(phone.link.hasCopy)
        await phone.turnOn()
        phone.link.setPaid(false)
        XCTAssertTrue(phone.link.hasCopy)

        // 關掉再打開，沒買
        let reopened = try stage.phone("a", bean: "r1")
        reopened.link.start(reopened.host)
        reopened.link.turnOff()
        XCTAssertTrue(reopened.link.hasCopy)
        let isErased = await reopened.link.eraseCloud()
        XCTAssertTrue(isErased)
        XCTAssertFalse(reopened.link.hasCopy)
        XCTAssertFalse(stage.hasCloud)
    }

    // MARK: 清除所有資料

    func test清除所有資料關同步忘帳本雲端照答案() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        let month = "\(phone.device)/2026-11.json"
        phone.link.wipe(erasing: false)
        phone.host.commit(Store.blank())
        await CloudStage.moment()
        XCTAssertFalse(phone.link.isOn)
        XCTAssertNil(phone.ledgerFile.load())
        XCTAssertNotNil(stage.text(month))

        let other = try stage.phone("b", bean: "r2")
        await other.turnOn()
        other.link.wipe(erasing: true)
        await CloudStage.until("刪掉雲端") { !stage.hasCloud && !other.link.isErasing }
        XCTAssertFalse(other.link.isOn)
        XCTAssertNil(other.ledgerFile.load())
    }
}
