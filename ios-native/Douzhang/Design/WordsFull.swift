import Foundation
import VeggieKit

/// 買完整版、恢復購買的每一種結果怎麼說。第一句回答錢的狀態；不寫金額，價格只用 Apple 給的字。
/// 付費頁上的承諾句不在這裡，等多米逐句確認再加。
extension Words {
    static let fullName = "番茄帳完整版"
    static let priceReading = "正在讀價格"
    static let priceFailed = "讀不到價格，點一下重試"
    private static let chargedHint = "有被扣款的話，按「\(VeggieText.restore)」。"
    private static let otherAccountHint = "用別的 Apple 帳號買的，先到 App Store 換成那個帳號再試。"
    private static let notVerified = "Apple 傳回的購買紀錄驗不過，先當作沒買。"

    /// 買完講哪一句。取消、重複點什麼都不說。
    static func buyLine(_ result: BuyResult) -> String? {
        switch result {
        case .cancelled, .busy: nil
        case .owned: "買好了，完整版可以用了。"
        case .noPrice: "沒有扣款。\(priceFailed)。"
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
}
