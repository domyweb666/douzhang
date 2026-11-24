import CryptoKit
import Foundation

/// 搬檔案時會遇到的幾種不行。只給程式分辨用，不印給人看。
enum CloudError: Error {
    /// 不是同步認得的路徑
    case badPath
    /// 沒登入 iCloud，或雲碟沒開
    case off
    /// 還沒下載到這支手機（已經請系統下載）
    case notReady
    case tooBig
    /// 做到一半 Apple 帳號換了
    case otherAccount
    /// 逾時或關掉，沒有做完
    case stopped
}

/// 雲端的一個檔。path 是「編號／檔名」（SyncFiles.locate 認得的才會出現在這裡）。
struct CloudFile: Equatable {
    var path: String
    /// 最新的那一版已經在這支手機上
    var isReady: Bool
    var changedAt: Date?
}

/// 雲端自己傳來的動靜。
enum CloudNotice {
    /// 第一份清單收齊了
    case gathered
    case files([CloudFile])
    /// Apple 帳號換了、登出、雲碟開關動了
    case account
}

/// 放同步檔案的地方：真的 iCloud（ICloudDrive），測試用本機資料夾扮。
/// 只搬檔案，合併規則在 Core/Sync*，什麼時候搬由 CloudLink 決定。每一步都要有時限。
/// identity 是「做這一步的前提」：跟現在登入的不是同一個就丟 otherAccount，不准做。
protocol CloudDrive: Sendable {
    /// 現在這個 iCloud 的代號；沒登入或雲碟沒開是 nil
    func identity() async throws -> String?
    /// 同上，跟 known 是同一個帳號就回 known 原本那個字：代號只准拿這樣問到的來比
    func identity(like known: String?) async throws -> String?
    /// 所有認得的檔，含還沒下載到這支手機的
    func files() async throws -> [CloudFile]
    /// 請系統下載。只是拜託，不等它好
    func download(_ path: String) async
    func read(_ path: String, for identity: String) async throws -> Data
    /// 第一次傳之前開好這台的資料夾
    func prepare(_ device: String, for identity: String) async throws
    /// 資料夾不在就丟錯，不自己開：傳到一半被別台刪掉，不准又把它建回來
    func write(_ path: String, _ data: Data, for identity: String) async throws
    /// 刪掉整個資料夾（每一台的都刪）。不知道是哪個帳號的不准叫
    func erase(for identity: String) async throws
    @MainActor func watch(_ onNotice: @escaping @MainActor (CloudNotice) -> Void)
    @MainActor func unwatch()
}

/// 代號不用換寫法、不用開資料夾的（不接 iCloud 的那種）不必自己寫。
extension CloudDrive {
    func identity(like _: String?) async throws -> String? {
        try await identity()
    }

    func prepare(_: String, for _: String) async throws {}
}

enum CloudHash {
    static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// 會同步卡住執行緒的檔案呼叫（NSFileCoordinator、找容器、讀雲端檔）都排到這一條自己的佇列：
/// 直接跑在 Swift 的執行緒池會把池子佔滿，連時限的那個 Task 都排不到。
/// 一次只做一件、照順序做：逾時沒等到的那一件，一定排在後來的「刪雲端」前面。
final class CloudLine: Sendable {
    private let queue = DispatchQueue(label: "org.domyweb.douzhang.cloud", qos: .utility)

    func run<T: Sendable>(
        _ seconds: Double,
        _ work: @escaping @Sendable (CloudTicket) throws -> T
    ) async throws -> T {
        let ticket = CloudTicket()
        let queue = queue
        do {
            return try await TimeLimit.run(seconds) {
                try await withCheckedThrowingContinuation { continuation in
                    queue.async {
                        let result: Result<T, Error> = Result { try ticket.run(work) }
                        continuation.resume(with: result)
                    }
                }
            }
        } catch {
            ticket.cancel()
            throw error
        }
    }
}

/// 排隊做的那一件事的號碼牌。等的人走了（逾時）就作廢：還沒輪到的不會再做，
/// 正在等 iCloud 讓路的叫它別等了。
final class CloudTicket: @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelled = false
    private var waiting: NSFileCoordinator?

    func run<T>(_ work: (CloudTicket) throws -> T) throws -> T {
        try check()
        return try work(self)
    }

    /// 這件事要用的協調器。記著它，作廢時才叫得停（cancel 哪個執行緒都能叫）。
    func coordinator() throws -> NSFileCoordinator {
        let fresh = NSFileCoordinator(filePresenter: nil)
        lock.lock()
        waiting = fresh
        lock.unlock()
        try check()
        return fresh
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let stuck = waiting
        lock.unlock()
        stuck?.cancel()
    }

    private func check() throws {
        lock.lock()
        let isOver = isCancelled
        lock.unlock()
        if isOver {
            throw CloudError.stopped
        }
    }
}
