@testable import Douzhang
import XCTest

/// 改之前的 jotTally：把全部格子做成清單再篩。只拿來對答案，新寫法只翻最近那幾格，結果要一模一樣。
enum WholeYearJotTally {
    static func tally(_ state: AppState, now: Millis) -> JotTally {
        let since = now - Params.Insight.jotDays * 24 * Params.msPerHour
        let items = state.days
            .flatMap { entry in jotItems(entry.value, key: entry.key) }
            .filter { $0.start >= since }
        var tally = JotTally()
        var found: [String: Int] = [:]
        for item in items {
            tally.notes += item.notes.count
            tally.pings += item.pings.count
            guard let entry = item.voided else { continue }
            if entry.reason.isEmpty {
                tally.unfilled += 1
            } else {
                found[Words.voidReason(entry.reason), default: 0] += 1
            }
        }
        tally.reasons = ordered(found)
        tally.items = items.stableSorted { -$0.start }
        return tally
    }

    private static func jotItems(_ day: DayRecord, key: String) -> [JotItem] {
        let beans = day.beans.filter { !$0.notes.isEmpty || !$0.pings.isEmpty }.map { bean in
            JotItem(
                start: bean.start ?? bean.keptAt,
                dayKey: key,
                typeId: bean.typeId,
                notes: bean.notes,
                pings: bean.pings
            )
        }
        let voids = day.voids.map { entry in
            JotItem(
                start: entry.start ?? entry.voidedAt - Double(entry.minute) * Params.msPerMinute,
                dayKey: key,
                typeId: entry.typeId,
                notes: entry.notes,
                pings: entry.pings,
                voided: entry
            )
        }
        return beans + voids
    }

    private static func ordered(_ found: [String: Int]) -> [ReasonCount] {
        let extra = found.keys.filter { !Words.voidReasons.contains($0) }.sorted()
        let all = (Words.voidReasons + extra).compactMap { reason in
            found[reason].map { ReasonCount(reason: reason, count: $0) }
        }
        return all.stableSorted { -Double($0.count) }
    }
}

/// 造資料：每筆照 app 的放法放進格子（有時區的照開始那刻、當時的時區；沒時區的舊紀錄照收下那天）。
enum JotWindowSample {
    /// UTC+14、UTC−12 是兩個最遠的時區
    static let zones: [String?] = [
        nil, "Asia/Taipei", "Pacific/Kiritimati", "Etc/GMT+12", "Europe/London",
        "America/Los_Angeles",
    ]
    static let reasons = ["", "念頭", "訊息", "有人找", "卡住", "其他", "手寫的"]

    static func put(_ bean: Bean, in state: inout AppState) {
        let key = StateUpgrade.home(bean.start, zone: bean.zone) ?? Store.dayKey(bean.keptAt)
        state.days[key, default: DayRecord()].beans.append(bean)
    }

    static func put(_ entry: VoidEntry, in state: inout AppState) {
        let key = StateUpgrade.home(entry.start, zone: entry.zone) ?? Store.dayKey(entry.voidedAt)
        state.days[key, default: DayRecord()].voids.append(entry)
    }

    static func bean(start: Millis, zone: String?, notes: [String], pings: [String]) -> Bean {
        Bean(
            keptAt: start + 25 * Moment.minute,
            typeId: "t1",
            len: 25,
            clue: "",
            notes: notes,
            pings: pings,
            flow: 0,
            start: zone == nil ? nil : start,
            zone: zone
        )
    }

    static func voided(start: Millis, zone: String?, minute: Int, reason: String) -> VoidEntry {
        VoidEntry(
            voidedAt: start + Double(minute) * Moment.minute,
            typeId: "t2",
            minute: minute,
            reason: reason,
            text: "",
            start: zone == nil ? nil : start,
            zone: zone,
            len: 25,
            notes: minute.isMultiple(of: 3) ? ["想到的"] : [],
            pings: minute.isMultiple(of: 4) ? [""] : []
        )
    }
}

/// 固定種子的亂數：每次跑出來的資料都一樣。
struct SeededNumbers {
    private var value: UInt64

    init(seed: UInt64) {
        value = seed
    }

    mutating func next(_ upper: Int) -> Int {
        value = value &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((value >> 33) % UInt64(upper))
    }
}

/// jotTally 只翻最近那幾格（效能審查乙2）：各種資料下跟整份翻的舊寫法結果一模一樣。
final class JotWindowTests: XCTestCase {
    private let day = 24 * Params.msPerHour

    private func assertSame(
        _ state: AppState,
        now: Millis,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected = WholeYearJotTally.tally(state, now: now)
        XCTAssertEqual(Insights.jotTally(state, now: now), expected, file: file, line: line)
    }

