@testable import Douzhang
import XCTest

/// iCloud 接頭對的是哪個帳號：代號的寫法、問的是哪一個、換機還原、帳本讀不到。
@MainActor
final class CloudAccountTests: XCTestCase {
    // MARK: 代號

    func test同一個帳號代號寫法變了也不問換了才問() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        phone.drive.isRestless = true
        await phone.turnOn()
        await phone.wakeUp()
        XCTAssertFalse(phone.link.asking)
        XCTAssertFalse(phone.drive.written.isEmpty)

        let reopened = try stage.phone("a", bean: "r1")
        reopened.drive.isRestless = true
        await reopened.open()
        XCTAssertFalse(reopened.link.asking)
        XCTAssertEqual(reopened.device, phone.device)

        reopened.drive.account = "someone"
        await reopened.wakeUp()
        XCTAssertEqual(reopened.link.question, .account)
        reopened.link.adopt()
        await reopened.idle()
        XCTAssertFalse(reopened.link.asking)
        XCTAssertNotEqual(reopened.device, phone.device)
        // 刪得到自己的：代號寫法變了也認得
        let isErased = await reopened.link.eraseCloud()
        XCTAssertTrue(isErased)
    }

    func test框開著換回原本的帳號寫法變了也認得() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        phone.drive.isRestless = true
        await phone.turnOn()
        let device = phone.device
        phone.drive.account = "someone"
        await phone.wakeUp()
        XCTAssertEqual(phone.link.question, .account)
        phone.drive.account = "me"
        phone.link.adopt()
        await phone.idle()
        XCTAssertFalse(phone.link.asking)
        XCTAssertEqual(phone.device, device)
        XCTAssertEqual(phone.host.backups, 1)
    }

    // MARK: 答應的是問的那一個

    func test框開著又換成第三個帳號再按要再問() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        let before = phone.drive.written.count
        phone.drive.account = "someone"
        await phone.wakeUp()
        XCTAssertEqual(phone.link.question, .account)
        XCTAssertEqual(phone.link.asks, 1)

        phone.drive.account = "third"
        phone.link.adopt()
        await phone.idle()
        XCTAssertEqual(phone.link.question, .account)
        // 問的是同一句，畫面靠這個數字才知道要再跳一次
        XCTAssertEqual(phone.link.asks, 2)
        XCTAssertEqual(phone.drive.written.count, before)
        XCTAssertEqual(phone.host.backups, 1)
        XCTAssertEqual(phone.ledgerFile.load()?.identity, "me")

        phone.link.adopt()
        await phone.idle()
        XCTAssertFalse(phone.link.asking)
        XCTAssertEqual(phone.host.backups, 2)
        XCTAssertEqual(phone.ledgerFile.load()?.identity, "third")
    }

    // MARK: 換機還原

    func test換機還原先問不讀不寫不備份() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let other = try stage.phone("b", bean: "r9")
        await other.turnOn()
        let old = try stage.phone("a", bean: "r1")
        await old.turnOn()
        old.ledgerFile.remove()

        let restored = try stage.phone("a", bean: "r1")
        await restored.open()
        XCTAssertEqual(restored.link.question, .restored)
        // 只問了一次登入的是哪個
        XCTAssertEqual(restored.drive.calls, 1)
        XCTAssertEqual(restored.host.backups, 0)
        XCTAssertEqual(restored.host.ids, ["r1"])
        XCTAssertNil(restored.ledgerFile.load())

        restored.link.adopt()
        await restored.idle()
        XCTAssertFalse(restored.link.asking)
        XCTAssertEqual(restored.host.backups, 1)
        XCTAssertEqual(restored.host.ids, ["r1", "r9"])
        XCTAssertNotEqual(restored.device, old.device)
    }

    func test換機還原按先不要下次打開再問() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let old = try stage.phone("a", bean: "r1")
        await old.turnOn()
        old.ledgerFile.remove()

        let restored = try stage.phone("a", bean: "r1")
        await restored.open()
        restored.link.decline()
        await restored.wakeUp()
        XCTAssertFalse(restored.link.asking)
        XCTAssertEqual(restored.link.problem, .paused)
        XCTAssertEqual(restored.drive.calls, 1)

        let again = try stage.phone("a", bean: "r1")
        await again.open()
        XCTAssertEqual(again.link.question, .restored)
        // 自己關掉再打開就是親手打開，不問
        again.link.turnOff()
        again.link.turnOn()
        await again.idle()
        XCTAssertFalse(again.link.asking)
        XCTAssertFalse(again.drive.written.isEmpty)
    }

    // MARK: 帳本

    func test帳本讀不到不拉不傳不問讀得到了換過帳號照問() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        try stage.lockLedger(phone, true)

        let reopened = try stage.phone("a", bean: "r1")
        reopened.drive.account = "someone"
        await reopened.open()
        XCTAssertEqual(reopened.drive.calls, 0)
        XCTAssertFalse(reopened.link.asking)
        XCTAssertEqual(reopened.host.backups, 0)
        reopened.link.turnOff()
        // 不知道有沒有，當有：寧可多問一次
        XCTAssertTrue(reopened.link.hasCopy)

        try stage.lockLedger(phone, false)
        reopened.link.turnOn()
        await reopened.idle()
        XCTAssertEqual(reopened.link.question, .account)
    }

    // MARK: 這是哪支手機

    func test沒開同步的人不問這是哪支手機打開才問() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let diary = CloudDiary()
        let vendor: () -> String? = {
            diary.add("問")
            return "a"
        }
        let phone = try stage.phone("a", bean: "r1", vendor: vendor)
        phone.link.start(phone.host)
        phone.link.setPaid(true)
        phone.link.becameActive()
        phone.host.keep("r2")
        phone.link.enteredBackground()
        XCTAssertFalse(phone.link.hasCopy)
        XCTAssertEqual(diary.all, [])
        await phone.turnOn()
        XCTAssertFalse(diary.all.isEmpty)
    }

    func test問不到是哪支手機說要刪的也記得但不刪() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        let unsure = try stage.phone("a", vendor: { nil })
        unsure.link.start(unsure.host)
        let first = await unsure.link.eraseCloud()
        XCTAssertFalse(first)
        XCTAssertEqual(unsure.link.problem, .eraseFailed)
        XCTAssertEqual(unsure.drive.calls, 0)
        XCTAssertTrue(stage.hasCloud)

        // 問得到了：帳本也讀得到了，這才刪
        let reopened = try stage.phone("a")
        reopened.link.start(reopened.host)
        XCTAssertEqual(reopened.link.problem, .eraseFailed)
        let second = await reopened.link.eraseCloud()
        XCTAssertTrue(second)
        XCTAssertFalse(stage.hasCloud)
        XCTAssertFalse(reopened.link.hasCopy)
    }
}
