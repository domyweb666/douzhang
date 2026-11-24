@testable import Douzhang
import XCTest

/// 假的 AppModel：只有狀態與備份。
@MainActor
final class FakeHost: CloudHost {
    var state: AppState
    /// 檔讀完了、讀得懂、存得進去
    var isHealthy = true
    var canBackUp = true
    private(set) var backups = 0
    weak var link: CloudLink?

    init(_ state: AppState) {
        self.state = state
    }

    var cloudState: AppState? {
        isHealthy ? state : nil
    }

    func takeCloud(_ merged: AppState) {
        commit(merged)
    }

    func backUpForCloud() -> Bool {
        backups += 1
        return canBackUp
    }

    func commit(_ next: AppState) {
        state = next
        link?.saved()
    }

    /// 在這台收下一顆。
    func keep(_ id: String, on key: String = CloudStage.day) {
        var next = state
        let bean = SyncSample.bean(id, at: CloudStage.base)
        next.days[key, default: DayRecord()].beans.append(bean)
        commit(next)
    }

    var ids: [String] {
        SyncSample.beans(state).map(\.id).sorted()
    }
}

/// 一支手機：一份狀態、一個接頭、一個通往同一個雲端資料夾的門。
@MainActor
struct TestPhone {
    let host: FakeHost
    let drive: FolderDrive
    let link: CloudLink
    let ledgerFile: CloudLedgerFile

    var device: String {
        link.ledger?.device ?? ""
    }

    /// 買了、打開同步，等它靜下來。
    func turnOn() async {
        link.start(host)
        link.setPaid(true)
        link.turnOn()
        await idle()
    }

    /// 關掉再打開 app：開關照上次，不是親手打開的。
    func open() async {
        link.start(host)
        link.setPaid(true)
        await idle()
    }

    func wakeUp() async {
        link.becameActive()
        await idle()
    }

    /// 當作隔夠久了，再看一次雲端還空不空。不走回前景那條：回前景會從頭算。
    func lookAgain() async {
        link.emptySince = ContinuousClock.now - .seconds(link.waits.empty)
        link.requestPull()
        await idle()
    }

    /// 手上的事都做完。
    func idle() async {
        await CloudStage.until("靜下來") { link.worker == nil && !link.isErasing }
    }
}

/// 一個測試的場地：雲端資料夾與每支手機自己的資料夾，用完整個刪掉。
@MainActor
final class CloudStage {
    nonisolated static let day = "2026-11-24"
    nonisolated static let base = Moment.local(2026, 11, 24, 9)

    let root: URL
    private var suites: [String] = []

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudStage-\(UUID().uuidString)")
    }

    var cloud: URL {
        root.appendingPathComponent("Records")
    }

    var hasCloud: Bool {
        FileManager.default.fileExists(atPath: cloud.path)
    }

    /// 一支手機。同一個 name 再要一次就是「關掉再打開」。empty 是雲端空了隔多久再看，
    /// pull 是一趟拉多久，vendor 是怎麼問「這是哪支手機」。
    func phone(
        _ name: String,
        bean: String? = nil,
        empty: Double = 0.1,
        pull: Double = Params.cloudPullSeconds,
        vendor: (() -> String?)? = nil
    ) throws -> TestPhone {
        let suite = "\(root.lastPathComponent)-\(name)"
        suites.append(suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let file = CloudLedgerFile(
            folder: root.appendingPathComponent(name),
            phone: vendor ?? { name }
        )
        let drive = FolderDrive(root: cloud)
        let waits = CloudWaits(push: 0.05, notice: 0.05, off: 0.2, empty: empty, pull: pull)
        let link = CloudLink(drive: drive, ledgerFile: file, defaults: defaults, waits: waits)
        let host = FakeHost(Store.blank())
        host.link = link
        if let bean {
            host.keep(bean)
        }
        return TestPhone(host: host, drive: drive, link: link, ledgerFile: file)
    }

    func put(_ text: String, at path: String) throws {
        let url = cloud.appendingPathComponent(path)
        let home = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func text(_ path: String) -> String? {
        try? String(contentsOf: cloud.appendingPathComponent(path), encoding: .utf8)
    }

    /// 帳本讀不到、又讀得到。
    func lockLedger(_ phone: TestPhone, _ isLocked: Bool) throws {
        let url = phone.ledgerFile.folder.appendingPathComponent(CloudLedgerFile.fileName)
        let mode = isLocked ? 0o000 : 0o644
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: url.path)
    }

    func clean() {
        try? FileManager.default.removeItem(at: root)
        for suite in suites {
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
    }

    /// 等到成立，最多五秒。讓出主執行緒，接頭從背景回來的事才輪得到。
    static func until(_ what: String, _ isDone: () -> Bool) async {
        let end = ContinuousClock.now + .seconds(5)
        while !isDone() {
            if ContinuousClock.now > end {
                XCTFail("等不到：\(what)")
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// 等夠久，確定那件事沒有發生。
    static func moment() async {
        try? await Task.sleep(for: .milliseconds(300))
    }
}

extension CloudLedgerFile {
    /// 讀不到的也當沒有：測試只想知道有沒有存成。
    func load() -> CloudLedger? {
        try? read()
    }
}

/// 發生過哪些事，照先後，跨執行緒記的。
final class CloudDiary: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    func add(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.unlock()
    }

    var all: [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }
}
