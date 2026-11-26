@testable import Douzhang
import XCTest

/// app 的殼接上同步：真的 AppModel、真的存檔，iCloud 用本機資料夾扮（不碰真的 iCloud）。
/// 接頭自己的時機在 CloudLinkTests，這裡只測殼這一邊。
/// 叫的是真的 wipeAll：會動測試宿主的 UserDefaults.standard（外觀、觸覺、選過的 app）與擋板，
/// 之後哪個測試要讀這幾個，先自己擺好。
@MainActor
final class AppModelCloudTests: XCTestCase {
    // MARK: 合進來

    func test合進來的存進檔進行中那顆不動() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        try await stage.seedCloud("r1")
        let mine = Machine.start(CloudStage.holding("r2"), now: TimeText.nowMillis())
        let shell = try await AppShell.open(stage, mine)
        defer { shell.close() }
        let run = shell.model.state.current
        await shell.turnOn()
        XCTAssertEqual(shell.ids, ["r1", "r2"])
        XCTAssertEqual(SyncSample.beans(shell.model.state).count, 2)
        XCTAssertNotNil(run)
        XCTAssertEqual(shell.model.state.current, run)
        XCTAssertEqual(shell.model.pulses, Pulses())
    }

    func test第一次同步前自動備份的是原本那份() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        try await stage.seedCloud("r1")
        let shell = try await AppShell.open(stage, CloudStage.holding("r2"))
        defer { shell.close() }
        XCTAssertNil(shell.model.lastBackup)
        await shell.turnOn()
        XCTAssertNotNil(shell.model.lastBackup)
        XCTAssertNil(shell.model.backupProblem)
        let folder = shell.backups
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        let name = try XCTUnwrap(names.first)
        let backup = try BackupFiles.readImport(folder.appendingPathComponent(name)).get()
        XCTAssertEqual(SyncSample.beans(backup).map(\.id), ["r2"])
    }

    func test備份不成不合不傳也不寫匯入那句() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        try await stage.seedCloud("r1")
        let shell = try await AppShell.open(
            stage,
            CloudStage.holding("r2"),
            backups: stage.blockedFolder()
        )
        defer { shell.close() }
        await shell.turnOn()
        XCTAssertEqual(shell.ids, ["r2"])
        XCTAssertTrue(shell.phone.drive.written.isEmpty)
        XCTAssertEqual(shell.phone.link.problem, .backupFailed)
        XCTAssertNil(shell.model.backupProblem)
    }

    // MARK: 不准合也不准傳

    func test本機檔讀不懂不合不傳也不動那個檔() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        try await stage.seedCloud("r1")
        let home = stage.root.appendingPathComponent(AppShell.name)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let url = home.appendingPathComponent(StateFile.fileName)
        try "{讀不懂".write(to: url, atomically: true, encoding: .utf8)

        let shell = try await AppShell.open(stage)
        defer { shell.close() }
        XCTAssertTrue(shell.model.unreadable)
        await shell.turnOn()
        shell.model.becameActive()
        await shell.phone.idle()
        XCTAssertNil(shell.model.cloudState)
        XCTAssertEqual(shell.phone.drive.calls, 0)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "{讀不懂")
    }

    func test沒存進去不合不傳() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, home: stage.blockedFolder())
        defer { shell.close() }
        shell.model.setDoing("寫第三節")
        // 存檔在背景寫：寫完才知道存不進去
        await CloudStage.until("存不進去") { shell.model.saveFailed }
        await shell.turnOn()
        XCTAssertNil(shell.model.cloudState)
        XCTAssertEqual(shell.phone.drive.calls, 0)
    }

    // MARK: 什麼時候

    func test存檔之後自己傳() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        await shell.turnOn()
        let before = shell.phone.drive.written.count
        _ = shell.model.addType()
        let tags = "\(shell.phone.device)/tags.json"
        await CloudStage.until("傳新標籤") {
            shell.phone.drive.written.dropFirst(before).contains(tags)
        }
    }

    func test回到前景就拉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        await shell.turnOn()
        try await stage.seedCloud("r2")
        shell.model.becameActive()
        await shell.phone.idle()
        XCTAssertEqual(shell.ids, ["r1", "r2"])
    }

    // MARK: 清除所有資料

    func test清除時留著雲端那份這台清空關同步也不傳空的上去() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        await shell.turnOn()
        let month = "\(shell.phone.device)/2026-11.json"
        let before = try XCTUnwrap(stage.text(month))

        shell.model.wipeAll(erasingCloud: false)
        // 當場就關：清空那一次存檔不會被當成要傳的
        XCTAssertFalse(shell.phone.link.isOn)
        XCTAssertNil(shell.phone.ledgerFile.load())
        shell.model.becameActive()
        await CloudStage.moment()
        XCTAssertEqual(shell.ids, [])
        XCTAssertEqual(stage.text(month), before)
        XCTAssertFalse(shell.model.cloud.hasCopy)
    }

    func test清除時選了也刪掉雲端就沒有了而且不會寫回來() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        await shell.turnOn()
        shell.model.wipeAll(erasingCloud: true)
        XCTAssertFalse(shell.phone.link.isOn)
        let cloud = stage.cloud.path
        await CloudStage.until("刪掉雲端") { !FileManager.default.fileExists(atPath: cloud) }
        await CloudStage.moment()
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloud))
        XCTAssertEqual(shell.ids, [])
    }

    func test正在傳的時候清除不會又寫回來() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        shell.phone.drive.writePause = 0.2
        shell.phone.link.setPaid(true)
        shell.phone.link.turnOn()
        await CloudStage.until("正在寫") { shell.phone.drive.calls > 4 }
        shell.model.wipeAll(erasingCloud: true)
        await shell.phone.idle()
        await CloudStage.moment()
        XCTAssertFalse(FileManager.default.fileExists(atPath: stage.cloud.path))
        XCTAssertNil(shell.phone.ledgerFile.load())
        XCTAssertEqual(shell.ids, [])
    }

    func test清除時雲端可能有一份才問退款也問() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        let cloudLink = shell.model.cloud
        XCTAssertFalse(cloudLink.hasCopy)
        // 打開過但沒登入 iCloud：那裡沒有這台的東西
        shell.phone.drive.account = nil
        await shell.turnOn()
        cloudLink.turnOff()
        XCTAssertFalse(cloudLink.hasCopy)
        shell.phone.drive.account = "me"
        await shell.turnOn()
        // 關掉、退款都還在雲端
        cloudLink.turnOff()
        cloudLink.setPaid(false)
        XCTAssertTrue(cloudLink.hasCopy)
        shell.model.wipeAll(erasingCloud: true)
        let cloud = stage.cloud.path
        await CloudStage.until("刪掉雲端") { !FileManager.default.fileExists(atPath: cloud) }
        await CloudStage.until("不用再刪了") { !cloudLink.hasCopy }
    }

    func test開著但沒放過東西清除也關同步不碰雲端() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        try await stage.seedCloud("r9")
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        shell.phone.drive.account = nil
        await shell.turnOn()
        shell.phone.drive.account = "me"
        let before = shell.phone.drive.calls
        shell.model.wipeAll(erasingCloud: true)
        XCTAssertFalse(shell.phone.link.isOn)
        await shell.phone.idle()
        XCTAssertEqual(shell.phone.drive.calls, before)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stage.cloud.path))
    }

    func test沒開過同步清除不碰雲端() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        try await stage.seedCloud("r9")
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        shell.model.wipeAll(erasingCloud: true)
        await CloudStage.moment()
        XCTAssertEqual(shell.phone.drive.calls, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stage.cloud.path))
        XCTAssertEqual(shell.ids, [])
    }
}
