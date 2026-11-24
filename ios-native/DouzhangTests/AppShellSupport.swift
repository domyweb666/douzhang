@testable import Douzhang
import XCTest

/// 殼＋它的接頭。存檔、自動備份、雲端都在這個測試自己的資料夾。
@MainActor
struct AppShell {
    static let name = "app"

    let model: AppModel
    let phone: TestPhone
    let home: URL
    let backups: URL
    let running: Task<Void, Never>

    /// 先擺好存檔再打開，跟真的開 app 走同一條路。
    static func open(
        _ stage: CloudStage,
        _ state: AppState? = nil,
        home: URL? = nil,
        backups: URL? = nil
    ) async throws -> AppShell {
        let home = home ?? stage.root.appendingPathComponent(name)
        let backups = backups ?? home.appendingPathComponent("backups")
        let file = StateFile(folder: home)
        if let state {
            XCTAssertTrue(file.save(state))
        }
        let phone = try stage.phone(name)
        let model = AppModel(
            file: file,
            backups: BackupFiles(folder: backups),
            cloud: phone.link
        )
        let running = Task { await model.run() }
        await CloudStage.until("讀完檔") { model.loaded }
        return AppShell(
            model: model,
            phone: phone,
            home: home,
            backups: backups,
            running: running
        )
    }

    /// 買了、打開同步，等它靜下來。
    func turnOn() async {
        phone.link.setPaid(true)
        phone.link.turnOn()
        await phone.idle()
    }

    func close() {
        running.cancel()
    }

    /// 存進檔裡的番茄。
    var ids: [String] {
        let saved = StateFile(folder: home).load().state
        return SyncSample.beans(saved).map(\.id).sorted()
    }
}

extension CloudStage {
    /// 只有一顆的一份狀態。
    static func holding(_ bean: String) -> AppState {
        SyncSample.state(day, SyncSample.bean(bean, at: base))
    }

    /// 別台先放一顆上去。
    func seedCloud(_ bean: String) async throws {
        let other = try phone("other-\(bean)", bean: bean)
        await other.turnOn()
    }

    /// 一個檔佔住那個位置：底下建不了資料夾，寫什麼都不成。
    func blockedFolder() throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("not-a-folder")
        try "x".write(to: url, atomically: true, encoding: .utf8)
        return url.appendingPathComponent("inside")
    }
}
