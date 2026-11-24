@testable import Douzhang
import XCTest

/// 完整版買了沒、能不能用、每一種結果講哪一句。
final class FullRuleTests: XCTestCase {
    private func deal(
        _ productID: String = FullRule.productID,
        isVerified: Bool = true,
        isRevoked: Bool = false
    ) -> FullRule.Deal {
        FullRule.Deal(productID: productID, isVerified: isVerified, isRevoked: isRevoked)
    }

    // MARK: 一堆紀錄 → 這次的答案

    func test驗過沒被收回的完整版才算買了() {
        XCTAssertEqual(FullRule.check([deal()]), .owned)
        XCTAssertEqual(FullRule.check([]), .notOwned)
    }

    func test別的產品不算() {
        XCTAssertEqual(FullRule.check([deal("org.domyweb.qieji.full")]), .notOwned)
    }

    func test退款被收回不算() {
        XCTAssertEqual(FullRule.check([deal(isRevoked: true)]), .notOwned)
        XCTAssertEqual(FullRule.check([deal(isRevoked: true), deal()]), .owned)
    }

    func test只有驗不過的那筆要分得出來() {
        XCTAssertEqual(FullRule.check([deal(isVerified: false)]), .unverified)
        XCTAssertEqual(FullRule.check([deal(isVerified: false), deal()]), .owned)
    }

    // MARK: 這次的答案 → 買了沒

    func test問得到照Apple() {
        for known in [FullStatus.unknown, .owned, .notOwned] {
            XCTAssertEqual(FullRule.next(known, check: .owned), .owned)
            XCTAssertEqual(FullRule.next(known, check: .notOwned), .notOwned)
        }
    }

    func test驗不過當沒買() {
        for known in [FullStatus.unknown, .owned, .notOwned] {
            XCTAssertEqual(FullRule.next(known, check: .unverified), .notOwned)
        }
    }

    func test問不到維持這次打開已經知道的() {
        for known in [FullStatus.unknown, .owned, .notOwned] {
            XCTAssertEqual(FullRule.next(known, check: .unreachable), known)
        }
    }

    // MARK: 剛買完、突然變空、恢復

    func test剛買完問不到就用手上那一筆() {
        XCTAssertEqual(FullRule.settled(.unreachable, proof: deal()), .owned)
    }

    func test剛買完問得到就照Apple() {
        for check in [FullRule.Check.owned, .notOwned, .unverified] {
            XCTAssertEqual(FullRule.settled(check, proof: deal()), check)
        }
    }

    func test手上那一筆不合格就還是問不到() {
        let bad = [
            deal("org.domyweb.qieji.full"),
            deal(isVerified: false),
            deal(isRevoked: true),
        ]
        for proof in bad {
            XCTAssertEqual(FullRule.settled(.unreachable, proof: proof), .unreachable)
        }
        XCTAssertEqual(FullRule.settled(.unreachable, proof: nil), .unreachable)
    }

    func test知道買了卻一筆都沒有才再看一眼() {
        XCTAssertTrue(FullRule.needsSecondLook(.owned, check: .notOwned))
        XCTAssertFalse(FullRule.needsSecondLook(.unknown, check: .notOwned))
        XCTAssertFalse(FullRule.needsSecondLook(.notOwned, check: .notOwned))
        for check in [FullRule.Check.owned, .unverified, .unreachable] {
            XCTAssertFalse(FullRule.needsSecondLook(.owned, check: check))
        }
    }

    func test再看一眼離線的維持退款的鎖回去() {
        XCTAssertEqual(FullRule.secondLook(nil), .unreachable)
        XCTAssertEqual(FullRule.secondLook(deal()), .owned)
        XCTAssertEqual(FullRule.secondLook(deal(isRevoked: true)), .notOwned)
        XCTAssertEqual(FullRule.secondLook(deal(isVerified: false)), .unverified)
    }

    func test恢復沒同步成功不准說沒買過() {
        for check in [FullRule.Check.notOwned, .unverified, .unreachable] {
            let result = FullRule.restored(.notOwned, check: check, isSynced: false)
            XCTAssertEqual(result, .failed)
        }
        let owned = FullRule.restored(.owned, check: .owned, isSynced: false)
        XCTAssertEqual(owned, .owned)
    }

