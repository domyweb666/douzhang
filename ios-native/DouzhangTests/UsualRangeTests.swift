@testable import Douzhang
import XCTest

/// 指標字典 M7（你平常幾顆）與 M8（斷了一陣子）。
final class UsualRangeTests: XCTestCase {
    private func state(_ beansPerDay: [Int: Int]) -> AppState {
        var state = Store.blank()
        for (day, beans) in beansPerDay {
            state.days[Sample.key(day)] = Sample.day(day, beans: beans)
        }
        return state
    }

    func test十個有番茄的日子取中間那一半() {
        let days = [11: 2, 12: 3, 13: 4, 14: 4, 15: 5, 16: 5, 17: 5, 18: 6, 19: 7, 20: 8]
        XCTAssertEqual(Insights.usualRange(state(days), todayKey: Sample.key(21)), 4 ... 6)
    }

    func test不到十個日子沒有範圍今天不算進去() {
        var days: [Int: Int] = [:]
        for day in 12 ... 21 {
            days[day] = 4
        }
        // 11/12 到 11/20 只有九天；今天那天不算
        XCTAssertNil(Insights.usualRange(state(days), todayKey: Sample.key(21)))
        XCTAssertEqual(Insights.usualRange(state(days), todayKey: Sample.key(22)), 4 ... 4)
    }

    func test只作廢的日子算零顆完全沒開的日子不算() {
        var made = state([2: 3, 4: 3, 6: 3, 8: 3, 10: 3, 12: 3, 14: 3, 16: 3, 18: 3])
        made.days[Sample.key(19)] = DayRecord(
            beans: [],
            voids: [Sample.voided(19, 9, minute: 8)]
        )
        // 九天各 3 顆、一天 0 顆：中間那一半還是 3
        XCTAssertEqual(Insights.usualRange(made, todayKey: Sample.key(20)), 3 ... 3)
    }

    func test第幾成的位置落在兩個中間照比例取() {
        XCTAssertEqual(Insights.quantile([1, 2, 3, 4], 0.5), 2.5)
        XCTAssertEqual(Insights.quantile([5], 0.75), 5)
        XCTAssertEqual(Insights.quantile([], 0.25), 0)
    }

    private func daily(_ days: ClosedRange<Int>) -> AppState {
        var every: [Int: Int] = [:]
        for day in days {
            every[day] = 4
        }
        return state(every)
    }

    func test每天用的人隔四天回來算斷了一陣子隔三天不算() {
        let made = daily(1 ... 16)
        XCTAssertTrue(Insights.cameBack(made, todayKey: Sample.key(20)))
        XCTAssertFalse(Insights.cameBack(made, todayKey: Sample.key(19)))
    }

    func test本來就隔幾天用一次的人不算() {
        let made = state([1: 2, 4: 2, 7: 2, 10: 2, 13: 2, 16: 2])
        XCTAssertFalse(Insights.cameBack(made, todayKey: Sample.key(21)))
    }

    func test用不到十四天不判斷一筆都沒有也不算() {
        XCTAssertFalse(Insights.cameBack(state([10: 2, 11: 2]), todayKey: Sample.key(20)))
        XCTAssertFalse(Insights.cameBack(Store.blank(), todayKey: Sample.key(20)))
    }

    func test斷了一陣子回來的第一天不給範圍() {
        let made = daily(1 ... 16)
        XCTAssertEqual(Insights.usualShown(made, todayKey: Sample.key(17)), 4 ... 4)
        XCTAssertNil(Insights.usualShown(made, todayKey: Sample.key(20)))
    }
}

/// 分析的字（.analytics/07-圖表與文案.md 的字串表）。
final class InsightWordsTests: XCTestCase {
    func test你平常幾顆兩個數字一樣只寫一個() {
        XCTAssertEqual(Words.usual(4 ... 6), "你平常 4 到 6 顆")
        XCTAssertEqual(Words.usual(3 ... 3), "你平常 3 顆")
    }

    func test這個長度的結果零的不寫作廢少的列分鐘() {
        let outcome = LengthOutcome(onBell: 9, flowed: 2, doneEarly: 1, voidMinutes: [12, 18])
        XCTAssertEqual(
            Words.lengthLine(outcome, len: 25),
            "25 分鐘，最近 14 顆：響了就收 9、延長 2、提早做完 1、作廢 2。作廢的停在第 12、18 分鐘"
        )
        let many = LengthOutcome(onBell: 3, voidMinutes: [6, 9, 15, 20])
        XCTAssertEqual(
            Words.lengthLine(many, len: 25),
            "25 分鐘，最近 7 顆：響了就收 3、作廢 4。作廢的停在第 6 到 20 分鐘"
        )
    }

    func test這個長度不到五顆說還差幾顆全部響了就收另一句() {
        XCTAssertEqual(
            Words.lengthLine(LengthOutcome(onBell: 2), len: 25),
            "這個長度再 3 顆，這裡會列出它們怎麼結束的"
        )
        XCTAssertEqual(
            Words.lengthLine(LengthOutcome(onBell: 6), len: 50),
            "50 分鐘，最近 6 顆都是響了就收"
        )
    }

    func test作廢答完那一行以前的訊息寫成有人找() {
        XCTAssertEqual(Words.voidedThisWeek(2, reason: "訊息"), "這週第 2 顆因為有人找作廢。")
        XCTAssertEqual(Words.voidedThisWeek(1, reason: "其他"), "這週第 1 顆選「其他」作廢。")
        XCTAssertEqual(Words.voidLine(minute: 12, reason: "訊息", text: ""), "作廢，第 12 分鐘・有人找")
    }

    func test記一筆的計數不到五筆不分種類() {
        XCTAssertEqual(Words.jotSum(JotTally(notes: 6, pings: 3)), "這兩週記了 9 筆：念頭 6、有人找 3。")
        XCTAssertEqual(Words.jotSum(JotTally(notes: 5)), "這兩週記了 5 筆：念頭 5。")
        XCTAssertEqual(Words.jotSum(JotTally(notes: 2)), "這兩週記了 2 筆。")
    }

    func test作廢的計數有選原因的不到五顆不分原因沒選的照實寫() {
        let reasons = [
            ReasonCount(reason: "有人找", count: 3),
            ReasonCount(reason: "念頭", count: 1),
            ReasonCount(reason: "卡住", count: 1),
        ]
        XCTAssertEqual(
            Words.voidSum(JotTally(reasons: reasons, unfilled: 1)),
            "作廢 6 顆：有人找 3、念頭 1、卡住 1、沒選 1。"
        )
        let few = [ReasonCount(reason: "有人找", count: 1)]
        XCTAssertEqual(Words.voidSum(JotTally(reasons: few, unfilled: 1)), "作廢 2 顆。")
    }

    func test沒寫字的那幾筆合成一行當天小計寫幾小時幾分() {
        XCTAssertEqual(
            Words.jotLines(.pings, ["客戶問報價", "", ""]),
            ["有人找：客戶問報價", "有人找 2 次"]
        )
        XCTAssertEqual(Words.jotLines(.notes, []), [])
        XCTAssertEqual(Words.daySumLine(5, 125), "5 顆・2 小時 5 分")
    }
}
