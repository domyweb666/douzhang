import Foundation

/// 正在跟 App Store 做的那件事。
enum FullDoing {
    case buying, restoring
}

/// 價格現在讀到哪了。
enum FullPrice: CaseIterable {
    /// 還沒開始讀
    case idle
    case reading, failed, known
}

/// 畫付費頁要知道的三件事。
struct FullShelf {
    var status = FullStatus.unknown
    var price = FullPrice.known
    var doing: FullDoing?
}

/// 剛做完的那一次買或恢復。
struct FullNote: Equatable {
    enum Result: Equatable {
        case bought(BuyResult), restored(RestoreResult)
    }

    var result: Result
    /// 同一個結果連兩次，也要再震一次、再念一次
    var id = UUID()

    var line: String? {
        switch result {
        case let .bought(result): Words.buyLine(result)
        case let .restored(result): Words.restoreLine(result)
        }
    }

    var isProblem: Bool {
        switch result {
        case let .bought(result): result.isProblem
        case let .restored(result): result.isProblem
        }
    }

    /// 這句說的是「買了」。
    var saysOwned: Bool {
        result == .bought(.owned) || result == .restored(.owned)
    }

    /// 設定頁那一行：跟現在對不上的舊話不講（說恢復了、後來退款；說沒找到、後來買了）。
    func settingsLine(_ status: FullStatus) -> String? {
        saysOwned == (status == .owned) ? line : nil
    }

    /// 這個結果之後，主按鈕不再是「購買」的那幾種。可能已經付過錢的只給恢復，不讓他再付一次。
    fileprivate var main: FullOffer.Main? {
        switch result {
        case .bought(.pending): .done
        case .bought(.problem(.unverified)), .bought(.problem(.unconfirmed)): .restore
        case .restored(.unverified): .restore
        case .bought, .restored: nil
        }
    }
}

/// 付費頁底下那一塊現在的樣子：講哪一句、主按鈕做什麼。純函式，畫面照著畫。
struct FullOffer: Equatable {
    enum Main: CaseIterable {
        case readingPrice, readPrice, buy, buying, restoring, restore, done
    }

    var main: Main
    var line: String?
    var isProblem = false

    static func now(_ shelf: FullShelf, note: FullNote?) -> FullOffer {
        if let doing = shelf.doing {
            return FullOffer(main: doing == .buying ? .buying : .restoring)
        }
        if shelf.status == .owned {
            return FullOffer(main: .done, line: ownedLine(note))
        }
        // 上次說買到了、現在卻沒有：退款了，那句不算
        let told = note?.saysOwned == true ? nil : note
        let noPrice = shelf.price == .failed ? Words.priceFailed : nil
        return FullOffer(
            main: told?.main ?? priceMain(shelf.price),
            line: told?.line ?? noPrice,
            isProblem: told?.isProblem ?? false
        )
    }

    /// 頁開著的時候變成買了：買的、恢復的、別處核准的；開頁時就已經買了的另一句。
    private static func ownedLine(_ note: FullNote?) -> String? {
        switch note?.result {
        case .bought: Words.buyLine(.owned)
        case .restored: Words.restoreLine(.owned)
        case nil: Words.fullOwned
        }
    }

    /// 沒看到價格不准付錢：讀不到就只能再讀一次。
    private static func priceMain(_ price: FullPrice) -> Main {
        switch price {
        case .known: .buy
        case .reading: .readingPrice
        case .idle, .failed: .readPrice
        }
    }

    /// 主按鈕是「等一下」，不能按。
    var isWaiting: Bool {
        switch main {
        case .readingPrice, .buying, .restoring: true
        case .readPrice, .buy, .restore, .done: false
        }
    }

    /// 還在決定要不要買：畫「付一次就能一直用」與價格。
    var showsPrice: Bool {
        main != .restore && main != .done
    }

    /// 「先不用」：已經沒有要不要買的問題時，主按鈕就是「好」。
    var showsDecline: Bool {
        main != .done
    }

    /// 下面那顆「恢復購買」：主按鈕已經是它的時候不畫兩顆。
    var showsRestore: Bool {
        main != .restore && main != .done
    }
}
