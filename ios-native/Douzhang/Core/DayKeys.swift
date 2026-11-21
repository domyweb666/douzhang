import Foundation

extension Array {
    /// 照 key 由小到大排，一樣大的維持原本的先後（Swift 內建的排序沒有保證這一點）。
    func stableSorted(by key: (Element) -> Double) -> [Element] {
        enumerated()
            .sorted { left, right in
                let leftKey = key(left.element)
                let rightKey = key(right.element)
                return leftKey == rightKey ? left.offset < right.offset : leftKey < rightKey
            }
            .map(\.element)
    }
}

/// 日期鍵（YYYY-MM-DD，本地日期）的加減：前後幾天、所屬的週（週一起算）、前後幾個月。
/// 讀不懂的鍵（手改過的檔才會有）原樣回去，不丟例外。
enum DayKeys {
    private static let daysPerWeek = 7

    static func dateOf(_ key: String) -> Date? {
        let numbers = key.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        let parts = DateComponents(year: numbers[0], month: numbers[1], day: numbers[2])
        return Store.localCalendar().date(from: parts)
    }

    static func keyOf(_ date: Date) -> String {
        Store.dayKey(date.timeIntervalSince1970 * Params.msPerSecond)
    }

    /// 那天本地 0 點的時刻；讀不懂的鍵回 0。
    static func start(_ key: String) -> Millis {
        guard let found = dateOf(key) else { return 0 }
        return found.timeIntervalSince1970 * Params.msPerSecond
    }

    /// 往前或往後幾天的日期鍵。
    static func shift(_ key: String, days: Int) -> String {
        guard let found = dateOf(key), let moved = Store.localCalendar().date(
            byAdding: .day,
            value: days,
            to: found
        ) else {
            return key
        }
        return keyOf(moved)
    }

    /// 往前或往後幾個月的 1 號。
    static func shiftMonth(_ key: String, months: Int) -> String {
        guard let found = dateOf(key) else { return key }
        let calendar = Store.localCalendar()
        var parts = calendar.dateComponents([.year, .month], from: found)
        parts.day = 1
        guard let first = calendar.date(from: parts), let moved = calendar.date(
            byAdding: .month,
            value: months,
            to: first
        ) else {
            return key
        }
        return keyOf(moved)
    }

    /// 星期幾：週一是 0、週日是 6。讀不懂的鍵回 0。
    static func weekdayIndex(_ key: String) -> Int {
        guard let found = dateOf(key) else { return 0 }
        // 系統的星期日是 1、星期六是 7；加 5 再除以 7 取餘數，週一就變成 0
        let weekday = Store.localCalendar().component(.weekday, from: found)
        return (weekday + 5) % daysPerWeek
    }

    /// 這一天所屬的週（週一起算）的週一。
    static func weekStart(_ key: String) -> String {
        shift(key, days: -weekdayIndex(key))
    }

    /// 這週七天的日期鍵（週一到週日）。
    static func weekDays(_ weekStart: String) -> [String] {
        (0 ..< daysPerWeek).map { shift(weekStart, days: $0) }
    }

    /// 往前或往後幾週的週一。
    static func shiftWeek(_ weekStart: String, weeks: Int) -> String {
        shift(weekStart, days: weeks * daysPerWeek)
    }
}
