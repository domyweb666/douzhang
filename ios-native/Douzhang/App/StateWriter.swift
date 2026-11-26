import Foundation

/// 把狀態寫進狀態檔，在背景寫。一年份的整份 JSON 編碼加寫檔要幾十毫秒，放在主執行緒會掉好幾格（效能審查甲1）。
/// 一條序列佇列，最新一份勝出：還沒開始寫的那份被新的蓋掉，正在寫的寫完再寫最新那份。
/// 所以落地的順序跟交進來的順序一樣，只是中間幾份可能跳過。不另外計時節流：資料越晚落地越危險。
final class StateWriter: @unchecked Sendable {
    private let file: StateFile
    private let queue = DispatchQueue(label: "org.domyweb.douzhang.state", qos: .userInitiated)
    private let lock = NSLock()
    /// 排著、還沒開始寫的那份與寫完要叫的；輪到時才拿走
    private var waiting: (state: AppState, done: @MainActor (Bool) -> Void)?
    /// 最後寫的那一份成不成；還沒寫過算成（沒有東西存不進去）
    private var lastSaved = true

    init(file: StateFile) {
        self.file = file
    }

    /// 交一份去寫。寫完回主執行緒叫 done，帶成不成；被後來的蓋掉的那份不會叫。
    func save(_ state: AppState, done: @escaping @MainActor (Bool) -> Void) {
        let isFirst = lock.withLock {
            let wasEmpty = waiting == nil
            waiting = (state, done)
            return wasEmpty
        }
        // 已經有一份在排：換掉它就好，輪到時寫的就是這份
        guard isFirst else { return }
        queue.async { self.writeWaiting() }
    }

    /// 等交進來的都寫完才回來：進背景、要讀檔之前。回最後寫的那一份成不成：
    /// 寫完回主執行緒的那一報還在排，要當場知道存不存得進去的（同步合併、清除、匯入）看這個。
    func flush() -> Bool {
        queue.sync { lock.withLock { lastSaved } }
    }

    private func writeWaiting() {
        let next = lock.withLock {
            defer { waiting = nil }
            return waiting
        }
        guard let next else { return }
        let isSaved = file.save(next.state)
        lock.withLock { lastSaved = isSaved }
        // main.async 照排的順序跑：兩次寫完的結果不會倒過來
        DispatchQueue.main.async {
            MainActor.assumeIsolated { next.done(isSaved) }
        }
    }
}
