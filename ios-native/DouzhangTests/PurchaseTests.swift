@testable import Douzhang
import StoreKit
import StoreKitTest
import XCTest

/// 購買的殼：錯誤怎麼分、還沒讀到價格不准買；真的買一次、退一次用 StoreKit 的測試商店
/// （不連 App Store、不花錢）。
@MainActor
final class PurchaseTests: XCTestCase {
    func test打開時還不知道買了沒什麼都不解鎖() {
        let shop = Purchases()
        XCTAssertEqual(shop.status, .unknown)
        for feature in FullFeature.allCases {
            XCTAssertFalse(shop.allows(feature))
        }
    }

    func test還沒讀到價格不准買() async {
        let shop = Purchases()
        let result = await shop.buy()
        XCTAssertEqual(result, .noPrice)
        XCTAssertFalse(shop.isBusy)
    }

    func testStoreKit的錯分成畫面要講的幾種() {
        let offline = StoreKitError.networkError(URLError(.notConnectedToInternet))
        XCTAssertEqual(Purchases.failure(StoreKitError.userCancelled), .cancelled)
        XCTAssertEqual(Purchases.failure(offline), .problem(.offline))
        let elsewhere = StoreKitError.notAvailableInStorefront
        XCTAssertEqual(Purchases.failure(elsewhere), .problem(.unavailable))
        XCTAssertEqual(Purchases.failure(StoreKitError.unknown), .problem(.failed))
        let refused = Product.PurchaseError.purchaseNotAllowed
        XCTAssertEqual(Purchases.failure(refused), .problem(.blocked))
        let gone = Product.PurchaseError.productUnavailable
        XCTAssertEqual(Purchases.failure(gone), .problem(.unavailable))
        XCTAssertEqual(Purchases.failure(TimeLimit.Expired()), .problem(.failed))
    }

    // MARK: 測試商店

    /// 雲端的測試環境裡 purchase() 會一直等（茄記 2026-11-22 卡過），
    /// 所以預設不跑；在有畫面的 Xcode 加環境變數 DOUZHANG_STOREKIT_TESTS=1 才跑。
    private func openStore() throws -> SKTestSession {
        let isOn = ProcessInfo.processInfo.environment["DOUZHANG_STOREKIT_TESTS"] == "1"
        try XCTSkipUnless(isOn, "購買整合測試要在 Xcode 開 DOUZHANG_STOREKIT_TESTS=1 才跑")
        let bundle = Bundle(for: PurchaseTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "Full", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    func test買了解鎖退款就鎖回去() async throws {
        let session = try openStore()
        let shop = Purchases()
        await shop.refresh()
        XCTAssertEqual(shop.status, .notOwned)

        await shop.loadPrice()
        XCTAssertNotNil(shop.price)
        let result = await shop.buy()
        XCTAssertEqual(result, .owned)
        XCTAssertTrue(shop.allows(.cloud))

        let deal = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: deal.identifier)
        await shop.refresh()
        XCTAssertEqual(shop.status, .notOwned)
    }

    func test重開之後照Apple的紀錄解鎖() async throws {
        let session = try openStore()
        let first = Purchases()
        await first.loadPrice()
        _ = await first.buy()

        // 本機什麼都沒存：新的一個要從 Apple 問回來
        let reopened = Purchases()
        XCTAssertEqual(reopened.status, .unknown)
        await reopened.refresh()
        XCTAssertEqual(reopened.status, .owned)
        session.clearTransactions()
    }
}
