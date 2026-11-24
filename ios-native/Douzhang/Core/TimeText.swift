import Foundation

/// 時間怎麼寫成字。倒數都用「結束時刻 − 現在」算，不另外存剩幾秒。
enum TimeText {
    private static let secondsPerMinute = 60

    private static func wholeSeconds(_ remaining: Millis) -> Int {
        max(0, Int((remaining / Params.msPerSecond).rounded(.up)))
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// 剩餘毫秒 →「m:ss」，不足 0 顯示 0:00。
    static func mmss(_ remaining: Millis) -> String {
        let total = wholeSeconds(remaining)
        return "\(total / secondsPerMinute):\(twoDigits(total % secondsPerMinute))"
    }

    /// 剩餘毫秒 → 分、秒各一串（聚焦模式的兩個大數字；跟 mmss 同一種進位，分鐘補到兩位）。
    static func clockParts(_ remaining: Millis) -> (minutes: String, seconds: String) {
        let total = wholeSeconds(remaining)
        return (twoDigits(total / secondsPerMinute), twoDigits(total % secondsPerMinute))
    }

    /// 時刻 →「HH:MM」（收據用，本地時間）。
    static func hhmm(_ time: Millis) -> String {
        let parts = Store.localCalendar().dateComponents([.hour, .minute], from: Store.date(time))
        return "\(twoDigits(parts.hour ?? 0)):\(twoDigits(parts.minute ?? 0))"
    }

    /// 現在的毫秒時刻。
    static func nowMillis() -> Millis {
        Date().timeIntervalSince1970 * Params.msPerSecond
    }
}
