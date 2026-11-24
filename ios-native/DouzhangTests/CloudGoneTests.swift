@testable import Douzhang
import XCTest

/// 雲端空了、被別台刪掉、自己這邊壞成空的：不准拿錯的那一份去蓋。
@MainActor
final class CloudGoneTests: XCTestCase {
    // MARK: 空了不等於被刪

    func test空一下又回來不問也不傳空的時候的() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1", empty: 60)
        await phone.turnOn()
        let before = phone.drive.written.count
        let aside = stage.root.appendingPathComponent("aside")
        try FileManager.default.moveItem(at: stage.cloud, to: aside)
        phone.host.keep("r2")
        await phone.wakeUp()
        phone.link.requestPush()
        await phone.idle()
        XCTAssertFalse(phone.link.asking)
        XCTAssertEqual(phone.drive.written.count, before)
        XCTAssertFalse(stage.hasCloud)

        try FileManager.default.moveItem(at: aside, to: stage.cloud)
        await phone.wakeUp()
        XCTAssertFalse(phone.link.asking)
        // 回來過就重新算時間
        XCTAssertNil(phone.link.emptySince)
        let month = stage.text("\(phone.device)/2026-11.json") ?? ""
        XCTAssertTrue(month.contains(#""r2""#))
    }

    func test隔夠久再看還是空的才問() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1", empty: 60)
        await phone.turnOn()
        try FileManager.default.removeItem(at: stage.cloud)
        await phone.wakeUp()
        await phone.wakeUp()
        XCTAssertFalse(phone.link.asking)
        await phone.lookAgain()
        XCTAssertEqual(phone.link.question, .emptied)
    }

    func test在背景看到空的不算回來從頭算() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1", empty: 60)
        await phone.turnOn()
        try FileManager.default.removeItem(at: stage.cloud)
        phone.host.keep("r2")
        phone.link.enteredBackground()
        await phone.idle()
        XCTAssertNil(phone.link.emptySince)

        // 被系統暫停一小時才回來
        phone.link.emptySince = ContinuousClock.now - .seconds(3600)
        await phone.wakeUp()
        XCTAssertFalse(phone.link.asking)
        XCTAssertNotNil(phone.link.emptySince)
        await phone.lookAgain()
        XCTAssertEqual(phone.link.question, .emptied)
    }

    func test在背景就算隔夠久也不問() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1", empty: 60)
        await phone.turnOn()
        try FileManager.default.removeItem(at: stage.cloud)
        phone.link.enteredBackground()
        await phone.lookAgain()
        XCTAssertFalse(phone.link.asking)
        XCTAssertFalse(stage.hasCloud)
    }

    func test問之前換了帳號問的是換帳號() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1", empty: 60)
        await phone.turnOn()
        let before = phone.drive.written.count
        try FileManager.default.removeItem(at: stage.cloud)
        await phone.wakeUp()
        phone.drive.onList = { [weak drive = phone.drive] in drive?.account = "someone" }
        await phone.lookAgain()
        XCTAssertEqual(phone.link.question, .account)
        XCTAssertEqual(phone.drive.written.count, before)
    }

    // MARK: 別台刪掉了

    func test別台刪掉後只剩這台剛傳的那一檔也要問不補寫() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        let two = try stage.phone("b", bean: "r2")
        await one.turnOn()
        await two.turnOn()
        let month = "\(two.device)/2026-11.json"
        let kept = try XCTUnwrap(stage.text(month))
        let before = two.drive.written.count
        let isErased = await one.link.eraseCloud()
        XCTAssertTrue(isErased)
        // 一邊刪一邊改，iCloud 留改過的那份
        try stage.put(kept, at: month)

        await two.wakeUp()
        await two.lookAgain()
        XCTAssertEqual(two.link.question, .emptied)
        XCTAssertEqual(two.drive.written.count, before)
        XCTAssertEqual(FolderDrive.paths(in: stage.cloud), [month])
        XCTAssertEqual(two.host.ids, ["r1", "r2"])
    }

    func test傳到一半被刪掉不會又建回來() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1", empty: 60)
        await phone.turnOn()
        let before = phone.drive.written.count
        let cloud = stage.cloud
        phone.drive.onWrite = { try? FileManager.default.removeItem(at: cloud) }
        phone.host.keep("r2")
        phone.link.enteredBackground()
        await phone.idle()
        XCTAssertEqual(phone.drive.written.count, before)
        XCTAssertFalse(stage.hasCloud)
        XCTAssertFalse(phone.link.asking)

        await phone.wakeUp()
        await phone.lookAgain()
        XCTAssertEqual(phone.link.question, .emptied)
        XCTAssertFalse(stage.hasCloud)
    }

    // MARK: 自己這邊壞成空的

    func test狀態檔壞成空的換編號把自己那份合回來() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        let month = "\(phone.device)/2026-11.json"
        let before = try XCTUnwrap(stage.text(month))

        let reopened = try stage.phone("a")
        await reopened.open()
        XCTAssertEqual(reopened.host.ids, ["r1"])
        XCTAssertNotEqual(reopened.device, phone.device)
        XCTAssertFalse(reopened.link.asking)
        reopened.host.keep("r2")
        reopened.link.enteredBackground()
        await reopened.idle()
        XCTAssertEqual(stage.text(month), before)
        XCTAssertEqual(reopened.host.ids, ["r1", "r2"])
        XCTAssertNotNil(stage.text("\(reopened.device)/2026-11.json"))
        // 還是同一個 iCloud 的帳本：換帳號照樣問
        reopened.drive.account = "someone"
        await reopened.wakeUp()
        XCTAssertEqual(reopened.link.question, .account)
    }
}
