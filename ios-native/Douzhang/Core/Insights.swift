import Foundation

/// 一個標籤用現在這個長度，最近幾筆各是怎麼結束的（指標字典 M2）。一筆只算一種。
struct LengthOutcome: Equatable {
    var onBell = 0
    var flowed = 0
    var doneEarly = 0
    /// 作廢的各停在第幾分鐘，由小到大
    var voidMinutes: [Int] = []

    var total: Int {
        onBell + flowed + doneEarly + voidMinutes.count
    }
}

/// 一個作廢原因幾顆。
struct ReasonCount: Equatable {
    var reason: String
    var count: Int
}

/// 清單上的一顆：計時中記過東西的番茄，或一筆作廢。
struct JotItem: Equatable {
    var start: Millis
    var dayKey: String
    var typeId: String
    var notes: [String]
    var pings: [String]
    var voided: VoidEntry?
}

/// 最近兩週計時中記了幾筆、作廢各是什麼原因（M3）。
struct JotTally: Equatable {
    var notes = 0
    var pings = 0
    /// 有選原因的作廢，多的在前面；一樣多的照畫面上選項的順序
    var reasons: [ReasonCount] = []
    /// 沒選原因的作廢
    var unfilled = 0
    /// 新的在上面
    var items: [JotItem] = []

    var jots: Int {
        notes + pings
    }

    var reasoned: Int {
        reasons.reduce(0) { $0 + $1.count }
    }

    var voids: Int {
        reasoned + unfilled
    }
}

/// 番茄帳 分析頁的新數字（.analytics/05-指標字典.md 的 M2、M3、M7、M8）。純函式，只讀不寫。
/// 都只給計數與範圍，不下結論、不跟別人比；視窗與門檻在 Params.Insight。
enum Insights {
    private static let msPerDay = 24 * Params.msPerHour

    /// 兩個日期鍵差幾天（後面減前面）。
    static func daysBetween(_ from: String, _ until: String) -> Int {
        Int(((DayKeys.start(until) - DayKeys.start(from)) / msPerDay).rounded())
    }

    // MARK: M2 這個長度的結果

    /// 這個標籤、現在這個長度，最近 lengthDays 天的紀錄各怎麼結束。順序：作廢 → 延長 → 提早做完 → 響了就收。
    static func lengthOutcome(_ state: AppState, type: TagType, now: Millis) -> LengthOutcome {
        let since = now - Params.Insight.lengthDays * msPerDay
        var outcome = LengthOutcome()
        for day in state.days.values {
            for bean in day.beans where counts(bean, type: type, since: since) {
                if bean.flow > 0 {
                    outcome.flowed += 1
                } else if bean.done {
                    outcome.doneEarly += 1
                } else {
                    outcome.onBell += 1
                }
            }
            for entry in day.voids where counts(entry, type: type, since: since) {
                outcome.voidMinutes.append(entry.minute)
            }
        }
        outcome.voidMinutes.sort()
        return outcome
    }

    /// 格式 v2 之前的番茄沒存有沒有提早做完，認不出是哪一種就不算；v2 起每顆都帶時區，拿它來認。
    private static func counts(_ bean: Bean, type: TagType, since: Millis) -> Bool {
        bean.typeId == type.id && bean.len == type.len && bean.zone != nil
            && (bean.start ?? bean.keptAt) >= since
    }

    /// 格式 v2 之前的作廢沒存原訂長度（len 是空的），對不上就不算。
    private static func counts(_ entry: VoidEntry, type: TagType, since: Millis) -> Bool {
        entry.typeId == type.id && entry.len == type.len
            && (entry.start ?? entry.voidedAt) >= since
    }

    // MARK: M3 記了幾筆、作廢的原因