    /// 一整年、每天幾顆到十幾顆，時區、原因、有沒有記東西都混著。
    private func year(seed: UInt64, now: Millis) -> AppState {
        var numbers = SeededNumbers(seed: seed)
        var state = Store.blank()
        for back in 0 ..< 370 {
            for _ in 0 ..< numbers.next(14) {
                let start = now - Double(back) * day - Double(numbers.next(24 * 60)) * Moment.minute
                let zone = JotWindowSample.zones[numbers.next(JotWindowSample.zones.count)]
                if numbers.next(3) == 0 {
                    let reasons = JotWindowSample.reasons
                    let reason = reasons[numbers.next(reasons.count)]
                    let entry = JotWindowSample.voided(
                        start: start, zone: zone, minute: 1 + numbers.next(24), reason: reason
                    )
                    JotWindowSample.put(entry, in: &state)
                } else {
                    let notes = Array(repeating: "念頭", count: numbers.next(3))
                    let pings = Array(repeating: "", count: numbers.next(2))
                    let bean = JotWindowSample.bean(
                        start: start, zone: zone, notes: notes, pings: pings
                    )
                    JotWindowSample.put(bean, in: &state)
                }
            }
        }
        return state
    }

    func test沒資料() {
        assertSame(Store.blank(), now: Moment.local(2026, 11, 20, 12))
    }

    func test一整年混著各時區跟整份翻一樣() {
        let moments = [
            Moment.local(2026, 11, 20, 12),
            Moment.local(2026, 11, 20, 0),
            Moment.local(2026, 11, 20, 23, 59),
            Moment.local(2026, 3, 29, 2, 30),
            Moment.local(2027, 1, 1, 0, 5),
        ]
        for (index, now) in moments.enumerated() {
            let state = year(seed: UInt64(index + 1), now: now)
            let result = Insights.jotTally(state, now: now)
            // 不是空對空：真的有東西可比
            XCTAssertFalse(result.items.isEmpty)
            XCTAssertGreaterThan(result.voids, 0)
            assertSame(state, now: now)
        }
    }

    func test剛好第十四天的邊界() {
        let now = Moment.local(2026, 11, 20, 12)
        let since = now - Params.Insight.jotDays * day
        var state = Store.blank()
        for zone in JotWindowSample.zones {
            for offset in [-1.0, 0, 1] {
                let start = since + offset
                JotWindowSample.put(
                    JotWindowSample.bean(start: start, zone: zone, notes: ["邊界"], pings: []),
                    in: &state
                )
                JotWindowSample.put(
                    JotWindowSample.voided(start: start, zone: zone, minute: 6, reason: "念頭"),
                    in: &state
                )
            }
        }
        let result = Insights.jotTally(state, now: now)
        // 有時區的五種：since 那一刻與之後一毫秒的番茄、作廢各兩筆＝20。
        // 沒時區的舊紀錄：番茄照收下那刻算（25 分鐘後，三筆都算）、作廢照作廢那刻往回推（兩筆）＝5
        XCTAssertEqual(result.items.count, 25)
        assertSame(state, now: now)
    }

    func test跨午夜開始的那顆放在前一天也算得到() {
        let now = Moment.local(2026, 11, 20, 0, 10)
        let since = now - Params.Insight.jotDays * day
        var state = Store.blank()
        // since 是 11/6 00:10：前一天 23:55 開始的不算、00:10 之後開始的算；收下都在 11/6
        let before = Moment.local(2026, 11, 5, 23, 55)
        let after = Moment.local(2026, 11, 6, 0, 15)
        for start in [before, since, after] {
            for zone in JotWindowSample.zones {
                JotWindowSample.put(
                    JotWindowSample.bean(start: start, zone: zone, notes: [], pings: ["小美"]),
                    in: &state
                )
            }
        }
        JotWindowSample.put(
            JotWindowSample.voided(start: before, zone: nil, minute: 20, reason: ""),
            in: &state
        )
        assertSame(state, now: now)
        // 有時區的照開始那刻：since 與之後的兩顆。沒時區的照收下那刻：23:55 開始、00:20 收下的那顆也算
        let zoned = JotWindowSample.zones.count - 1
        XCTAssertEqual(Insights.jotTally(state, now: now).pings, zoned * 2 + 3)
    }

    func test最遠的兩個時區放在差兩天的格子() {
        let now = Moment.local(2026, 11, 20, 12)
        let since = now - Params.Insight.jotDays * day
        var state = Store.blank()
        for zone in ["Pacific/Kiritimati", "Etc/GMT+12"] {
            for hours in [-30.0, -26, -12, -1, 0, 1, 12, 26, 30] {
                let start = since + hours * Params.msPerHour
                JotWindowSample.put(
                    JotWindowSample.voided(start: start, zone: zone, minute: 3, reason: "卡住"),
                    in: &state
                )
            }
        }
        // 同一刻開始的兩筆（不同格子）：排出來的先後也要一樣
        JotWindowSample.put(
            JotWindowSample.bean(start: since, zone: "Asia/Taipei", notes: ["同一刻"], pings: []),
            in: &state
        )
        assertSame(state, now: now)
    }
}
