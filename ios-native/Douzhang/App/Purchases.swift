import Foundation
import Observation
import os
import StoreKit

/// 完整版的購買（StoreKit 2）：問 Apple 買了沒、讀價格、買、恢復購買。規則在 FullRule，句子在 Words。
/// 送審前要給會寫 iOS 的人看過的檔（準則 6-34）。
/// 「買了沒」只放記憶體，打開、回到前景、買完、恢復完都重問；不存憑證、不印交易內容、錯誤只印型別。
/// 沒有假解鎖：開發版也要用沙盒帳號或 StoreKit 測試設定檔真的買。
@MainActor
@Observable
final class Purchases {
    private static let log = Logger(subsystem: "org.domyweb.douzhang", category: "purchase")

    private(set) var status = FullStatus.unknown
    /// Apple 給的在地價格字串，還沒讀到是 nil
    private(set) var price: String?
    /// 讀過、讀不到：按鈕改成再讀一次
    private(set) var priceFailed = false
    private(set) var isPricing = false
    /// 正在買或正在恢復：那兩顆按鈕先不能點
    private(set) var isBusy = false

    @ObservationIgnored private var product: Product?
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var order = AskOrder()

    func allows(_ feature: FullFeature) -> Bool {
        FullRule.allows(feature, status: status)
    }

    /// 打開 app 時叫一次：聽別處完成的交易（別台買的、家長核准、退款）、收掉沒結束的、問買了沒。
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.settle(result)
            }
        }
        // 各跑各的：沒結束的那串卡住，也不能擋著問買了沒
        Task {
            for await result in StoreKit.Transaction.unfinished {
                await settle(result)
            }
        }
        Task { await firstAsk() }
    }

    /// 重新問一次買了沒。打開 app、回到前景、買完、恢復完都叫。
    @discardableResult
    func refresh() async -> FullRule.Check {
        await reask(proof: nil)
    }

    /// 讀價格：付費頁、設定頁打開時，還有讀不到按重試。
    func loadPrice() async {
        guard !isPricing, status != .owned else { return }
        isPricing = true
        priceFailed = false
        defer { isPricing = false }
        if let found = await fetchProduct() {
            product = found
            price = found.displayPrice
        } else {
            priceFailed = price == nil
        }
    }

    /// 只准由寫著「購買」的按鈕叫。買的就是讀到價格的那個商品，付款框跳出來之後不設時限。
    func buy() async -> BuyResult {
        guard !isBusy else { return .busy }
        guard let product else { return .noPrice }
        guard AppStore.canMakePayments else { return .problem(.blocked) }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case let .success(result):
                return await bought(result)
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .problem(.failed)
            }
        } catch {
            note("buy", error)
            return Purchases.failure(error)
        }
    }

    func restore() async -> RestoreResult {
        guard !isBusy else { return .busy }
        isBusy = true
        defer { isBusy = false }
        var isSynced = true
        do {
            // 不設時限：這一步可能要他登入 Apple 帳號，不能在打密碼時中斷
            try await AppStore.sync()
        } catch {
            note("restore", error)
            if Purchases.failure(error) == .cancelled {
                return .cancelled
            }
            isSynced = false
        }
        // 同步沒成功也再問一次：買過的人，手機裡常常本來就有那筆紀錄
        let check = await refresh()
        return FullRule.restored(status, check: check, isSynced: isSynced)
    }

    // MARK: 跟 Apple 要東西

    private func bought(_ result: VerificationResult<StoreKit.Transaction>) async -> BuyResult {
        guard case .verified = result else {
            await refresh()
            return .problem(.unverified)
        }
        await reask(proof: Purchases.brief(result))
        finish(result)
        return status == .owned ? .owned : .problem(.unconfirmed)
    }

    private func settle(_ result: VerificationResult<StoreKit.Transaction>) async {
        await refresh()
        finish(result)
    }

    /// 驗過的都收掉，不然下次打開會一直再送；驗不過的不收、不算數。
    /// 不等它：finish 沒有時限，卡住會擋著付了錢的人，也擋著後面的退款通知。沒收成的下次打開再收。
    private func finish(_ result: VerificationResult<StoreKit.Transaction>) {
        guard case let .verified(deal) = result else { return }
        Task { await deal.finish() }
    }

    /// 打開那一次問不到，晚到的答案已經丟了：不再問的話，買過的人這次打開都算沒買。
    private func firstAsk() async {
        for _ in 0 ..< Params.storeTries {
            let check = await refresh()
            if check != .unreachable {
                return
            }
        }
    }

    /// proof 是剛買完 Apple 交回來的那一筆，只在問不到時才用得上（FullRule.settled）。
    @discardableResult
    private func reask(proof: FullRule.Deal?) async -> FullRule.Check {
        let turn = order.begin()
        let check = await FullRule.settled(ask(), proof: proof)
        guard order.accept(turn, check: check) else { return check }
        let next = FullRule.next(status, check: check)
        if next != status {
            status = next
        }
        return check
    }

    private func ask() async -> FullRule.Check {
        do {
            let deals = try await TimeLimit.run(Params.storeWaitSeconds) {
                await Purchases.deals()
            }
            let check = FullRule.check(deals)
            guard FullRule.needsSecondLook(status, check: check) else { return check }
            let latest = try await TimeLimit.run(Params.storeWaitSeconds) {
                await Purchases.latestDeal()
            }
            return FullRule.secondLook(latest)
        } catch {
            note("entitlements", error)
            return .unreachable
        }
    }

    /// 沒拿到（逾時、斷線、Apple 回空的）再試一次，還是沒有就回 nil。
    private func fetchProduct() async -> Product? {
        for _ in 0 ..< Params.storeTries {
            do {
                let found = try await TimeLimit.run(Params.storeWaitSeconds) {
                    try await Product.products(for: [FullRule.productID])
                }
                if let match = found.first(where: { $0.id == FullRule.productID }) {
                    return match
                }
            } catch {
                note("price", error)
            }
        }
        return nil
    }

    private func note(_ what: String, _ error: Error) {
        let kind = String(describing: type(of: error))
        Purchases.log.error("\(what, privacy: .public): \(kind, privacy: .public)")
    }
}

