@testable import Douzhang
import XCTest

/// 付費頁每一種狀態：講哪一句、主按鈕是哪一顆（畫布第 6 題那張表）、設定頁那一區。
final class FullOfferTests: XCTestCase {
    private func offer(
        _ result: FullNote.Result? = nil,
        status: FullStatus = .notOwned,
        price: FullPrice = .known,
        doing: FullDoing? = nil
    ) -> FullOffer {
        let shelf = FullShelf(status: status, price: price, doing: doing)
        return FullOffer.now(shelf, note: result.map { FullNote(result: $0) })
    }

    // MARK: 價格

    func test讀價格中不能按也不說話() {
        let now = offer(price: .reading)
        XCTAssertEqual(now, FullOffer(main: .readingPrice))
        XCTAssertTrue(now.isWaiting)
        XCTAssertEqual(Words.fullMain(now.main), "正在讀價格")
    }

    func test還沒按購買就讀不到價格不提扣款給再讀一次() {
        let now = offer(price: .failed)
        XCTAssertEqual(now, FullOffer(main: .readPrice, line: "現在讀不到價格。"))
        XCTAssertEqual(Words.fullMain(now.main), "再讀一次")
        XCTAssertFalse(now.isWaiting)
    }

    func test按了購買才發現沒有價格先講沒扣款() {
        let now = offer(.bought(.noPrice), price: .failed)
        XCTAssertEqual(now, FullOffer(main: .readPrice, line: "沒有扣款。現在讀不到價格。"))
    }

    func test還沒開始讀也按得到不會一直掛著正在讀() {
        XCTAssertEqual(offer(price: .idle), FullOffer(main: .readPrice))
    }

    func test沒看到價格不准出現購買() {
        for price in FullPrice.allCases where price != .known {
            XCTAssertNotEqual(offer(price: price).main, .buy)
            XCTAssertNotEqual(offer(.restored(.nothing), price: price).main, .buy)
        }
    }

    // MARK: 平常與正在做

    func test平常與自己按取消都不說話主按鈕是購買() {
        XCTAssertEqual(offer(), FullOffer(main: .buy))
        XCTAssertEqual(offer(.bought(.cancelled)), FullOffer(main: .buy))
        XCTAssertEqual(offer(.restored(.cancelled)), FullOffer(main: .buy))
        XCTAssertEqual(Words.fullMain(.buy), "購買")
    }

    func test還不知道買了沒照沒買畫() {
        for price in FullPrice.allCases {
            XCTAssertEqual(offer(status: .unknown, price: price), offer(price: price))
        }
    }

    func test購買中與恢復中主按鈕不能按先不用還在() {
        let buying = offer(doing: .buying)
        XCTAssertEqual(Words.fullMain(buying.main), "購買中")
        let restoring = offer(doing: .restoring)
        XCTAssertEqual(Words.fullMain(restoring.main), "正在恢復")
        for now in [buying, restoring] {
            XCTAssertNil(now.line)
            XCTAssertTrue(now.isWaiting)
            XCTAssertTrue(now.showsDecline)
            XCTAssertTrue(now.showsRestore)
        }
    }

    // MARK: 買的結果

    func test等核准灰字主按鈕是好不畫價格() {
        let now = offer(.bought(.pending))
        XCTAssertEqual(now, FullOffer(main: .done, line: Words.buyLine(.pending)))
        XCTAssertEqual(Words.fullMain(now.main), "好")
        XCTAssertFalse(now.showsPrice)
        XCTAssertFalse(now.showsDecline)
        XCTAssertFalse(now.showsRestore)
    }

    func test沒買成的紅字可以再買() {
        for problem in [BuyProblem.failed, .offline, .blocked, .unavailable] {
            let now = offer(.bought(.problem(problem)))
            XCTAssertEqual(now.main, .buy, "\(problem)")
            XCTAssertEqual(now.line, Words.buyLine(.problem(problem)))
            XCTAssertTrue(now.isProblem)
            XCTAssertTrue(now.showsPrice)
        }
    }