    /// 最近 jotDays 天：每顆（收下與作廢都算）記的念頭與有人找各幾筆，作廢的原因各幾顆。
    /// 沒寫字的也算一筆；以前存的「訊息」當成「有人找」。
    static func jotTally(_ state: AppState, now: Millis) -> JotTally {
        let since = now - Params.Insight.jotDays * msPerDay
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

    /// 一天裡要列出來的：記過東西的番茄、每一筆作廢。
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

    /// 多的在前面；一樣多的照畫面上選項的順序，手改出來的其他原因排最後。
    private static func ordered(_ found: [String: Int]) -> [ReasonCount] {
        let extra = found.keys.filter { !Words.voidReasons.contains($0) }.sorted()
        let all = (Words.voidReasons + extra).compactMap { reason in
            found[reason].map { ReasonCount(reason: reason, count: $0) }
        }
        return all.stableSorted { -Double($0.count) }
    }

    /// 這週（週一起算）同一個原因作廢了幾顆，含剛剛那一筆。沒選原因、或這週沒有，回 nil。
    static func voidsThisWeek(_ state: AppState, reason: String, todayKey: String) -> Int? {
        let shown = Words.voidReason(reason)
        guard !shown.isEmpty else { return nil }
        let keys = DayKeys.weekDays(DayKeys.weekStart(todayKey))
        let same = keys.flatMap { state.days[$0]?.voids ?? [] }
            .filter { Words.voidReason($0.reason) == shown }
        return same.isEmpty ? nil : same.count
    }

    // MARK: M7 你平常幾顆、M8 斷了一陣子

    /// 今天之前 usualDays 天裡，有開始番茄的日子各收幾顆，取中間那一半的範圍。
    /// 只作廢、沒收下的日子算 0 顆；完全沒開的日子不算。日子不夠回 nil。今天不算進去。
    static func usualRange(_ state: AppState, todayKey: String) -> ClosedRange<Int>? {
        let perDay = (1 ... Params.Insight.usualDays).compactMap { back -> Double? in
            let day = state.days[DayKeys.shift(todayKey, days: -back)]
            return Receipt.hasRecord(day) ? Double(day?.beans.count ?? 0) : nil
        }
        guard perDay.count >= Params.Insight.usualMinDays else { return nil }
        let sorted = perDay.sorted()
        let low = Int(quantile(sorted, Params.Insight.usualLow).rounded())
        let high = Int(quantile(sorted, Params.Insight.usualHigh).rounded())
        return low ... max(low, high)
    }

    /// 排好的數字裡第幾成的位置；落在兩個中間就照比例取。
    static func quantile(_ sorted: [Double], _ share: Double) -> Double {
        guard let last = sorted.last else { return 0 }
        let spot = share * Double(sorted.count - 1)
        let index = Int(spot)
        let next = index + 1 < sorted.count ? sorted[index + 1] : last
        return sorted[index] + (next - sorted[index]) * (spot - Double(index))
    }

    /// 斷了一陣子才回來：今天之前最後一筆離今天的天數，超過她最近最長那次間隔的兩倍，而且至少 backMinGap 天。
    /// 用不到 backMinUse 天不判斷。只用來決定要不要顯示「你平常幾顆」，自己不顯示。
    static func cameBack(_ state: AppState, todayKey: String) -> Bool {
        let keys = state.days
            .filter { Receipt.hasRecord($0.value) && $0.key < todayKey }
            .keys.sorted()
        guard let first = keys.first, let last = keys.last,
              daysBetween(first, todayKey) >= Params.Insight.backMinUse else { return false }
        let gap = daysBetween(last, todayKey)
        let recent = keys.filter { daysBetween($0, last) < Params.Insight.backWindow }
        let longest = zip(recent, recent.dropFirst()).map { daysBetween($0, $1) }.max() ?? 1
        return gap > longest * 2 && gap >= Params.Insight.backMinGap
    }

    /// 鈴響頁第二行要不要出現：日子夠、而且不是斷了一陣子回來的第一天。
    static func usualShown(_ state: AppState, todayKey: String) -> ClosedRange<Int>? {
        cameBack(state, todayKey: todayKey) ? nil : usualRange(state, todayKey: todayKey)
    }
}