/// 不碰自己狀態的那幾個：把 StoreKit 的型別換成規則看得懂的。
extension Purchases {
    /// StoreKit 丟出來的錯 → 畫面要分的幾種情況；認不得的一律當一般失敗。
    nonisolated static func failure(_ error: Error) -> BuyResult {
        if let kit = error as? StoreKitError {
            switch kit {
            case .userCancelled: return .cancelled
            case .networkError: return .problem(.offline)
            case .notAvailableInStorefront: return .problem(.unavailable)
            default: return .problem(.failed)
            }
        }
        if let refusal = error as? Product.PurchaseError {
            switch refusal {
            case .purchaseNotAllowed: return .problem(.blocked)
            case .productUnavailable: return .problem(.unavailable)
            default: return .problem(.failed)
            }
        }
        return .problem(.failed)
    }

    private nonisolated static func deals() async -> [FullRule.Deal] {
        var found: [FullRule.Deal] = []
        for await result in StoreKit.Transaction.currentEntitlements {
            found.append(brief(result))
        }
        return found
    }

    /// 最近一筆完整版交易；退款的也在，帶著撤銷日期。
    private nonisolated static func latestDeal() async -> FullRule.Deal? {
        let latest = await StoreKit.Transaction.latest(for: FullRule.productID)
        guard let latest else { return nil }
        return brief(latest)
    }

    private nonisolated static func brief(
        _ result: VerificationResult<StoreKit.Transaction>
    ) -> FullRule.Deal {
        switch result {
        case let .verified(deal):
            FullRule.Deal(
                productID: deal.productID,
                isVerified: true,
                isRevoked: deal.revocationDate != nil
            )
        case let .unverified(deal, _):
            FullRule.Deal(
                productID: deal.productID,
                isVerified: false,
                isRevoked: deal.revocationDate != nil
            )
        }
    }
}
