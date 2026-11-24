import Foundation

/// 真的 iCloud：容器裡 Documents 以外的 Records 資料夾（不會出現在「檔案」app）。
/// 建立時什麼都不碰；會卡住的呼叫全部排在 CloudLine 上，主執行緒不會等它。
final class ICloudDrive: CloudDrive {
    static let container = "iCloud.org.domyweb.douzhang"
    static let folder = "Records"

    private let line = CloudLine()
    private let catalog: CloudCatalog

    @MainActor
    init() {
        catalog = CloudCatalog()
    }

    func identity() async throws -> String? {
        try await identity(like: nil)
    }

    func identity(like known: String?) async throws -> String? {
        try await line.run(Params.cloudStepSeconds) { _ -> String? in
            let manager = FileManager.default
            let home = manager.url(forUbiquityContainerIdentifier: ICloudDrive.container)
            guard home != nil else { return nil }
            return try ICloudDrive.code(like: known)
        }
    }

    /// 系統的清單（含還沒下載的）加上手機裡真的有的。只看清單的話，剛寫的檔還沒列進去，
    /// 會以為不見了又重寫一次，甚至以為整個雲端被清空。
    func files() async throws -> [CloudFile] {
        let catalog = catalog
        let listed = try await TimeLimit.run(Params.cloudListSeconds) {
            try await catalog.listed()
        }
        return try await line.run(Params.cloudStepSeconds) { _ -> [CloudFile] in
            let here = try ICloudDrive.onDisk(ICloudDrive.root())
            let known = Set(here.map(\.path))
            let rest = listed.filter { !known.contains($0.path) }
            return (here + rest).sorted { $0.path < $1.path }
        }
    }

    func download(_ path: String) async {
        // 只是拜託系統下載：叫不動就算了，下次拉還會再叫
        try? await line.run(Params.cloudStepSeconds) { _ in
            let url = try ICloudDrive.place(path)
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }

    func read(_ path: String, for identity: String) async throws -> Data {
        try await line.run(Params.cloudStepSeconds) { ticket -> Data in
            let url = try ICloudDrive.place(path)
            guard ICloudDrive.isReady(url) else {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                throw CloudError.notReady
            }
            return try CloudAccess.read(url, ticket) { try ICloudDrive.check(identity) }
        }
    }

    func prepare(_ device: String, for identity: String) async throws {
        try await line.run(Params.cloudStepSeconds) { ticket in
            let tags = try ICloudDrive.place(CloudLedger.tagsPath(device))
            let home = tags.deletingLastPathComponent()
            try CloudAccess.makeFolder(home, ticket) { try ICloudDrive.check(identity) }
        }
    }

    func write(_ path: String, _ data: Data, for identity: String) async throws {
        try await line.run(Params.cloudStepSeconds) { ticket in
            let url = try ICloudDrive.place(path)
            try CloudAccess.write(data, to: url, ticket) { try ICloudDrive.check(identity) }
        }
    }

    /// 這支手機上還沒有那個資料夾、系統的清單卻有東西：刪了也是白刪，之後又會下來，當沒刪成。
    /// 帳號先比：別的帳號那裡本來就是空的，不能當成刪好了。
    func erase(for identity: String) async throws {
        guard let now = try await self.identity(like: identity) else { throw CloudError.off }
        guard now == identity else { throw CloudError.otherAccount }
        let listed = try await glance()
        try await line.run(Params.cloudStepSeconds) { ticket in
            let root = try ICloudDrive.root()
            try ICloudDrive.check(identity)
            guard FileManager.default.fileExists(atPath: root.path) else {
                if listed.isEmpty {
                    return
                }
                throw CloudError.notReady
            }
            try CloudAccess.erase(root, ticket) { try ICloudDrive.check(identity) }
        }
    }

    /// 逾時也要收：不然查詢沒人聽地一直跑。
    private func glance() async throws -> [CloudFile] {
        let catalog = catalog
        do {
            return try await TimeLimit.run(Params.cloudListSeconds) {
                try await catalog.glance()
            }
        } catch {
            await catalog.endGlance()
            throw error
        }
    }

    @MainActor
    func watch(_ onNotice: @escaping @MainActor (CloudNotice) -> Void) {
        catalog.watch(onNotice)
    }

    @MainActor
    func unwatch() {
        catalog.unwatch()
    }
}

// MARK: 只准在 CloudLine 上叫的

private extension ICloudDrive {
    static func root() throws -> URL {
        let manager = FileManager.default
        guard let home = manager.url(forUbiquityContainerIdentifier: container) else {
            throw CloudError.off
        }
        return home.appendingPathComponent(folder, isDirectory: true)
    }

    /// 外來的字不當路徑用：同步不認得的一律不碰（CWE-22）。
    static func place(_ path: String) throws -> URL {
        guard SyncFiles.locate(path) != nil else { throw CloudError.badPath }
        return try root().appendingPathComponent(path)
    }

    /// 現在登入的 iCloud 的代號；沒登入是 nil。
    static func code(like known: String?) throws -> String? {
        guard let token = FileManager.default.ubiquityIdentityToken else { return nil }
        return try CloudToken.code(token, like: known)
    }

    /// 動手那一刻再看一次帳號：做到一半換了 Apple ID，不准把這個人的寫進那個人的。
    static func check(_ identity: String) throws {
        guard let now = try code(like: identity) else { throw CloudError.off }
        guard now == identity else { throw CloudError.otherAccount }
    }

    /// 最新的那一版在不在手機上。讀不到屬性的當不在；屬性讀得到但沒有這個值，
    /// 是不歸 iCloud 管的檔，讀它無害。
    static func isReady(_ url: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.ubiquitousItemDownloadingStatusKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return false }
        let status = values.ubiquitousItemDownloadingStatus
        return status == nil || status == .current
    }

    static func onDisk(_ root: URL) -> [CloudFile] {
        let manager = FileManager.default
        var found: [CloudFile] = []
        for device in (try? manager.contentsOfDirectory(atPath: root.path)) ?? [] {
            let home = root.appendingPathComponent(device)
            for name in (try? manager.contentsOfDirectory(atPath: home.path)) ?? [] {
                let path = "\(device)/\(name)"
                guard SyncFiles.locate(path) != nil else { continue }
                let isHere = isReady(home.appendingPathComponent(name))
                found.append(CloudFile(path: path, isReady: isHere))
            }
        }
        return found
    }
}
