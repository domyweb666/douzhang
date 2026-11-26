import Foundation
import Observation
import os

/// iCloud 同步什麼時候拉、什麼時候傳。合併規則在 Core/Sync*，搬檔案在 CloudDrive，
/// 這裡是接頭：時機與排隊在這個檔，開關在 +Switch，拉、傳在 +Transfer，
/// 是哪個 iCloud、有沒有被清空在 +Account，刪雲端在 +Erase。
/// - 一次只有一個 worker 在跑，拉、傳、刪永遠不會同時
/// - 每件事開始時記下 generation，等回來先對號：關掉、退款、停下來問之後，晚到的結果一律丟掉
/// - 不准時只是停：不刪任何東西，手機裡的和 iCloud 裡的都不動
@MainActor
@Observable
final class CloudLink {
    static let key = "cloudSync"
    static let log = Logger(subsystem: "org.domyweb.douzhang", category: "cloud")

    /// 設定頁的開關。預設關
    private(set) var isOn: Bool
    var isErasing = false
    /// 停下來問：有值就跳框
    var question: CloudQuestion?
    /// 問過幾次：同一個問題連問兩次，畫面才分得出來
    var asks = 0
    /// 設定列下面那一句，沒事是 nil
    var problem: CloudProblem?

    @ObservationIgnored weak var host: CloudHost?
    @ObservationIgnored let drive: CloudDrive
    @ObservationIgnored let ledgerFile: CloudLedgerFile
    @ObservationIgnored var ledger: CloudLedger?
    /// 這次打開第一次拉完了：之後才准傳
    @ObservationIgnored var ready = false
    @ObservationIgnored var worker: Task<Void, Never>?
    /// 上次傳完的內容
    @ObservationIgnored var sentContent: CloudContent?
    /// 答應放進哪個 iCloud
    @ObservationIgnored var consent = CloudConsent.none
    /// 停下來問的時候，登入的是哪個 iCloud
    @ObservationIgnored var askedAbout: String?
    /// 第一次看到雲端空了是什麼時候
    @ObservationIgnored var emptySince: ContinuousClock.Instant?
    @ObservationIgnored var emptyWait: Task<Void, Never>?
    /// 在背景：iCloud 沒機會更新清單，這段看到的空不算
    @ObservationIgnored var isAway = false
    /// 本機讀不懂、沒存進去，那一趟拉沒做：好了要補
    @ObservationIgnored var missedPull = false
    @ObservationIgnored var lastNoticed: [CloudFile]?
    /// 時間到了還沒讀到的第一個檔：下一趟從它接著讀
    @ObservationIgnored var unread: String?
    /// 讀不到的檔，幾點讀的：隔幾分鐘才再讀
    @ObservationIgnored var resting: [String: ContinuousClock.Instant] = [:]
    /// 上次讀過的別台的檔：沒改過的不再讀
    @ObservationIgnored var copies = CloudCopies()

    @ObservationIgnored let defaults: UserDefaults
    @ObservationIgnored let waits: CloudWaits
    @ObservationIgnored private var isPaid = false
    @ObservationIgnored var paused = false
    @ObservationIgnored private(set) var generation = 0
    @ObservationIgnored private var wantsPull = false
    @ObservationIgnored private var wantsPush = false
    @ObservationIgnored private var pushWait: Task<Void, Never>?
    @ObservationIgnored private var noticeWait: Task<Void, Never>?
    @ObservationIgnored private var offWait: Task<Void, Never>?
    @ObservationIgnored private var offSince: ContinuousClock.Instant?

    init(
        drive: CloudDrive,
        ledgerFile: CloudLedgerFile,
        defaults: UserDefaults = .standard,
        waits: CloudWaits = CloudWaits()
    ) {
        self.drive = drive
        self.ledgerFile = ledgerFile
        self.defaults = defaults
        self.waits = waits
        isOn = defaults.bool(forKey: CloudLink.key)
    }

    /// 開著、買了、沒有停下來：三樣都對才准動。
    var allowed: Bool {
        isOn && isPaid && !paused
    }

    /// 這件事開始之後，沒有人關掉、停下來過。
    func isCurrent(_ turn: Int) -> Bool {
        turn == generation && allowed
    }

    // MARK: 什麼時候

    /// 讀完檔之後叫一次。
    func start(_ host: CloudHost) {
        self.host = host
        problem = lastingProblem
        requestPull()
    }

