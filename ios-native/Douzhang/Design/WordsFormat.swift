import Foundation

/// 帶數字、日期的句子。翻自 Expo 版 design/words.js 裡的函式。
extension Words {
    private static let minutesPerHour = 60
    private static let secondsPerMinute = 60.0
    private static let noon = 12
    private static let evening = 18

    /// 數字照原樣寫：25 寫成 25，12.5 寫成 12.5。
    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    /// 一顆多長：不到一分鐘的只有開發期的測試顆，寫秒。
    static func typeLen(_ len: Double) -> String {
        len < 1 ? "\(Int((len * secondsPerMinute).rounded())) 秒" : "\(number(len)) 分"
    }

    /// 主畫面最上面那顆膠囊：「專注・25 分」；待機時可點，後面多一個 ›。
    static func tagLabel(_ type: TagType, more: Bool = false) -> String {
        "\(type.name)・\(typeLen(type.len))" + (more ? " \(chevron)" : "")
    }

    /// 待機開始鈕的字：「開始・25 分」。
    static func startLabel(_ len: Double) -> String {
        "\(start)・\(number(len)) 分"
    }

    static func startTest(_ len: Double) -> String {
        "開始測試・\(typeLen(len))"
    }

    static func flowMore(_ minutes: Int) -> String {
        "再做 \(minutes) 分"
    }

    static func todayKept(_ count: Int) -> String {
        "今天收了 \(count) 顆"
    }

    static func rangAgo(_ minutes: Int) -> String {
        "響了 \(minutes) 分鐘前。收下後直接回待機。"
    }

    static func zenScreenA11y(_ time: String) -> String {
        "聚焦模式，剩 \(time)。點兩下顯示按鈕"
    }

    static func tomatoColorName(_ color: TomatoColor) -> String {
        switch color {
        case .red: "紅番茄"
        case .orange: "橘番茄"
        case .yellow: "黃番茄"
        case .purple: "紫番茄"
        case .pink: "粉番茄"
        }
    }

    static func minutes(_ value: Int) -> String {
        "\(value) 分"
    }

    static func restLongEvery(_ every: Int) -> String {
        "每 \(every) 顆"
    }

    static func restLongValue(_ every: Int, _ minutes: Int) -> String {
        "每 \(every) 顆・\(minutes) 分"
    }

    static func restLongSub(_ every: Int, _ minutes: Int) -> String {
        "今天每收下 \(every) 顆，那次休息 \(minutes) 分。"
    }

    static func shieldAppsCount(_ count: Int) -> String {
        "\(count) 項"
    }

    static func lastAutoBackup(_ when: String) -> String {
        "上次自動備份：\(when)"
    }

    static func ambienceKind(_ kind: AmbienceKind) -> String {
        switch kind {
        case .off: "關"
        case .rain: "雨"
        case .fire: "柴火"
        }
    }

    /// 主畫面那顆聲音鈕上的字：選了哪一種。
    static func ambienceChip(_ kind: AmbienceKind) -> String {
        "♪ " + (kind == .off ? ambienceTitle : ambienceKind(kind))
    }

    static func ambienceLevel(_ level: AmbienceLevel) -> String {
        switch level {
        case .low: "小"
        case .mid: "中"
        case .high: "大"
        }
    }

    static func moreBeans(_ count: Int) -> String {
        "+\(count)"
    }

    static func beansCount(_ count: Int) -> String {
        "\(count) 顆"
    }

    /// 多久：不到一小時寫分，滿一小時寫「幾小時 幾分」。
    static func duration(_ minutes: Double) -> String {
        let whole = Int(minutes.rounded())
        if whole < minutesPerHour {
            return "\(whole) 分"
        }
        let rest = whole % minutesPerHour
        return "\(whole / minutesPerHour) 小時" + (rest > 0 ? " \(rest) 分" : "")
    }

    static func daySumLine(_ beans: Int, _ minutes: Double) -> String {
        "\(beans) 顆・\(Int(minutes.rounded())) 分"
    }

    static func blockTitle(_ name: String, len: Double, flow: Double) -> String {
        "\(name)・\(typeLen(len))" + (flow > 0 ? "＋\(number(flow))" : "")
    }

    /// 時間軸左邊的整點：半夜 12、上午 9、中午 12、下午 3、晚上 8。
    static func hourLabel(_ hour: Int) -> String {
        if hour == 0 {
            return "半夜 12"
        }
        if hour < noon {
            return "上午 \(hour)"
        }
        if hour == noon {
            return "中午 12"
        }
        return hour < evening ? "下午 \(hour - noon)" : "晚上 \(hour - noon)"
    }

    /// 日期鍵 → 「11月17日」。讀不懂的鍵原樣寫。
    static func monthDay(_ key: String) -> String {
        guard let date = DayKeys.dateOf(key) else { return key }
        let parts = Store.localCalendar().dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)月\(parts.day ?? 0)日"
    }

    /// 日期鍵 → 「星期二」。
    static func weekday(_ key: String) -> String {
        "星期" + weekdayShort[DayKeys.weekdayIndex(key)]
    }

    /// 日期鍵 → 「2026年11月」。
    static func monthTitle(_ key: String) -> String {
        guard let date = DayKeys.dateOf(key) else { return key }
        let parts = Store.localCalendar().dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)年\(parts.month ?? 0)月"
    }

    static func daysRange(_ from: String, _ upTo: String) -> String {
        "\(monthDay(from))–\(monthDay(upTo))"
    }

    static func weekOf(_ key: String) -> String {
        "\(monthDay(key)) 那週"
    }

    static func dayTitle(_ key: String) -> String {
        "\(monthDay(key)) \(weekday(key))"
    }

    static func dayA11y(_ key: String, hasRecord: Bool) -> String {
        dayTitle(key) + (hasRecord ? "，有紀錄" : "")
    }

    static func monthDayA11y(_ key: String, beans: Int, leaf: Bool) -> String {
        dayTitle(key) + (beans > 0 ? "，\(beans) 顆" : "") + (leaf ? "，\(leafA11y)" : "")
    }

    static func dayReceiptTitle(_ key: String) -> String {
        "\(monthDay(key))的收據"
    }

    static func flowMark(_ minutes: Double) -> String {
        "延長 \(number(minutes)) 分"
    }

    /// 念頭一撇、有人找一橫。
    static func jotMark(notes: Int, pings: Int) -> String {
        String(repeating: "′", count: notes) + String(repeating: "–", count: pings)
    }

    static func voidLine(minute: Int, reason: String, text: String) -> String {
        let why = reason.isEmpty ? "" : "・\(reason)"
        let note = text.isEmpty ? "" : "：\(text)"
        return "作廢，第 \(minute) 分鐘" + why + note
    }
}
