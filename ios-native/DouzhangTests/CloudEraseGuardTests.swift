@testable import Douzhang
import XCTest

/// 刪了救不回來：不知道是哪個 iCloud、登入的不是那一個，一律不刪，而且照實說沒刪成。
/// 刪得成的在 CloudEraseTests。
@MainActor
final class CloudEraseGuardTests: XCTestCase {
    /// 放過東西、關掉再打開，這次帳本讀不到。
    private func locked(_ stage: CloudStage) async throws -> TestPhone {
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        try stage.lockLedger(phone, true)
        return try stage.phone("a", bean: "r1")
    }

    /// 開關跟著備份回來、帳本沒有：換機還原、轉給別人的手機。雲端有別台放的。
    private func restored(_ stage: CloudStage) async throws -> TestPhone {
        let other = try stage.phone("b", bean: "r9")
        await other.turnOn()
        let old = try stage.phone("a", bean: "r1")
        await old.turnOn()
        old.ledgerFile.remove()
        return try stage.phone("a", bean: "r1")
    }

    // MARK: 帳本讀不到

    func test帳本讀不到清除選也刪掉不刪說沒刪成讀得到再按才刪() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try await locked(stage)
        await phone.open()
        XCTAssertTrue(phone.link.hasCopy)
        phone.link.wipe(erasing: true)
        await phone.idle()
        XCTAssertFalse(phone.link.isOn)
        XCTAssertEqual(phone.link.problem, .eraseFailed)
        XCTAssertEqual(phone.drive.calls, 0)
        XCTAssertTrue(stage.hasCloud)

        // 重開那句還在，帳本沒被丟掉；還是讀不到就還是不刪
        let reopened = try stage.phone("a")
        reopened.link.start(reopened.host)
        XCTAssertEqual(reopened.link.problem, .eraseFailed)
        let first = await reopened.link.eraseCloud()
        XCTAssertFalse(first)
        XCTAssertEqual(reopened.link.problem, .eraseFailed)
        XCTAssertEqual(reopened.drive.calls, 0)
        XCTAssertTrue(stage.hasCloud)

        try stage.lockLedger(reopened, false)
        let second = await reopened.link.eraseCloud()
        XCTAssertTrue(second)
        XCTAssertFalse(stage.hasCloud)
        XCTAssertNil(reopened.link.problem)
        XCTAssertFalse(reopened.link.hasCopy)
    }

    func test帳本讀不到關掉選也刪掉不刪讀得到了是別的帳號也不刪() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try await locked(stage)
        await phone.open()
        phone.drive.account = "someone"
        let first = await phone.link.eraseCloud()
        XCTAssertFalse(first)
        XCTAssertEqual(phone.link.problem, .eraseFailed)
        XCTAssertEqual(phone.drive.calls, 0)

        try stage.lockLedger(phone, false)
        let second = await phone.link.eraseCloud()
        XCTAssertFalse(second)
        XCTAssertEqual(phone.link.problem, .eraseOther)
        XCTAssertTrue(stage.hasCloud)

        phone.drive.account = "me"
        let third = await phone.link.eraseCloud()
        XCTAssertTrue(third)
        XCTAssertFalse(stage.hasCloud)
    }

    func test退款後帳本讀不到也不刪() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try await locked(stage)
        phone.link.start(phone.host)
        XCTAssertTrue(phone.link.hasCopy)
        let isErased = await phone.link.eraseCloud()
        XCTAssertFalse(isErased)
        XCTAssertEqual(phone.link.problem, .eraseFailed)
        XCTAssertEqual(phone.drive.calls, 0)
        XCTAssertTrue(stage.hasCloud)
    }

    func test說過要刪哪個帳本讀不到時也不刪那個還記得() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        phone.drive.account = nil
        await phone.link.eraseCloud()
        XCTAssertEqual(phone.link.erasePending, "me")

        try stage.lockLedger(phone, true)
        let reopened = try stage.phone("a", bean: "r1")
        await reopened.open()
        let first = await reopened.link.eraseCloud()
        XCTAssertFalse(first)
        XCTAssertEqual(reopened.drive.calls, 0)
        XCTAssertEqual(reopened.link.erasePending, "me")
        XCTAssertTrue(stage.hasCloud)
    }

    func test帳本讀不到清除選留著就不再說() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try await locked(stage)
        await phone.open()
        phone.link.wipe(erasing: true)
        XCTAssertTrue(phone.link.hasCopy)
        phone.link.wipe(erasing: false)
        XCTAssertNil(phone.link.problem)
        XCTAssertFalse(phone.link.hasCopy)
        XCTAssertEqual(phone.drive.calls, 0)
        XCTAssertTrue(stage.hasCloud)
    }

    // MARK: 這支手機沒放過

    func test換機還原清除不問選也刪掉也不刪別台的() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try await restored(stage)
        await phone.open()
        XCTAssertEqual(phone.link.question, .restored)
        phone.link.decline()
        XCTAssertTrue(phone.link.isOn)
        XCTAssertFalse(phone.link.hasCopy)

        let before = phone.drive.calls
        phone.link.wipe(erasing: true)
        await phone.idle()
        XCTAssertFalse(phone.link.isOn)
        XCTAssertNil(phone.link.problem)
        XCTAssertNil(phone.link.erasePending)
        XCTAssertEqual(phone.drive.calls, before)
        XCTAssertTrue(stage.hasCloud)
    }

    func test換機還原直接叫刪也不碰雲端() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try await restored(stage)
        await phone.open()
        let before = phone.drive.calls
        await phone.link.eraseCloud()
        XCTAssertNil(phone.link.problem)
        XCTAssertEqual(phone.drive.calls, before)
        XCTAssertTrue(stage.hasCloud)
    }

    func test打開過沒登入從沒傳過之後登入也不會刪() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let other = try stage.phone("b", bean: "r9")
        await other.turnOn()
        let phone = try stage.phone("a", bean: "r1")
        phone.drive.account = nil
        await phone.turnOn()
        XCTAssertFalse(phone.link.hasCopy)
        phone.link.wipe(erasing: true)
        await phone.idle()
        XCTAssertNil(phone.link.problem)

        phone.drive.account = "me"
        await phone.link.eraseCloud()
        XCTAssertNil(phone.link.problem)
        XCTAssertTrue(stage.hasCloud)
    }

    // MARK: 登入的是別的帳號

    func test別的帳號那裡是空的也不算刪成() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        try FileManager.default.removeItem(at: stage.cloud)
        phone.drive.account = "someone"
        let isErased = await phone.link.eraseCloud()
        XCTAssertFalse(isErased)
        XCTAssertEqual(phone.link.problem, .eraseOther)
        XCTAssertEqual(phone.link.erasePending, "me")
    }
}
