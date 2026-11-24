@testable import Douzhang
import XCTest

/// iCloud 接頭什麼時候傳、拉與傳會不會打架。
@MainActor
final class CloudTimingTests: XCTestCase {
    // MARK: 什麼時候傳

    func test第一次拉完之前不傳() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        phone.drive.isBroken = true
        await phone.turnOn()
        phone.host.keep("r2")
        phone.link.enteredBackground()
        await CloudStage.moment()
        XCTAssertTrue(phone.drive.written.isEmpty)

        phone.drive.isBroken = false
        await phone.wakeUp()
        XCTAssertFalse(phone.drive.written.isEmpty)
    }

    func test存檔後停手一下才傳一次() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        let before = phone.drive.written.count
        phone.host.keep("r2")
        phone.host.keep("r3")
        await CloudStage.until("傳上去") { phone.drive.written.count > before }
        await CloudStage.moment()
        XCTAssertEqual(phone.drive.written.count, before + 1)
    }

    func test進背景馬上傳() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        phone.host.keep("r2")
        phone.link.enteredBackground()
        await phone.idle()
        let text = stage.text("\(phone.device)/2026-11.json") ?? ""
        XCTAssertTrue(text.contains(#""r2""#))
    }

    func test內容一樣不重寫檔不見了就補寫() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        let before = phone.drive.written.count
        await phone.wakeUp()
        XCTAssertEqual(phone.drive.written.count, before)

        let month = "\(phone.device)/2026-11.json"
        try FileManager.default.removeItem(at: stage.cloud.appendingPathComponent(month))
        await phone.wakeUp()
        XCTAssertEqual(phone.drive.written.count, before + 1)
        XCTAssertNotNil(stage.text(month))
    }

    func test打草稿不傳() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        await phone.turnOn()
        let before = phone.drive.calls
        var next = phone.host.state
        next.doing = "寫企劃"
        phone.host.commit(next)
        await CloudStage.moment()
        XCTAssertEqual(phone.drive.calls, before)
    }

    func test本機讀不懂或存失敗不拉也不傳() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let phone = try stage.phone("a", bean: "r1")
        phone.host.isHealthy = false
        await phone.turnOn()
        XCTAssertEqual(phone.drive.calls, 0)

        phone.host.isHealthy = true
        await phone.wakeUp()
        let before = phone.drive.calls
        phone.host.isHealthy = false
        phone.host.keep("r2")
        phone.link.becameActive()
        await CloudStage.moment()
        XCTAssertEqual(phone.drive.calls, before)
    }

    func test本機好了存檔就自己補拉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        await one.turnOn()
        let two = try stage.phone("b")
        two.host.isHealthy = false
        await two.turnOn()
        two.host.keep("r2")
        await two.idle()
        XCTAssertEqual(two.drive.calls, 0)

        two.host.isHealthy = true
        two.host.keep("r3")
        await two.idle()
        XCTAssertEqual(two.host.ids, ["r1", "r2", "r3"])
        XCTAssertFalse(two.drive.written.isEmpty)
    }

    func test一趟沒讀完的接著讀完不用等下次回前景() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        for name in ["r1", "r2", "r3"] {
            let other = try stage.phone("other-\(name)")
            other.host.keep(name)
            await other.turnOn()
        }
        // 一趟只來得及讀一個檔
        let phone = try stage.phone("a", pull: 0)
        await phone.turnOn()
        await CloudStage.until("讀完") { phone.host.ids == ["r1", "r2", "r3"] }
        await CloudStage.until("不再接著讀") { phone.link.unread == nil }
        await phone.idle()
        // 每個檔各讀一次，沒有從頭重讀
        XCTAssertEqual(phone.drive.reads.count, Set(phone.drive.reads).count)
    }

    // MARK: 不打架

    func test拉的時候本機又收了一顆不會丟() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        await one.turnOn()
        let two = try stage.phone("b", bean: "r2")
        two.drive.readPause = 0.2
        two.link.start(two.host)
        two.link.setPaid(true)
        two.link.turnOn()
        await CloudStage.until("開始拉") { two.drive.calls > 2 }
        two.host.keep("r3")
        await two.idle()
        XCTAssertEqual(two.host.ids, ["r1", "r2", "r3"])
    }

    func test進行中那顆與下一顆要做的事不受同步影響() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        await one.turnOn()
        let two = try stage.phone("b")
        var busy = Machine.start(two.host.state, now: CloudStage.base)
        busy.doing = "寫企劃"
        two.host.state = busy
        await two.turnOn()
        XCTAssertEqual(two.host.ids, ["r1"])
        XCTAssertEqual(two.host.state.current, busy.current)
        XCTAssertEqual(two.host.state.doing, "寫企劃")
    }

    func test拉與傳不會同時() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let one = try stage.phone("a", bean: "r1")
        await one.turnOn()
        let two = try stage.phone("b", bean: "r2")
        two.drive.readPause = 0.03
        two.drive.writePause = 0.03
        await two.turnOn()
        for round in 0 ..< 5 {
            two.host.keep("x\(round)")
            two.link.enteredBackground()
            two.link.becameActive()
            two.link.requestPush()
            try await Task.sleep(for: .milliseconds(20))
        }
        await two.idle()
        XCTAssertEqual(two.drive.busiest, 1)
    }
}
