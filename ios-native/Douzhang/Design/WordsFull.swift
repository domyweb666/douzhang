import Foundation
import VeggieKit

/// 完整版的字：付費頁、設定頁購買區、買與恢復的每一種結果。
/// 結果的第一句回答錢的狀態；不寫金額，價格只用 Apple 給的字。
extension Words {
    static let fullName = "番茄帳完整版"
    static let priceReading = "正在讀價格"
    static let priceFailed = "沒有扣款。現在讀不到價格。"
    private static let chargedHint = "有被扣款的話，按「\(VeggieText.restore)」。"
    private static let otherAccountHint = "用別的 Apple 帳號買的，先到 App Store 換成那個帳號再試。"
    private static let notVerified = "Apple 傳回的購買紀錄驗不過，先當作沒買。"

    /// 買完講哪一句。取消、重複點什麼都不說。
    static func buyLine(_ result: BuyResult) -> String? {
        switch result {
        case .cancelled, .busy: nil
        case .owned: "買好了，完整版可以用了。"
        case .noPrice: priceFailed
        case .pending: "還沒扣款，這筆購買在等核准。核准之後完整版就能用。"
        case let .problem(problem): problemLine(problem)
        }
    }

    /// 恢復完講哪一句。全家共用的三句用 VeggieText。
    static func restoreLine(_ result: RestoreResult) -> String? {
        switch result {
        case .cancelled, .busy: nil
        case .owned: VeggieText.restored
        case .nothing: "\(VeggieText.restoreNothing)。\(otherAccountHint)"
        case .unverified: "\(notVerified)等一下再按一次「\(VeggieText.restore)」。"
        case .failed: VeggieText.restoreFailed
        }
    }

    private static func problemLine(_ problem: BuyProblem) -> String {
        switch problem {
        case .unconfirmed: "付款完成了，還讀不到購買紀錄。等一下按「\(VeggieText.restore)」。"
        case .unverified: "可能已經扣款。\(notVerified)\(chargedHint)"
        case .offline: "沒有完成購買，連不上 App Store。\(chargedHint)"
        case .blocked: "沒有扣款。這支手機不能用 App 內購買，到「螢幕使用時間」看看有沒有關掉。"
        case .unavailable: "沒有扣款。App Store 現在買不到\(fullName)。"
        case .failed: "沒有完成購買，等一下再試一次。\(chargedHint)"
        }
    }

    // MARK: 設定頁

    static let fullRow = "完整版"
    static let fullOwned = "已購買"
    /// 正在恢復：設定頁那一列的右邊、付費頁的主按鈕
    static let fullRestoring = "正在恢復"

    /// 「完整版」那一列右邊的字。有字就是買了、不能點；沒有就點進付費頁。
    static func fullRowValue(_ status: FullStatus) -> String? {
        status == .owned ? fullOwned : nil
    }

    // MARK: 付費頁的按鈕

    static let fullDecline = "先不用"

    /// 主按鈕。會跳付款視窗的只有寫著「購買」的這一顆（準則 6-16）。
    static func fullMain(_ main: FullOffer.Main) -> String {
        switch main {
        case .readingPrice: priceReading
        case .readPrice: "再讀一次"
        case .buy: "購買"
        case .buying: "購買中"
        case .restoring: fullRestoring
        case .restore: VeggieText.restore
        case .done: confirm
        }
    }

    // MARK: 付費頁的承諾句（草稿：送審前要多米逐句確認，準則 6-19、3-29；編號照 J-設計選項第 5 題）

    /// 5-1
    static let fullOnce = "付一次就能一直用"
    /// 5-5：上面那行是 zenEnter
    static let fullZenNote = "手機橫放，整頁大時鐘"
    /// 5-3：上面那行是 cloudRow
    static let fullCloudNote = "開著同步，換手機番茄還在。要登入 iCloud"
    /// 5-4：上面那行是 shieldRow
    static let fullShieldNote = "要允許螢幕使用時間"
    /// 5-2：寫了就不能再向買過的人收這兩樣的錢
    static let fullLater = "之後新增的背景音與外觀"
    static let fullLaterNote = "也包含在內"

    // MARK: 付費頁的聚焦預覽

    static let fullSample = "範例"
    static let fullSampleDoing = "寫第三節"

    static func fullSampleA11y(_ time: String) -> String {
        "聚焦模式的範例，剩 \(time)"
    }
}
