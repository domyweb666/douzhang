@testable import Douzhang
import XCTest

/// 月檢視下面那塊：選中那一天的番茄，與換月之後停在哪一天。
final class MonthBoardTests: XCTestCase {
    private let key = "2026-11-17"

    private func state(_ records: [String: DayRecord]) -> AppState {
        var made = Store.blank()
        made.days = records
        return made
    }

    private func voidDay(_ day: Int) -> DayRecord {
        let voidedAt = Moment.local(2026, 11, day, 10, 7)
        let entry = VoidEntry(voidedAt: voidedAt, typeId: "t1", minute: 7, reason: "", text: "")
        return DayRecord(beans: [], voids: [entry])
    }

    private func landing(_ records: [String: DayRecord], month: String) -> String {
        MonthBoard.landing(state(records), month: month, todayKey: key)
    }

    func test列那天的番茄由早到晚作廢不列() {
        var record = voidDay(17)
        record.beans = [
            November.bean(17, 13, 0, len: 30, typeId: "t3"),
            November.bean(17, 9, 0, len: 25),
        ]
        let found = MonthBoard.beans(state([key: record]), key: key)
        XCTAssertEqual(found.map(\.typeId), ["t1", "t3"])
        XCTAssertEqual(found.map(\.kind), [.bean, .bean])
    }

    func test沒紀錄只有作廢與讀不懂的日期鍵都是空的() {
        XCTAssertEqual(MonthBoard.beans(state([:]), key: key), [])
        XCTAssertEqual(MonthBoard.beans(state([key: voidDay(17)]), key: key), [])
        XCTAssertEqual(MonthBoard.beans(state([:]), key: "oops"), [])
    }

    func test刪掉又沒留名字的標籤叫已刪除的標籤() {
        let record = November.day(November.bean(17, 9, 0, len: 25, typeId: "deleted"))
        let made = state([key: record])
        let names = MonthBoard.beans(made, key: key).map { item in
            Machine.typeOf(made, item.typeId).name
        }
        XCTAssertEqual(names, [Words.removedTag])
    }

    func test翻回這個月選今天不管哪天有番茄() {
        let records = ["2026-11-03": November.day(November.bean(3, 9, 0, len: 25))]
        XCTAssertEqual(landing(records, month: "2026-11-01"), key)
        XCTAssertEqual(landing([:], month: "2026-11-01"), key)
    }

    func test翻到以前的月選那個月最後一個有番茄的日子() {
        let bean = November.bean(3, 9, 0, len: 25)
        let records = [
            "2026-09-30": November.day(bean),
            "2026-10-02": November.day(bean),
            "2026-10-20": November.day(bean),
            "2026-10-28": voidDay(17),
            "2026-10-30": DayRecord(),
            "2026-11-03": November.day(bean),
        ]
        XCTAssertEqual(landing(records, month: "2026-10-01"), "2026-10-20")
    }

    func test那個月沒有番茄就選一號() {
        let records = [
            "2026-10-28": voidDay(17),
            "2026-11-03": November.day(November.bean(3, 9, 0, len: 25)),
        ]
        XCTAssertEqual(landing(records, month: "2026-10-01"), "2026-10-01")
        XCTAssertEqual(landing(records, month: "2025-11-01"), "2025-11-01")
    }

    func test葉子只給第一顆以後過完沒番茄的日子格子跟下面那塊同一條規則() {
        let made = state([
            "2026-11-05": voidDay(5),
            "2026-11-10": November.day(November.bean(10, 9, 0, len: 25)),
            "2026-11-12": voidDay(12),
        ])
        let since = MonthBoard.firstKept(made)
        XCTAssertEqual(since, "2026-11-10")
        let days = RackCalendar.monthWeeks(made, key: key, todayKey: key).flatMap(\.days)
        for day in days where day.inMonth {
            let hasLeaf = MonthBoard.hasLeaf(made, key: day.key, todayKey: key, since: since)
            // 還沒開始用的（只有作廢也算還沒）、有番茄的、今天與以後都不寫
            let expected = day.key > "2026-11-10" && day.key < key
            XCTAssertEqual(hasLeaf, expected, day.key)
            XCTAssertEqual(day.leaf, hasLeaf, day.key)
        }
        // 一顆都沒有的人：哪天都不寫
        XCTAssertNil(MonthBoard.firstKept(state([:])))
        XCTAssertFalse(
            MonthBoard.hasLeaf(state([:]), key: "2026-11-01", todayKey: key, since: nil)
        )
    }

    func test標題寫幾月幾日週幾() {
        XCTAssertEqual(Words.dayHead("2026-11-26"), "11月26日 週四")
        XCTAssertEqual(Words.dayHead("2026-11-01"), "11月1日 週日")
    }

    func test一列讀屏念時刻標籤名多長在做什麼與筆記() {
        var wrote = November.bean(17, 5, 24, len: 25, flow: 15)
        wrote.doing = "寫稿"
        wrote.clue = "寫完開頭"
        let plain = November.bean(17, 9, 0, len: 1)
        let found = MonthBoard.beans(state([key: November.day(wrote, plain)]), key: key)
        XCTAssertEqual(
            found.map { Words.monthBeanA11y($0, name: "專注") },
            ["05:24，專注，25 分＋15，寫稿，寫完開頭", "09:00，專注，1 分"]
        )
    }

    func test時間軸一顆讀屏念標籤名長度在做什麼與筆記沒寫的不念() {
        var wrote = November.bean(17, 9, 0, len: 25)
        wrote.doing = "寫第三節"
        wrote.clue = "寫完開頭"
        let items = Receipt.timeline(November.day(wrote, November.bean(17, 10, 0, len: 50)))
        XCTAssertEqual(
            items.map { Words.blockA11y($0, name: "專注") },
            ["專注，25 分，寫第三節，寫完開頭", "專注，50 分"]
        )
    }
}

/// 「在做什麼」帶進時間軸與收據（時間軸主字是標籤名，在做什麼排在長度後面）。
final class DoingTitleTests: XCTestCase {
    func test時間軸與收據都帶著在做什麼作廢也帶() {
        var kept = November.bean(17, 9, 0, len: 25)
        kept.doing = "寫稿"
        let voidedAt = Moment.local(2026, 11, 17, 10, 7)
        var voided = VoidEntry(voidedAt: voidedAt, typeId: "t1", minute: 7, reason: "", text: "")
        voided.doing = "剪片"
        let day = DayRecord(beans: [kept], voids: [voided])
        XCTAssertEqual(Receipt.timeline(day).map(\.doing), ["寫稿", "剪片"])
        XCTAssertEqual(Receipt.rows(day).map(\.doing), ["寫稿", "剪片"])
    }

    func test作廢那行有寫在做什麼就放最前面() {
        XCTAssertEqual(
            Words.voidLine(minute: 7, reason: "卡住", text: "", doing: "寫稿"),
            "寫稿・作廢，第 7 分鐘・卡住"
        )
    }
}
