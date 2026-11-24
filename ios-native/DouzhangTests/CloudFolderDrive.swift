@testable import Douzhang
import XCTest

/// 一個普通的本機資料夾扮 iCloud。兩支手機各拿一個，指同一個資料夾。
@MainActor
final class FolderDrive: CloudDrive {
    let root: URL
    /// 登入的是哪個 iCloud；nil 是沒登入
    var account: String? = "me"
    /// 同一個帳號，每次從頭問到的代號寫法都不一樣（真的 token 沒保證一樣）
    var isRestless = false
    /// 還沒下載到這支手機的
    var pending: Set<String> = []
    /// 清單列不出來
    var isBroken = false
    /// 每次讀、寫之前卡多久
    var readPause = 0.0
    var writePause = 0.0
    /// 剛列完清單、正要寫下去的那一刻發生的事
    var onList: (@MainActor () -> Void)?
    var onWrite: (@MainActor () -> Void)?
    private(set) var asked: [String] = []
    private(set) var written: [String] = []
    private(set) var reads: [String] = []
    /// 開資料夾不算
    private(set) var calls = 0
    /// 最多同時有幾件事在做
    private(set) var busiest = 0
    private var running = 0
    private var spellings = 0
    private var onNotice: (@MainActor (CloudNotice) -> Void)?

    init(root: URL) {
        self.root = root
    }

    private func enter() {
        calls += 1
        running += 1
        busiest = max(busiest, running)
    }

    private func leave() {
        running -= 1
    }

    private func rest(_ seconds: Double) async {
        if seconds > 0 {
            try? await Task.sleep(for: .seconds(seconds))
        }
    }

    private func check(_ identity: String) throws {
        guard let account else { throw CloudError.off }
        guard account == FolderDrive.owner(identity) else { throw CloudError.otherAccount }
    }

    /// 代號是「帳號」或「帳號#第幾種寫法」。
    private static func owner(_ code: String) -> String {
        String(code.prefix { $0 != "#" })
    }

    // MARK: CloudDrive

    func identity() async throws -> String? {
        try await identity(like: nil)
    }

    func identity(like known: String?) async throws -> String? {
        enter()
        defer { leave() }
        if !isRestless {
            return account
        }
        guard let account else { return nil }
        if let known, FolderDrive.owner(known) == account {
            return known
        }
        spellings += 1
        return "\(account)#\(spellings)"
    }

    func files() async throws -> [CloudFile] {
        enter()
        defer { leave() }
        if isBroken {
            throw CloudError.stopped
        }
        let found = listing()
        onList?()
        return found
    }

    func download(_ path: String) async {
        enter()
        defer { leave() }
        asked.append(path)
    }

    func read(_ path: String, for identity: String) async throws -> Data {
        enter()
        defer { leave() }
        try check(identity)
        await rest(readPause)
        reads.append(path)
        return try Data(contentsOf: root.appendingPathComponent(path))
    }

    func prepare(_ device: String, for identity: String) async throws {
        try check(identity)
        let home = root.appendingPathComponent(device)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    /// 資料夾不在就寫不進去，跟真的一樣不自己開。
    func write(_ path: String, _ data: Data, for identity: String) async throws {
        enter()
        defer { leave() }
        try check(identity)
        await rest(writePause)
        onWrite?()
        try data.write(to: root.appendingPathComponent(path), options: .atomic)
        written.append(path)
    }

    /// 帳號先比，跟真的一樣：別的帳號那裡是空的也不算刪成。
    func erase(for identity: String) async throws {
        enter()
        defer { leave() }
        try check(identity)
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    func watch(_ onNotice: @escaping @MainActor (CloudNotice) -> Void) {
        self.onNotice = onNotice
    }

    func unwatch() {
        onNotice = nil
    }

    // MARK: 測試用

    /// 系統說清單變了。
    func tell() {
        onNotice?(.files(listing()))
    }

    /// 那個資料夾裡認得的檔。
    static func paths(in root: URL) -> [String] {
        let all = FileManager.default.enumerator(atPath: root.path)?.allObjects ?? []
        return all.compactMap { $0 as? String }
            .filter { SyncFiles.locate($0) != nil }
            .sorted()
    }

    private func listing() -> [CloudFile] {
        FolderDrive.paths(in: root)
            .map { CloudFile(path: $0, isReady: !pending.contains($0)) }
    }
}