    func test可能付過錢的不給購買只給恢復() {
        let results: [FullNote.Result] = [
            .bought(.problem(.unverified)),
            .bought(.problem(.unconfirmed)),
            .restored(.unverified),
        ]
        for result in results {
            for price in FullPrice.allCases {
                let now = offer(result, price: price)
                XCTAssertEqual(now.main, .restore, "\(result)")
                XCTAssertTrue(now.isProblem)
                XCTAssertFalse(now.showsPrice)
                XCTAssertTrue(now.showsDecline)
                XCTAssertFalse(now.showsRestore)
            }
        }
        XCTAssertEqual(Words.fullMain(.restore), "恢復購買")
    }

    func test買好了灰字主按鈕是好() {
        let now = offer(.bought(.owned), status: .owned)
        XCTAssertEqual(now, FullOffer(main: .done, line: Words.buyLine(.owned)))
    }

    func test等核准的時候核准了換成買好了() {
        let now = offer(.bought(.pending), status: .owned)
        XCTAssertEqual(now, FullOffer(main: .done, line: Words.buyLine(.owned)))
    }

    func test頁開著才問到早就買了() {
        XCTAssertEqual(
            offer(status: .owned, price: .idle),
            FullOffer(main: .done, line: "已購買")
        )
    }

    func test買好之後退款那句不留著也能再買() {
        XCTAssertEqual(offer(.bought(.owned)), FullOffer(main: .buy))
        XCTAssertEqual(
            offer(.restored(.owned), price: .idle),
            FullOffer(main: .readPrice)
        )
    }

    // MARK: 恢復的結果

    func test恢復三種() {
        let found = offer(.restored(.owned), status: .owned)
        XCTAssertEqual(found, FullOffer(main: .done, line: "已恢復你的購買"))
        let nothing = offer(.restored(.nothing))
        XCTAssertEqual(nothing.main, .buy)
        XCTAssertEqual(nothing.line, Words.restoreLine(.nothing))
        XCTAssertFalse(nothing.isProblem)
        let failed = offer(.restored(.failed))
        XCTAssertEqual(failed.main, .buy)
        XCTAssertEqual(failed.line, Words.restoreLine(.failed))
        XCTAssertTrue(failed.isProblem)
    }

    func test同一個結果連兩次也算兩次() {
        let first = FullNote(result: .bought(.problem(.blocked)))
        let second = FullNote(result: .bought(.problem(.blocked)))
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.result, second.result)
    }

    // MARK: 字

    func test主按鈕的字都不一樣只有一顆寫購買() {
        let names = FullOffer.Main.allCases.map { Words.fullMain($0) }
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertEqual(names.filter { $0 == "購買" }.count, 1)
        XCTAssertFalse(names.contains { $0.contains("解鎖") })
    }

    // MARK: 設定頁購買區

    func test買了寫已購買不能點沒買與不知道可以點() {
        XCTAssertEqual(Words.fullRowValue(.owned), "已購買")
        XCTAssertNil(Words.fullRowValue(.notOwned))
        XCTAssertNil(Words.fullRowValue(.unknown))
    }

    func test設定頁那一行跟現在對不上就不講() {
        let found = FullNote(result: .restored(.owned))
        XCTAssertEqual(found.settingsLine(.owned), "已恢復你的購買")
        XCTAssertNil(found.settingsLine(.notOwned))
        let nothing = FullNote(result: .restored(.nothing))
        XCTAssertNotNil(nothing.settingsLine(.notOwned))
        XCTAssertNotNil(nothing.settingsLine(.unknown))
        XCTAssertNil(nothing.settingsLine(.owned))
        XCTAssertNil(FullNote(result: .restored(.cancelled)).settingsLine(.notOwned))
    }
}
