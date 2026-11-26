import Foundation

/// 上次讀過的別台的檔：沒改過的下一趟不再讀、不再解析，直接拿上次讀出來的那一份。
/// 只放記憶體，不寫檔：App 重開、關掉同步、換帳號都從頭全讀。
struct CloudCopies {
    /// 讀到時清單上的修改時間與大小，和讀出來的那一份（讀不懂、跳過的是 nil）
    struct Copy {
        var changedAt: Date
        var size: Int
        var piece: SyncFiles.Remote?
    }

    /// 這些是哪個 iCloud、這台當時是哪個編號讀的：哪個不一樣就整份不算
    private var identity: String?
    private var device: String?
    private(set) var files: [String: Copy] = [:]

    /// 這一趟拉之前先對：拿不準就全部忘掉、這趟整份重讀。
    /// 拿不準是：換了帳號或編號、有下載好的檔沒有修改時間或大小、修改時間比上次讀的還早。
    /// 清單上沒有的檔（被刪了）一起忘掉。
    mutating func check(_ others: [CloudFile], identity: String, device: String) {
        let isSure = identity == self.identity && device == self.device
            && others.filter(\.isReady).allSatisfy { file in
                guard let changedAt = file.changedAt, file.size != nil else { return false }
                return files[file.path].map { changedAt >= $0.changedAt } ?? true
            }
        guard isSure else {
            self.identity = identity
            self.device = device
            files = [:]
            return
        }
        let listed = Set(others.map(\.path))
        files = files.filter { listed.contains($0.key) }
    }

    /// 修改時間與大小都跟上次讀的一樣，才拿上次那一份。
    func same(_ file: CloudFile) -> Copy? {
        guard let copy = files[file.path], file.changedAt == copy.changedAt,
              file.size == copy.size else { return nil }
        return copy
    }

    mutating func add(_ fresh: [String: Copy]) {
        files.merge(fresh) { _, new in new }
    }
}