    /// 買了沒：打開 app、狀態變了都傳進來。退款只停同步，開關照舊留著。
    func setPaid(_ paid: Bool) {
        guard paid != isPaid else { return }
        isPaid = paid
        if paid {
            requestPull()
        } else {
            stop()
            paused = false
            question = nil
            problem = lastingProblem
        }
    }

    /// 空了多久從回來這一刻重新算。
    func becameActive() {
        isAway = false
        forgetEmpty()
        requestPull()
    }

    /// 存檔成功之後叫：停手一下才傳。番茄與標籤沒變就不傳。
    /// 之前因為本機讀不懂、沒存進去而沒拉成的，現在好了就補拉一次，不等下次回前景。
    func saved() {
        if missedPull, allowed, host?.cloudState != nil {
            missedPull = false
            requestPull()
        }
        guard hasNews else { return }
        pushWait?.cancel()
        pushWait = later(waits.push) { [weak self] in self?.requestPush() }
    }

    /// 進背景：不等了，馬上傳。跟系統要的那一點時間，不管成不成一定還。
    func enteredBackground() {
        isAway = true
        forgetEmpty()
        guard hasNews else { return }
        pushWait?.cancel()
        requestPush()
        guard let worker else { return }
        let grace = BackgroundGrace()
        Task {
            await worker.value
            grace.end()
        }
    }

    private var hasNews: Bool {
        guard allowed, ready, let state = host?.cloudState else { return false }
        return sentContent != CloudContent(state)
    }

    /// 打開、關掉都從頭來：之前停下來問的、出過的狀況不算了。
    func setOn(_ isOn: Bool) {
        self.isOn = isOn
        defaults.set(isOn, forKey: CloudLink.key)
        paused = false
        question = nil
        consent = .none
        problem = lastingProblem
    }

    // MARK: 排隊

    func requestPull() {
        guard allowed else { return }
        wantsPull = true
        kick()
    }

    func requestPush() {
        guard allowed else { return }
        wantsPush = true
        kick()
    }

    /// 刪雲端的時候不開工，刪完會再叫一次。
    func kick() {
        guard worker == nil, !isErasing, wantsPull || wantsPush else { return }
        worker = Task { await work() }
    }

    /// 一件做完才做下一件，先拉再傳。
    private func work() async {
        while !isErasing, wantsPull || wantsPush {
            if wantsPull {
                wantsPull = false
                await pull()
            } else {
                wantsPush = false
                pushWait?.cancel()
                await push()
            }
        }
        worker = nil
    }

    /// 作廢手上正在做的：generation 一加，等回來的都對不上號。
    func stop() {
        generation += 1
        ready = false
        wantsPull = false
        wantsPush = false
        pushWait?.cancel()
        noticeWait?.cancel()
        offWait?.cancel()
        offSince = nil
        forgetEmpty()
        missedPull = false
        lastNoticed = nil
        unread = nil
        sentContent = nil
        resting = [:]
        copies = CloudCopies()
        drive.unwatch()
    }

    func later(
        _ seconds: Double,
        _ act: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled {
                act()
            }
        }
    }

    func forgetEmpty() {
        emptyWait?.cancel()
        emptySince = nil
    }
}

// MARK: 雲端的動靜

extension CloudLink {
    func noticed(_ notice: CloudNotice) {
        guard allowed, let book = ledger else { return }
        switch notice {
        case .gathered:
            // 平常有一趟拉正在等它；那一趟等到逾時了才收齊，就補拉一次
            pullSoon(onlyIfUnready: true)
        case .account:
            pullSoon()
        case let .files(files):
            // 別台的檔真的變了、或整個空了才拉。自己寫的檔會一直有動靜，不理
            let others = files.filter { SyncFiles.locate($0.path)?.device != book.device }
            guard book.isGone(files) || others != lastNoticed else { return }
            lastNoticed = others
            pullSoon()
        }
    }

    func pullSoon(onlyIfUnready: Bool = false) {
        noticeWait?.cancel()
        noticeWait = later(waits.notice) { [weak self] in
            guard let self else { return }
            if onlyIfUnready, ready {
                return
            }
            requestPull()
        }
    }

    /// 連不連得到 iCloud。剛打開那幾秒常常還沒好：持續一陣子才說，好了就把那句收掉。
    func noteOff(_ isOff: Bool) {
        guard isOff else {
            offWait?.cancel()
            offSince = nil
            if problem == .off {
                problem = nil
            }
            return
        }
        guard let since = offSince else {
            offSince = ContinuousClock.now
            offWait = later(waits.off) { [weak self] in self?.requestPull() }
            return
        }
        if ContinuousClock.now - since >= .seconds(waits.off) {
            problem = .off
        }
    }
}