    func test恢復同步成功照問到的說() {
        func restored(_ check: FullRule.Check) -> RestoreResult {
            FullRule.restored(.notOwned, check: check, isSynced: true)
        }
        XCTAssertEqual(restored(.notOwned), .nothing)
        XCTAssertEqual(restored(.unverified), .unverified)
        XCTAssertEqual(restored(.unreachable), .failed)
        XCTAssertEqual(FullRule.restored(.owned, check: .unreachable, isSynced: true), .owned)
    }

    // MARK: 問的次序

    func test照順序回來的都收() {
        var order = AskOrder()
        let first = order.begin()
        XCTAssertTrue(order.accept(first, check: .notOwned))
        let second = order.begin()
        XCTAssertTrue(order.accept(second, check: .owned))
    }

    func test先問的晚到不收() {
        var order = AskOrder()
        let first = order.begin()
        let second = order.begin()
        XCTAssertTrue(order.accept(second, check: .owned))
        XCTAssertFalse(order.accept(first, check: .notOwned))
    }

    func test後問的沒問到先問的晚到照收() {
        var order = AskOrder()
        let first = order.begin()
        let second = order.begin()
        XCTAssertTrue(order.accept(second, check: .unreachable))
        XCTAssertTrue(order.accept(first, check: .owned))
    }

    // MARK: 能不能用

    func test只有確定買了才解鎖() {
        for feature in FullFeature.allCases {
            XCTAssertTrue(FullRule.allows(feature, status: .owned))
            XCTAssertFalse(FullRule.allows(feature, status: .notOwned))
            XCTAssertFalse(FullRule.allows(feature, status: .unknown))
        }
    }

    // MARK: 結果對字

    func test取消與重複點什麼都不說() {
        XCTAssertNil(Words.buyLine(.cancelled))
        XCTAssertNil(Words.buyLine(.busy))
        XCTAssertNil(Words.restoreLine(.cancelled))
        XCTAssertNil(Words.restoreLine(.busy))
    }

    func test買的每一種結果第一句回答錢的狀態() {
        let heads: [(BuyResult, String)] = [
            (.owned, "買好了"),
            (.noPrice, "沒有扣款"),
            (.pending, "還沒扣款"),
            (.problem(.unconfirmed), "付款完成了"),
            (.problem(.unverified), "可能已經扣款"),
            (.problem(.offline), "沒有完成購買"),
            (.problem(.blocked), "沒有扣款"),
            (.problem(.unavailable), "沒有扣款"),
            (.problem(.failed), "沒有完成購買"),
        ]
        for (result, head) in heads {
            XCTAssertEqual(Words.buyLine(result)?.hasPrefix(head), true, "\(result)")
        }
    }

    func test不用多米的禁用詞() {
        let results = [BuyResult.owned, .noPrice, .pending]
        let all = results + BuyProblem.allCases.map { BuyResult.problem($0) }
        for result in all {
            XCTAssertEqual(Words.buyLine(result)?.contains("解鎖"), false, "\(result)")
        }
    }

    func test買的問題每一種都有自己的一句() {
        let lines = BuyProblem.allCases.compactMap { Words.buyLine(.problem($0)) }
        XCTAssertEqual(Set(lines).count, BuyProblem.allCases.count)
    }

    func test可能被扣款的都說要按恢復購買() {
        let maybeCharged: [BuyProblem] = [.unconfirmed, .unverified, .offline, .failed]
        for problem in maybeCharged {
            let line = Words.buyLine(.problem(problem)) ?? ""
            XCTAssertTrue(line.contains("恢復購買"), "\(problem)")
        }
    }

    func test恢復用全家共用的三句() {
        XCTAssertEqual(Words.restoreLine(.owned), "已恢復你的購買")
        XCTAssertEqual(Words.restoreLine(.failed), "出了點問題，請再試一次")
        let nothing = "沒有找到購買紀錄。用別的 Apple 帳號買的，先到 App Store 換成那個帳號再試。"
        XCTAssertEqual(Words.restoreLine(.nothing), nothing)
        XCTAssertEqual(Words.restoreLine(.unverified)?.contains("驗不過"), true)
    }

    func test出了問題才算問題() {
        for result in [BuyResult.owned, .cancelled, .busy, .noPrice, .pending] {
            XCTAssertFalse(result.isProblem)
        }
        for problem in BuyProblem.allCases {
            XCTAssertTrue(BuyResult.problem(problem).isProblem)
        }
        XCTAssertEqual(RestoreResult.allCases.filter(\.isProblem), [.unverified, .failed])
    }
}
