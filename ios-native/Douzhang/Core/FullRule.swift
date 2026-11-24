import Foundation

/// 完整版買了才有的功能。
enum FullFeature: CaseIterable {
    /// iCloud 同步
    case cloud
    /// 計時中擋住其他 app
    case shield
    /// 聚焦模式
    case zen
}

/// 買了沒。只活在記憶體，不存檔：存了就能改一個值免費用，退款後也收不回來。
enum FullStatus {
    /// 這次打開還沒問到過
    case unknown
    case owned, notOwned
}

/// 「完整版買了沒」與「能不能用」的規則。純函式，不碰 StoreKit、不碰儲存。
/// 這裡只回答案，不刪、不改任何番茄與設定：鎖回去（退款）只停功能。
enum FullRule {
    /// 要跟 App Store Connect 上的一字不差
    static let productID = "org.domyweb.douzhang.full"

    /// Apple 給的一筆購買紀錄，只留判斷要的三件事。
    struct Deal {
        var productID: String
        /// 簽章驗過
        var isVerified: Bool
        /// 退款、被收回
        var isRevoked: Bool
    }

    /// 問一次 Apple 的答案。
    enum Check {
        case owned, notOwned
        /// 有完整版的紀錄，但簽章驗不過
        case unverified
        /// 沒網路、App Store 沒回應、逾時
        case unreachable
    }

    /// 只信驗過、沒被收回、產品 ID 對的那一筆。
    static func check(_ deals: [Deal]) -> Check {
        let ours = deals.filter { $0.productID == productID && !$0.isRevoked }
        if ours.contains(where: \.isVerified) {
            return .owned
        }
        return ours.isEmpty ? .notOwned : .unverified
    }

    /// 剛買完的那次重問：有答案照 Apple 的；只是問不到，就用手上這一筆。
    /// 它跟 currentEntitlements 交出來的是同一種東西（驗過、產品對、沒被收回，同一條 check），
    /// 不用的話，付了錢的人只因為 Apple 回得慢就被鎖著。只在記憶體，下次打開照樣重問。
    static func settled(_ check: Check, proof: Deal?) -> Check {
        guard check == .unreachable, let proof else { return check }
        return FullRule.check([proof]) == .owned ? .owned : check
    }

    /// 這次打開已經知道買了，卻一筆都沒問到：離線、帳號暫時登出時 Apple 也會回空的，
    /// 不能當成退款，要再看一眼最近那一筆。
    static func needsSecondLook(_ known: FullStatus, check: Check) -> Bool {
        known == .owned && check == .notOwned
    }

    /// 再看一眼：退款會留撤銷日期，照樣鎖得回去；連一筆都沒有就是問不到。
    static func secondLook(_ latest: Deal?) -> Check {
        guard let latest else { return .unreachable }
        return check([latest])
    }

    /// 恢復完的結果。沒同步成功時，沒找到不算沒買過，只能說出了問題。
    static func restored(
        _ status: FullStatus,
        check: Check,
        isSynced: Bool
    ) -> RestoreResult {
        if status == .owned {
            return .owned
        }
        guard isSynced else { return .failed }
        switch check {
        case .notOwned: return .nothing
        case .unverified: return .unverified
        case .owned, .unreachable: return .failed
        }
    }

    /// 問得到照 Apple；驗不過當沒買；問不到維持這次打開已經知道的。
    static func next(_ known: FullStatus, check: Check) -> FullStatus {
        switch check {
        case .owned: .owned
        case .notOwned, .unverified: .notOwned
        case .unreachable: known
        }
    }

    /// 只有確定買了才算解鎖：還不知道的那一小段先停著。
    static func allows(_ feature: FullFeature, status: FullStatus) -> Bool {
        switch feature {
        case .cloud, .shield, .zen: status == .owned
        }
    }
}

/// 問 Apple 的次序：先問的晚到，不准蓋掉後問的（不然買完會被買之前問的那次鎖回去）。
struct AskOrder {
    private var asked = 0
    private var landed = 0

    mutating func begin() -> Int {
        asked += 1
        return asked
    }

    /// 這次的答案收不收。問不到的不算答案，不佔次序。
    mutating func accept(_ turn: Int, check: FullRule.Check) -> Bool {
        guard turn > landed else { return false }
        if check != .unreachable {
            landed = turn
        }
        return true
    }
}

/// 買一次的結果。每一種對一句話（Words.buyLine），取消什麼都不說。
enum BuyResult: Equatable {
    case owned, cancelled
    /// 正在買或正在恢復，這次沒做事
    case busy
    /// 還沒讀到價格：沒看到價格不准付錢
    case noPrice
    /// 等核准（家長、銀行）
    case pending
    case problem(BuyProblem)

    /// 出了問題才用紅字；買好了、等核准只是告知，用灰字。
    var isProblem: Bool {
        if case .problem = self {
            return true
        }
        return false
    }
}

/// 買不成，或買了但還不能算。
enum BuyProblem: CaseIterable {
    /// 付款完成了，但還讀不到那筆紀錄
    case unconfirmed
    /// 那筆交易的簽章驗不過
    case unverified
    case offline
    /// 這支手機不能用 App 內購買（螢幕使用時間，或公司、學校管理的手機）
    case blocked
    /// App Store 現在沒賣：沒上架、還沒過審，或這個地區沒有
    case unavailable
    case failed
}

/// 恢復購買的結果（Words.restoreLine）。
enum RestoreResult: CaseIterable {
    case owned, cancelled
    /// 正在買或正在恢復，這次沒做事
    case busy
    /// 問到了，這個帳號沒買過
    case nothing
    case unverified
    case failed

    /// 出了問題才用紅字；沒買過只是告知。
    var isProblem: Bool {
        switch self {
        case .owned, .cancelled, .busy, .nothing: false
        case .unverified, .failed: true
        }
    }
}
