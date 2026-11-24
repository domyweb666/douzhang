import Foundation

/// iCloud 那份要刪的時候：關掉選了「也刪掉」、清除所有資料、沒刪成的再按一次。
/// 刪了救不回來，所以三條路同一個規矩：知道是哪個 iCloud、登入的就是那一個，才刪。
extension CloudLink {
    private static let pendingKey = "cloudErasePending"

    /// 要刪的是哪個 iCloud。
    private enum EraseTarget {
        /// 這支手機沒有帳本：沒放過東西，沒有要刪的
        case none
        /// 不知道是哪個：不准刪
        case unknown
        case known(String)
    }

    /// 說要刪、還沒刪成的那一份：是哪個 iCloud（空字串＝不知道是哪個，等帳本讀得到才准刪），沒有是 nil。
    /// 寫下來，刪到一半 app 被關掉才有得再刪。UserDefaults 會跟著備份到別支手機，
    /// 所以連是哪支手機一起記，不是自己的不算；當下問不到是哪支的先記空的，算自己的。
    var erasePending: String? {
        get {
            let saved = defaults.stringArray(forKey: CloudLink.pendingKey) ?? []
            guard let owner = saved.first, owner.isEmpty || owner == ledgerFile.phone() else {
                return nil
            }
            return saved.last
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: CloudLink.pendingKey)
                return
            }
            defaults.set([ledgerFile.phone() ?? "", newValue], forKey: CloudLink.pendingKey)
        }
    }

    /// 說過要刪、還沒刪成：那句話一直留著。不自動重刪，等人按。
    var lastingProblem: CloudProblem? {
        erasePending == nil ? nil : .eraseFailed
    }

    /// 雲端可能有這支手機放的：清除所有資料、關掉同步時要不要問。不看買了沒，退款的人也要問得到。
    /// 沒有帳本的不算：換機還原、沒登入過的，開關開著也沒放過東西。帳本讀不到時當有。
    var hasCopy: Bool {
        if erasePending != nil {
            return true
        }
        do {
            guard let book = try ledger ?? ledgerFile.read() else { return false }
            return book.seen || isOn
        } catch {
            return true
        }
    }

    func forgetLedger() {
        ledger = nil
        ledgerFile.remove()
    }

    /// 清除所有資料：關同步、忘掉帳本；erasing 是當場問到的答案，選留著就連上次沒刪成的也不刪了。
    func wipe(erasing: Bool) {
        let target: EraseTarget = erasing ? eraseTarget : .none
        turnOff()
        switch target {
        case .none:
            erasePending = nil
            problem = nil
            forgetLedger()
        case .unknown:
            refuse()
        case let .known(identity):
            erasePending = identity
            problem = nil
            forgetLedger()
            Task { await erase(identity) }
        }
    }

    /// 關掉時選了「也刪掉」，或上次沒刪成再按一次。回有沒有刪成。
    @discardableResult
    func eraseCloud() async -> Bool {
        let target = eraseTarget
        turnOff()
        switch target {
        case .none:
            return true
        case .unknown:
            refuse()
            return false
        case let .known(identity):
            erasePending = identity
            return await erase(identity)
        }
    }

    /// 帳本對的那個；帳本已經忘了就是上次說要刪的那個。帳本讀不到就不知道。
    private var eraseTarget: EraseTarget {
        do {
            let book = try ledger ?? ledgerFile.read()
            if let identity = book?.identity {
                return .known(identity)
            }
        } catch {
            return .unknown
        }
        guard let pending = erasePending else { return .none }
        return pending.isEmpty ? .unknown : .known(pending)
    }

    /// 不刪，照實說沒刪成。帳本留著：刪掉它就永遠不知道是誰的。
    private func refuse() {
        erasePending = erasePending ?? ""
        problem = .eraseFailed
    }

    /// 先等手上的傳輸收工再刪：不然寫到一半的那個檔會在刪完之後又出現。
    /// 刪的時候又被打開，也是刪完才開工。
    private func erase(_ identity: String) async -> Bool {
        guard !isErasing else { return false }
        isErasing = true
        let grace = BackgroundGrace()
        await worker?.value
        var failure: Error?
        do {
            try await drive.erase(for: identity)
            erasePending = nil
            forgetLedger()
        } catch {
            note("erase", error)
            failure = error
        }
        grace.end()
        isErasing = false
        if failure == nil || isOn {
            problem = lastingProblem
        } else {
            let isOther = (failure as? CloudError) == .otherAccount
            problem = isOther ? .eraseOther : .eraseFailed
        }
        kick()
        return failure == nil
    }
}
