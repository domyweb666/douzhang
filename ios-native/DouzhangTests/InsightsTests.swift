@testable import Douzhang
import XCTest

/// 分析頁的假資料：十一月的番茄與作廢。番茄帶時區（格式 v2 之後的樣子）。
enum Sample {
    static let zone = "Asia/Taipei"

    static func key(_ day: Int) -> String {
        String(format: "2026-11-%02d", day)
    }

    static func bean(
        _ day: Int,
        _ hour: Int,
        len: Double = 25,
        flow: Double = 0,
        done: Bool = false,
        typeId: String = "t1"
    ) -> Bean {
        var made = November.bean(day, hour, 0, len: len, typeId: typeId, flow: flow)
        made.zone = zone
        made.done = done
        return made
    }

    static func voided(
        _ day: Int,
        _ hour: Int,
        minute: Int,
        reason: String = "",
        len: Double? = 25
    ) -> VoidEntry {
        let start = Moment.local(2026, 11, day, hour)
        return VoidEntry(
            voidedAt: start + Double(minute) * Moment.minute,
            typeId: "t1",
            minute: minute,
            reason: reason,
            text: "",
            start: start,
            zone: zone,
            len: len
        )
    }

    /// 那一天收了幾顆（九點起一小時一顆）。
    static func day(_ day: Int, beans: Int) -> DayRecord {
        DayRecord(beans: (0 ..< beans).map { bean(day, 9 + $0) }, voids: [])
    }
}

/// 指標字典 M2：這個長度最近幾筆怎麼結束。
final class LengthOutcomeTests: XCTestCase {
    private let now = Moment.local(2026, 11, 20, 12)
    private let type = Store.defaultType

    private func outcome(_ day: DayRecord, key: String = Sample.key(18)) -> LengthOutcome {
        var state = Store.blank()
        state.days[key] = day
        return Insights.lengthOutcome(state, type: type, now: now)
    }

    func test四種結束一筆只算一種延長排在提早做完前面() {
        let both = Sample.bean(18, 12, flow: 15, done: true)
        let day = DayRecord(
            beans: [
                Sample.bean(18, 9),
                Sample.bean(18, 10, flow: 15),
                Sample.bean(18, 11, done: true),
                both,
            ],
            voids: [Sample.voided(18, 14, minute: 18), Sample.voided(18, 15, minute: 12)]
        )
        let result = outcome(day)
        XCTAssertEqual(result.onBell, 1)
        XCTAssertEqual(result.flowed, 2)
        XCTAssertEqual(result.doneEarly, 1)
        XCTAssertEqual(result.voidMinutes, [12, 18])
        XCTAssertEqual(result.total, 6)
    }

    func test別的標籤別的長度不算() {
        let day = DayRecord(
            beans: [Sample.bean(18, 9, typeId: "t2"), Sample.bean(18, 10, len: 50)],
            voids: [Sample.voided(18, 14, minute: 9, len: 50)]
        )
        XCTAssertEqual(outcome(day).total, 0)
    }

    func test格式二之前的紀錄認不出怎麼結束的不算() {
        // 舊番茄沒有時區、舊作廢沒有原訂長度
        let day = DayRecord(
            beans: [November.bean(18, 9, 0, len: 25)],
            voids: [Sample.voided(18, 14, minute: 9, len: nil)]
        )
        XCTAssertEqual(outcome(day).total, 0)
    }

    func test超過二十八天的不算() {
        var old = Sample.bean(1, 9)
        old.start = Moment.local(2026, 10, 20, 9)
        XCTAssertEqual(outcome(DayRecord(beans: [old], voids: []), key: "2026-10-20").total, 0)
        XCTAssertEqual(outcome(Sample.day(1, beans: 2), key: Sample.key(1)).onBell, 2)
    }
}

/// 指標字典 M3：計時中記了幾筆、作廢的原因。
final class JotTallyTests: XCTestCase {
    private let now = Moment.local(2026, 11, 20, 12)

    private func tally(_ days: [Int: DayRecord]) -> JotTally {
        var state = Store.blank()
        for (day, record) in days {
            state.days[Sample.key(day)] = record
        }
        return Insights.jotTally(state, now: now)
    }

    func test沒寫字的也算一筆作廢那顆記的也算() {
        var kept = Sample.bean(18, 9)
        kept.notes = ["回信", ""]
        kept.pings = [""]
        var lost = Sample.voided(19, 10, minute: 12, reason: "訊息")
        lost.pings = ["小美"]
        let result = tally([
            18: DayRecord(beans: [kept], voids: []),
            19: DayRecord(beans: [], voids: [lost]),
        ])
        XCTAssertEqual(result.notes, 2)
        XCTAssertEqual(result.pings, 2)
        XCTAssertEqual(result.jots, 4)
        XCTAssertEqual(result.reasons, [ReasonCount(reason: "有人找", count: 1)])
        // 新的在上面
        XCTAssertEqual(result.items.map(\.dayKey), [Sample.key(19), Sample.key(18)])
        XCTAssertNotNil(result.items.first?.voided)
    }

    func test以前存的訊息跟有人找是同一種多的排前面沒選的另外數() {
        let voids = [
            Sample.voided(18, 9, minute: 6, reason: "念頭"),
            Sample.voided(18, 10, minute: 7, reason: "訊息"),
            Sample.voided(18, 11, minute: 8, reason: "有人找"),
            Sample.voided(18, 12, minute: 9),
        ]
        let result = tally([18: DayRecord(beans: [], voids: voids)])
        XCTAssertEqual(result.reasons, [
            ReasonCount(reason: "有人找", count: 2),
            ReasonCount(reason: "念頭", count: 1),
        ])
        XCTAssertEqual(result.unfilled, 1)
        XCTAssertEqual(result.reasoned, 3)
        XCTAssertEqual(result.voids, 4)
    }

    func test兩週以前的不算沒記過東西的番茄不列() {
        var early = Sample.bean(1, 9)
        early.notes = ["太早"]
        let result = tally([
            1: DayRecord(beans: [early], voids: []),
            19: Sample.day(19, beans: 2),
        ])
        XCTAssertEqual(result, JotTally())
    }

    func test這週同一個原因作廢第幾顆上週的不算沒選的沒有() {
        var state = Store.blank()
        // 11/15 是星期日（上一週），11/16 星期一、11/17 星期二
        state.days[Sample.key(15)] = DayRecord(
            beans: [],
            voids: [Sample.voided(15, 9, minute: 6, reason: "有人找")]
        )
        state.days[Sample.key(16)] = DayRecord(
            beans: [],
            voids: [Sample.voided(16, 9, minute: 6, reason: "有人找")]
        )
        state.days[Sample.key(17)] = DayRecord(beans: [], voids: [
            Sample.voided(17, 9, minute: 6, reason: "訊息"),
            Sample.voided(17, 10, minute: 6),
        ])
        let today = Sample.key(17)
        XCTAssertEqual(Insights.voidsThisWeek(state, reason: "有人找", todayKey: today), 2)
        XCTAssertNil(Insights.voidsThisWeek(state, reason: "", todayKey: today))
        XCTAssertNil(Insights.voidsThisWeek(state, reason: "卡住", todayKey: today))
    }
}
