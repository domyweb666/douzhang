import Foundation

/// 是哪個 iCloud、用哪本帳、雲端有沒有被清空：拉與傳動手前都要先過這一關。
extension CloudLink {
    /// 現在的 iCloud 代號。沒登入、或這輪已經作廢就是 nil。
    /// 帳本讀不到就丟錯：不知道上次對的是哪個，不准同步。
    func account(_ turn: Int) async throws -> String? {
        let book = try currentLedger()
        let known = [consent.identity, book?.identity].compactMap { $0 }
        var identity = try await drive.identity(like: known.first)
        if known.count > 1, identity != known.first {
            identity = try await drive.identity(like: known.last)
        }
        guard isCurrent(turn) else { return nil }
        noteOff(identity == nil)
        return identity
    }

    private func currentLedger() throws -> CloudLedger? {
        try ledger ?? ledgerFile.read()
    }

    /// 這輪要用的帳本。換了帳號、沒答應過就問，回 nil。
    func openLedger(_ identity: String, _ state: AppState) throws -> CloudLedger? {
        guard let saved = try currentLedger() else {
            guard consent == .any || consent.identity == identity else {
                ask(.restored, about: identity)
                return nil
            }
            return firstLedger(identity)
        }
        // 答應放進去的就是這一個：當成第一次
        if consent.identity == identity {
            return firstLedger(identity)
        }
        guard saved.identity == identity else {
            ask(.account, about: identity)
            return nil
        }
        // 同一個帳號，或換回來了：編號照舊
        consent = .none
        ledger = saved
        return isHollow(state, saved) ? renewed(saved) : saved
    }

    /// 第一次：先備份，備份不成就不同步。備份完馬上存帳本，下次才不會又備份一次。
    private func firstLedger(_ identity: String) -> CloudLedger? {
        var fresh = ledgerFile.fresh()
        fresh.identity = identity
        guard let host, host.backUpForCloud(), ledgerFile.save(fresh) else {
            problem = .backupFailed
            return nil
        }
        consent = .none
        ledger = fresh
        return fresh
    }

    /// 傳過番茄，本機卻一筆都沒有：狀態檔壞成空的。照這本帳走會拿空的蓋掉自己在雲端的那份。
    private func isHollow(_ state: AppState, _ book: CloudLedger) -> Bool {
        let isEmpty = state.days.values.allSatisfy { $0.beans.isEmpty && $0.voids.isEmpty }
        return isEmpty && book.hasSentRecords
    }

    /// 換一個編號，舊資料夾就變成「別台」，會自己合回來。還是同一個 iCloud，換帳號照樣問。
    private func renewed(_ book: CloudLedger) -> CloudLedger? {
        var fresh = ledgerFile.fresh()
        fresh.identity = book.identity
        fresh.seen = book.seen
        guard ledgerFile.save(fresh) else { return nil }
        ledger = fresh
        return fresh
    }

    /// 雲端的清單。換了帳號、被刪掉了：停下來問，回 nil。
    func list(_ book: CloudLedger, identity: String, turn: Int) async throws -> [CloudFile]? {
        if let known = book.identity, known != identity {
            ask(.account, about: identity)
            return nil
        }
        drive.watch { [weak self] notice in self?.noticed(notice) }
        let files = try await drive.files()
        guard isCurrent(turn) else { return nil }
        if book.isGone(files) {
            try await doubt(identity, turn)
            return nil
        }
        forgetEmpty()
        return files
    }

    /// 清單收齊了是空的，不等於雲端是空的：剛登入回來、剛更新完系統，伺服器的清單還沒下來也是空的。
    /// 隔一陣子再看一次還是空的才問，這段時間不傳。問之前再對一次帳號，列到一半換了要問的是換帳號。
    /// 在背景看到的不算：回到前景會再拉一次，從那時候算起。
    private func doubt(_ identity: String, _ turn: Int) async throws {
        guard !isAway else { return }
        guard let since = emptySince else {
            emptySince = ContinuousClock.now
            emptyWait = later(waits.empty) { [weak self] in self?.requestPull() }
            return
        }
        guard ContinuousClock.now - since >= .seconds(waits.empty) else { return }
        let again = try await drive.identity(like: identity)
        guard isCurrent(turn) else { return }
        guard let again else {
            noteOff(true)
            return
        }
        ask(again == identity ? .emptied : .account, about: again)
    }

    /// 存不進去就只留在記憶體：下次打開頂多多寫一次一樣的檔。
    func keep(_ book: CloudLedger) {
        guard book != ledger else { return }
        ledger = book
        _ = ledgerFile.save(book)
    }
}
