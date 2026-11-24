import Foundation

/// 雲端有哪些檔、下載好了沒（NSMetadataQuery）。查詢只在主執行緒開關與讀，
/// 交出去的是自己的 CloudFile，系統的物件不離開這裡。
@MainActor
final class CloudCatalog {
    /// 路徑最後三段：Records／編號／檔名
    private static let tailParts = 3

    private var onNotice: (@MainActor (CloudNotice) -> Void)?
    /// 有人在聽才准開查詢：關掉同步之後才輪到的那一趟，不准又把它開起來
    private(set) var isWatched = false
    private var query: NSMetadataQuery?
    /// 第幾次查詢。停掉之後才送到的舊通知對不上號，不理
    private var round = 0
    private var observers: [NSObjectProtocol] = []
    private var files: [CloudFile] = []
    private var isGathered = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func watch(_ onNotice: @escaping @MainActor (CloudNotice) -> Void) {
        self.onNotice = onNotice
        isWatched = true
    }

    func unwatch() {
        onNotice = nil
        isWatched = false
        stop()
    }

    /// 看一眼就收（刪雲端之前）。
    func glance() async throws -> [CloudFile] {
        isWatched = true
        defer { endGlance() }
        return try await listed()
    }

    /// 有人在聽就不收：逾時被丟下的那一眼晚點才醒，那時同步可能又打開了，查詢是它在用。
    func endGlance() {
        if onNotice == nil {
            unwatch()
        }
    }

    /// 第一份清單收齊才回。一直收不齊由叫的人設時限。
    func listed() async throws -> [CloudFile] {
        guard isWatched else { throw CloudError.stopped }
        start()
        if query != nil, !isGathered {
            await withCheckedContinuation { waiting.append($0) }
        }
        guard isGathered else { throw CloudError.stopped }
        return files
    }

    private func stop() {
        round += 1
        query?.stop()
        query = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
        files = []
        isGathered = false
        wake()
    }

    private func start() {
        guard query == nil else { return }
        let fresh = NSMetadataQuery()
        // Documents 以外的那一半
        fresh.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        fresh.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*.json")
        query = fresh
        listen(.NSMetadataQueryDidFinishGathering, from: fresh) { $0.gathered() }
        listen(.NSMetadataQueryDidUpdate, from: fresh) { $0.updated() }
        listen(.NSUbiquityIdentityDidChange, from: nil) { $0.accountChanged() }
        if !fresh.start() {
            stop()
        }
    }

    private func listen(
        _ name: Notification.Name,
        from source: NSMetadataQuery?,
        _ act: @escaping @MainActor @Sendable (CloudCatalog) -> Void
    ) {
        let mine = round
        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: source,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.hear(mine, act)
            }
        }
        observers.append(observer)
    }

    private func hear(_ source: Int, _ act: @MainActor (CloudCatalog) -> Void) {
        if source == round {
            act(self)
        }
    }

    private func gathered() {
        files = collect()
        isGathered = true
        wake()
        onNotice?(.gathered)
    }

    private func updated() {
        let next = collect()
        guard isGathered, next != files else { return }
        files = next
        onNotice?(.files(next))
    }

    /// 換帳號後舊的清單不算數，下次要用時重新查。
    private func accountChanged() {
        stop()
        onNotice?(.account)
    }

    private func wake() {
        let sleepers = waiting
        waiting = []
        for sleeper in sleepers {
            sleeper.resume()
        }
    }

    private func collect() -> [CloudFile] {
        guard let query else { return [] }
        query.disableUpdates()
        defer { query.enableUpdates() }
        let items = (0 ..< query.resultCount).compactMap { index in
            query.result(at: index) as? NSMetadataItem
        }
        return items.compactMap { CloudCatalog.file($0) }.sorted { $0.path < $1.path }
    }

    private static func file(_ item: NSMetadataItem) -> CloudFile? {
        guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { return nil }
        let tail = url.pathComponents.suffix(tailParts)
        let path = tail.dropFirst().joined(separator: "/")
        guard tail.count == tailParts, tail.first == ICloudDrive.folder,
              SyncFiles.locate(path) != nil else { return nil }
        let key = NSMetadataUbiquitousItemDownloadingStatusKey
        let status = item.value(forAttribute: key) as? String
        return CloudFile(
            path: path,
            isReady: status == NSMetadataUbiquitousItemDownloadingStatusCurrent,
            changedAt: item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
        )
    }
}
