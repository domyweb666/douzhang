@testable import Douzhang
import XCTest

/// 月檢視下面「這個月做了什麼」的清單，與「在做什麼」當主字。
final class MonthDoneTests: XCTestCase {
    private let key = "2026-11-17"

    private func bean(
        _ day: Int,
        _ hour: Int,
        len: Double,
        typeId: String = "t1",
        doing: String = "",
        clue: String = ""
    ) -> Bean {
        var made = November.bean(day, hour, 0, len: len, typeId: typeId)
        made.doing = doing
        made.clue = clue
        return made
    }

    private func days(_ records: [String: DayRecord]) -> [DoneDay] {
        var state = Store.blank()
        state.days = records
        return MonthDone.days(state, key: key)
    }

    func test列這個月有番茄的日子新的在上() {
        var voided = DayRecord()
        let voidedAt = Moment.local(2026, 11, 12, 10, 7)
        voided.voids = [
            VoidEntry(voidedAt: voidedAt, typeId: "t1", minute: 7, reason: "", text: ""),
        ]
        let records = [
            "2026-10-30": November.day(bean(3, 9, len: 25)),
            "2026-11-03": November.day(bean(3, 9, len: 25)),
            "2026-11-12": voided,
            "2026-11-16": DayRecord(),
            "2026-11-17": November.day(bean(17, 9, len: 25)),
            "2026-12-01": November.day(bean(17, 9, len: 25)),
        ]
        XCTAssertEqual(days(records).map(\.key), ["2026-11-17", "2026-11-03"])
    }

    func test主字有寫在做什麼就用那句沒寫用標籤名同名合併分鐘多的在前() throws {
        let record = November.day(
            bean(17, 9, len: 25),
            bean(17, 10, len: 25, doing: "寫稿"),
            bean(17, 11, len: 25, typeId: "t2", doing: "寫稿"),
            bean(17, 13, len: 30, typeId: "t3")
        )
        let day = try XCTUnwrap(days([key: record]).first)
        XCTAssertEqual(day.names, ["寫稿", "閱讀", "專注"])
        XCTAssertEqual(day.sum, DaySum(beans: 4, minutes: 105))
    }

    func test色塊是那天最多分鐘的標籤延長也算一樣多照先做的() {
        // t1 紅、t2 紫
        var flowed = bean(17, 9, len: 25)
        flowed.flow = 30
        let byFlow = days([key: November.day(flowed, bean(17, 11, len: 50, typeId: "t2"))])
        XCTAssertEqual(byFlow.first?.color, .red)
        let total = November.day(
            bean(17, 9, len: 25),
            bean(17, 10, len: 25, typeId: "t2"),
            bean(17, 11, len: 25, typeId: "t2")
        )
        XCTAssertEqual(days([key: total]).first?.color, .purple)
        let tied = November.day(bean(17, 9, len: 25, typeId: "t2"), bean(17, 10, len: 25))
        XCTAssertEqual(days([key: tied]).first?.color, .purple)
    }

    func test副字是那天收下的第一句() {
        let wrote = November.day(
            bean(17, 11, len: 25, clue: "後寫的"),
            bean(17, 9, len: 25),
            bean(17, 10, len: 25, clue: "先寫的")
        )
        let plain = November.day(bean(3, 9, len: 25))
        let found = days([key: wrote, "2026-11-03": plain])
        XCTAssertEqual(found.map(\.clue), ["先寫的", ""])
    }

    func test刪掉的標籤照原本的名字沒留名字的叫已刪除的標籤() {
        let found = days([key: November.day(bean(17, 9, len: 25, typeId: "deleted"))])
        XCTAssertEqual(found.first?.names, [Words.removedTag])
    }

    func test沒番茄與讀不懂的日期鍵都是空的() {
        XCTAssertEqual(days([:]), [])
        XCTAssertEqual(MonthDone.days(Store.blank(), key: "oops"), [])
    }

    func test清單的字最多列三個再寫等() {
        XCTAssertEqual(Words.doneNames(["寫稿"]), "寫稿")
        XCTAssertEqual(Words.doneNames(["寫稿", "備課", "剪片"]), "寫稿、備課、剪片")
        XCTAssertEqual(Words.doneNames(["寫稿", "備課", "剪片", "閱讀"]), "寫稿、備課、剪片等")
        XCTAssertEqual(Words.weekdayCompact(key), "週二")
    }

    func test標題這個月或幾月() {
        XCTAssertEqual(Words.doneTitle("2026-11-03", todayKey: key), "這個月做了什麼")
        XCTAssertEqual(Words.doneTitle("2026-10-01", todayKey: key), "10月做了什麼")
        XCTAssertEqual(Words.doneTitle("2025-11-01", todayKey: key), "11月做了什麼")
    }

    func test讀屏念日期做了什麼幾顆多久與那句() {
        let found = days([key: November.day(bean(17, 9, len: 25, doing: "寫稿", clue: "寫完開頭"))])
        XCTAssertEqual(
            found.first.map(Words.doneA11y),
            "11月17日 星期二，寫稿，1 顆・25 分，寫完開頭"
        )
    }
}

/// 「在做什麼」帶進時間軸與收據，當主字。
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

    func test有寫在做什麼就用那句沒寫用標籤名() {
        let type = Store.defaultType
        XCTAssertEqual(Receipt.workName("寫稿", type: type), "寫稿")
        XCTAssertEqual(Receipt.workName("", type: type), type.name)
    }

    func test作廢那行有寫在做什麼就放最前面() {
        XCTAssertEqual(
            Words.voidLine(minute: 7, reason: "卡住", text: "", doing: "寫稿"),
            "寫稿・作廢，第 7 分鐘・卡住"
        )
    }
}
