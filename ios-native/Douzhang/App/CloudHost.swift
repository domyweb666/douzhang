import Foundation

/// 番茄與標籤的主人（AppModel；測試裡是假的）。CloudLink 只認這三樣，不認畫面。
@MainActor
protocol CloudHost: AnyObject {
    /// 現在的狀態。檔還沒讀完、讀不懂、上次沒存進去時是 nil：那時不拉也不傳
    var cloudState: AppState? { get }
    /// 換上合好的那份並存檔。進行中那顆與偏好沒有動；不准重播番茄掉落
    func takeCloud(_ merged: AppState)
    /// 第一次同步之前，把現在存著的原文自動備份一份。回成不成功（沒東西要備份也算）
    func backUpForCloud() -> Bool
}

/// 停下來問「放進去／先不要」的原因。
enum CloudQuestion {
    /// Apple 帳號換了
    case account
    /// 看過東西的 iCloud 整個空了，或這台放的被刪掉
    case emptied
    /// 開關是開的、帳本是新的，又不是剛剛親手打開：換機還原、轉給別人的手機
    case restored
}

/// 設定列下面那一句的原因。
enum CloudProblem: CaseIterable {
    case off, backupFailed, paused, eraseFailed
    /// 要刪的那份在別的 Apple 帳號
    case eraseOther
}

/// 使用者答應過把這支手機的番茄放進哪個 iCloud。
enum CloudConsent: Equatable {
    case none
    /// 剛剛親手打開同步：第一次就放進現在登入的那個
    case any
    /// 按了「放進去」：只答應問的那一個
    case only(String)

    var identity: String? {
        if case let .only(identity) = self {
            return identity
        }
        return nil
    }
}

/// 等多久（秒）。測試換成短的。
struct CloudWaits {
    var push = Params.cloudPushSeconds
    var notice = Params.cloudNoticeSeconds
    var off = Params.cloudOffSeconds
    var empty = Params.cloudEmptySeconds
    var pull = Params.cloudPullSeconds
}

/// 傳得出去的那一半狀態。草稿每個字都會存檔，這一半沒變就不用整份再算一次。
struct CloudContent: Equatable {
    private let days: [String: DayRecord]
    private let types: [TagType]
    private let removed: [RemovedTag]

    init(_ state: AppState) {
        days = state.days
        types = state.settings.types
        removed = state.settings.removedTypes
    }
}
