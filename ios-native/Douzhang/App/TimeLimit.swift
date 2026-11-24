import Foundation

/// 等一件事最多幾秒，超過就丟 Expired。
/// StoreKit 與 iCloud 的呼叫不理會取消，不能用 task group：group 結束前會等它跑完，等於沒設時限
/// （豆鍵 2026-11-11 在審查的 iPad 上就是這樣一直轉圈被退）。
/// 改成兩個各自跑的工作搶著回覆，先到的算數，晚到的丟掉。
/// 工作裡只准 await：會卡住執行緒的（NSFileCoordinator、找 iCloud 容器、同步讀檔）先丟到
/// DispatchQueue.global() 再接回來，不然執行緒池佔滿，計時那個也醒不來。
enum TimeLimit {
    struct Expired: Error {}

    static func run<T: Sendable>(
        _ seconds: Double,
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let reply = ReplyOnce(continuation)
            Task {
                do {
                    let value = try await work()
                    reply.send(.success(value))
                } catch {
                    reply.send(.failure(error))
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                reply.send(.failure(Expired()))
            }
        }
    }
}

/// 只讓第一個回覆送出去，第二個直接丟掉：continuation 回覆兩次會閃退。
private final class ReplyOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func send(_ result: Result<T, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}
