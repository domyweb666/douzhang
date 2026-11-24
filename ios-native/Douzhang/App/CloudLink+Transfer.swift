import Foundation
import os

/// 拉與傳的步驟。只有 worker 會叫，刪雲端（+Erase）會先等 worker 收工，所以三件事不會重疊。
/// 每次 await 回來都先 isCurrent 對號，對不上就不碰任何東西。
extension CloudLink {
    // MARK: 拉

    /// 把別台的讀下來合進本機。成功一次之後這次打開才准傳。
    func pull() async {
        let turn = generation
        var isDone = false
        defer {
            if turn == generation {
                missedPull = host?.cloudState == nil
                // 沒拉全：同一份清單再有動靜時要再拉，不能當成看過了
                if !isDone || !resting.isEmpty {
                    lastNoticed = nil
                }
            }
        }
        guard let state = host?.cloudState else { return }
        do {
            guard let identity = try await account(turn),
                  let book = try openLedger(identity, state),
                  let files = try await list(book, identity: identity, turn: turn) else { return }
            let found = try await fetch(files, own: book.device, identity: identity, turn: turn)
            let remotes = await CloudLink.remotes(found, own: book.device)
            guard isCurrent(turn), await join(remotes, turn: turn) else { return }
            var next = book
            next.identity = identity
            next.seen = book.seen || !files.isEmpty
            keep(next)
            ready = true
            isDone = unread == nil
            if problem != nil {
                problem = nil
            }
            // 第一次傳、有哪個檔不見了要補寫，都在這一趟
            requestPush()
            if !isDone {
                pullSoon()
            }
        } catch {
            failed("pull", error, turn)
        }
    }

    /// 能讀的都讀下來。還沒下載好的請系統下載，這輪跳過：下載好會有動靜，到時再拉一次。
    /// 時間到了就先合已經讀到的，記著下一趟從哪裡接；一趟至少走一個檔，才不會一直停在同一個。
    private func fetch(
        _ files: [CloudFile],
        own: String,
        identity: String,
        turn: Int
    ) async throws -> [String: Data] {
        let end = ContinuousClock.now + .seconds(waits.pull)
        let others = files.filter { SyncFiles.locate($0.path)?.device != own }
        let start = others.firstIndex { $0.path == unread } ?? 0
        unread = nil
        var found: [String: Data] = [:]
        for (order, file) in others[start...].enumerated() {
            guard isCurrent(turn) else { break }
            guard order == 0 || ContinuousClock.now < end else {
                unread = file.path
                break
            }
            if !file.isReady {
                await drive.download(file.path)
            } else if !isResting(file.path) {
                let data = try await read(file.path, identity: identity, turn: turn)
                found[file.path] = data
            }
        }
        return found
    }

    /// 讀不到就跳過這個檔，不影響別的檔；換了帳號就整趟不算。
    private func read(_ path: String, identity: String, turn: Int) async throws -> Data? {
        do {
            return try await drive.read(path, for: identity)
        } catch CloudError.otherAccount {
            throw CloudError.otherAccount
        } catch CloudError.notReady {
            return nil
        } catch {
            if isCurrent(turn) {
                resting[path] = ContinuousClock.now
                note("read", error)
            }
            return nil
        }
    }

    private func isResting(_ path: String) -> Bool {
        guard let since = resting[path] else { return false }
        return ContinuousClock.now - since < .seconds(Params.cloudRestSeconds)
    }

    /// 合進本機。整份合一次要算一陣子，放背景算；算的時候使用者又收了一顆、打了字，
    /// 就拿新的那份重合，換上去的一定是跟此刻的狀態合出來的。回能不能接著傳。
    private func join(_ remotes: [SyncFiles.Remote], turn: Int) async -> Bool {
        for _ in 0 ..< Params.cloudMergeTries {
            guard let base = host?.cloudState else { return false }
            let merged = await CloudLink.merged(base, remotes)
            guard isCurrent(turn) else { return false }
            if host?.cloudState == base {
                return take(merged, over: base)
            }
        }
        // 一直在動：這次直接在主執行緒合，不再追
        guard let base = host?.cloudState else { return false }
        return take(SyncMerge.merged(base, remotes), over: base)
    }

    private func take(_ merged: AppState, over base: AppState) -> Bool {
        if merged != base {
            host?.takeCloud(merged)
        }
        return host?.cloudState != nil
    }

    // MARK: 傳

    /// 把這台現在的整份寫進自己的資料夾。跟上次傳的一樣、檔也還在的就不寫。
    func push() async {
        let turn = generation
        guard ready, let state = host?.cloudState, let book = ledger else { return }
        do {
            guard let identity = try await account(turn),
                  let files = try await list(book, identity: identity, turn: turn) else { return }
            let parcels = await CloudLink.parcels(state, device: book.device)
            let there = Set(files.map(\.path))
            guard isCurrent(turn) else { return }
            if book.sent.isEmpty {
                try await drive.prepare(book.device, for: identity)
            }
            for parcel in parcels {
                if there.contains(parcel.path), book.sent[parcel.path] == parcel.sha {
                    continue
                }
                guard isCurrent(turn) else { return }
                try await drive.write(parcel.path, parcel.data, for: identity)
                guard isCurrent(turn), var next = ledger else { return }
                next.sent[parcel.path] = parcel.sha
                next.seen = true
                keep(next)
            }
            guard isCurrent(turn) else { return }
            sentContent = CloudContent(state)
        } catch {
            failed("push", error, turn)
        }
    }

    // MARK: 失敗

    private func failed(_ what: String, _ error: Error, _ turn: Int) {
        guard isCurrent(turn) else { return }
        note(what, error)
        if (error as? CloudError) == .otherAccount {
            // 重拉一趟，第一步就會看到換了帳號、停下來問
            pullSoon()
        }
    }

    /// 靜靜同步，失敗不跳出來；只印錯誤的型別，不印路徑與內容。
    func note(_ what: String, _ error: Error) {
        let kind = String(describing: type(of: error))
        CloudLink.log.error("\(what, privacy: .public): \(kind, privacy: .public)")
    }

    // MARK: 放背景算的

    /// 要寫的一個檔。
    struct Parcel {
        var path: String
        var data: Data
        var sha: String
    }

    private nonisolated static func remotes(
        _ files: [String: Data],
        own: String
    ) async -> [SyncFiles.Remote] {
        await Task.detached(priority: .utility) {
            SyncFiles.remotes(files, except: own)
        }.value
    }

    private nonisolated static func merged(
        _ base: AppState,
        _ remotes: [SyncFiles.Remote]
    ) async -> AppState {
        await Task.detached(priority: .utility) {
            SyncMerge.merged(base, remotes)
        }.value
    }

    private nonisolated static func parcels(_ state: AppState, device: String) async -> [Parcel] {
        await Task.detached(priority: .utility) {
            SyncFiles.outgoing(state, device: device)
                .sorted { $0.key < $1.key }
                .map { path, text in
                    let data = Data(text.utf8)
                    return Parcel(path: path, data: data, sha: CloudHash.hex(data))
                }
        }.value
    }
}
