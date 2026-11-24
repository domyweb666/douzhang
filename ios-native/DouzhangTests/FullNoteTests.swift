@testable import Douzhang
import XCTest

/// 關掉付費頁再進來，剛做完的那一次留不留；計時開始時付費頁收不收。
final class FullNoteTests: XCTestCase {
    /// 錢的事還沒定論的：可能付過了，或在等核准
    private let unsettled: [FullNote.Result] = [
        .bought(.pending),
        .bought(.problem(.unverified)),
        .bought(.problem(.unconfirmed)),
        .restored(.unverified),
    ]
    private let settled: [FullNote.Result] = [
        .bought(.owned),
        .bought(.cancelled),
        .bought(.busy),
        .bought(.noPrice),
        .bought(.problem(.offline)),
        .bought(.problem(.blocked)),
        .bought(.problem(.unavailable)),
        .bought(.problem(.failed)),
        .restored(.owned),
        .restored(.cancelled),
        .restored(.busy),
        .restored(.nothing),
        .restored(.failed),
    ]
    private let silent: [FullNote.Result] = [
        .bought(.cancelled),
        .bought(.busy),
        .restored(.cancelled),
        .restored(.busy),
    ]

    // MARK: 關掉再進來

    func test沒定論的關掉再進來不會變回購買那句也在() throws {
        for result in unsettled {
            let note = FullNote(result: result)
            for status in [FullStatus.unknown, .notOwned] {
                let kept = try XCTUnwrap(note.kept(status), "\(result)")
                XCTAssertEqual(kept, note)
                for price in FullPrice.allCases {
                    let shelf = FullShelf(status: status, price: price)
                    let now = FullOffer.now(shelf, note: kept)
                    let isPending = result == .bought(.pending)
                    XCTAssertEqual(now.main, isPending ? .done : .restore, "\(result)")
                    // 頁一打開就讀價格：讀不到的那句不准蓋掉這句
                    XCTAssertNotNil(now.line)
                    XCTAssertEqual(now.line, note.line, "\(result)")
                }
                XCTAssertEqual(kept.settingsLine(status), note.line)
            }
        }
    }

    func test沒定論的買到了就不留() {
        for result in unsettled {
            XCTAssertNil(FullNote(result: result).kept(.owned), "\(result)")
        }
    }

    func test有定論的關掉就不留() {
        for result in settled {
            XCTAssertFalse(FullNote(result: result).isUnsettled, "\(result)")
            for status in [FullStatus.unknown, .owned, .notOwned] {
                XCTAssertNil(FullNote(result: result).kept(status), "\(result)")
            }
        }
    }

    // MARK: 又做了一次

    func test沒定論的不因為取消或重複點就忘了() {
        for result in unsettled {
            let last = FullNote(result: result)
            for quiet in silent {
                XCTAssertEqual(FullNote.after(last, quiet), last, "\(result) \(quiet)")
            }
        }
    }

    func test有新結果就換新的() {
        let news: [FullNote.Result] = [
            .restored(.owned),
            .restored(.nothing),
            .restored(.unverified),
        ]
        for result in unsettled {
            let last = FullNote(result: result)
            for next in news {
                let after = FullNote.after(last, next)
                XCTAssertEqual(after.result, next)
                XCTAssertNotEqual(after.id, last.id)
            }
        }
    }

    func test沒定論的恢復沒成功還是原來那句再講一次() {
        for result in unsettled {
            let last = FullNote(result: result)
            let after = FullNote.after(last, .restored(.failed))
            XCTAssertEqual(after.result, result)
            // 新的 id：再震一次、再念一次，不然按了像沒反應
            XCTAssertNotEqual(after.id, last.id)
            let now = FullOffer.now(FullShelf(status: .notOwned), note: after)
            XCTAssertNotEqual(now.main, .buy, "\(result)")
            XCTAssertEqual(now.line, last.line, "\(result)")
        }
        let first = FullNote.after(nil, .restored(.failed))
        XCTAssertEqual(first.result, .restored(.failed))
    }

    func test有定論的取消就換成取消() {
        for quiet in silent {
            let last = FullNote(result: .bought(.problem(.offline)))
            XCTAssertEqual(FullNote.after(last, quiet).result, quiet)
            XCTAssertEqual(FullNote.after(nil, quiet).result, quiet)
        }
    }

    // MARK: 付費頁開著時開始計時

    private func cue(_ isFocusing: Bool, _ note: FullNote? = nil) -> FullCue {
        FullCue(isFocusing: isFocusing, note: note)
    }

    func test下一顆自己開始就收正在付款不收() {
        XCTAssertTrue(cue(true).closes(after: cue(false), isBusy: false))
        XCTAssertFalse(cue(true).closes(after: cue(false), isBusy: true))
        XCTAssertFalse(cue(false).closes(after: cue(true), isBusy: false))
    }

    func test結果跟下一顆同一拍到有話講就留著() {
        let told = FullNote(result: .bought(.owned))
        XCTAssertFalse(cue(true, told).closes(after: cue(false), isBusy: false))
        // 早就講過的那句不算
        XCTAssertTrue(cue(true, told).closes(after: cue(false, told), isBusy: false))
        let quiet = FullNote(result: .bought(.cancelled))
        XCTAssertTrue(cue(true, quiet).closes(after: cue(false), isBusy: false))
    }

    func test付款中開始計時付完沒話講才收() {
        for quiet in silent {
            let note = FullNote(result: quiet)
            XCTAssertTrue(cue(true, note).closes(after: cue(true), isBusy: false), "\(quiet)")
            // 還有另一件在做
            XCTAssertFalse(cue(true, note).closes(after: cue(true), isBusy: true))
            // 沒在計時的取消：頁留著
            XCTAssertFalse(cue(false, note).closes(after: cue(false), isBusy: false))
        }
        for told in [FullNote.Result.bought(.owned), .bought(.pending), .restored(.nothing)] {
            let note = FullNote(result: told)
            XCTAssertFalse(cue(true, note).closes(after: cue(true), isBusy: false), "\(told)")
        }
    }

    func test計時中再按一次清掉上一句不算付完() {
        let last = FullNote(result: .bought(.problem(.offline)))
        XCTAssertFalse(cue(true).closes(after: cue(true, last), isBusy: false))
    }
}
