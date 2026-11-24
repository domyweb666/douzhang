import Foundation

/// 帶數字、日期的句子。翻自 Expo 版 design/words.js 裡的函式。
extension Words {
    private static let minutesPerHour = 60
    private static let secondsPerMinute = 60.0
    private static let noon = 12
    private static let evening = 18

    /// 升級前就刪掉的標籤，名字沒留下來：番茄架與分析都這樣叫。
    static let removedTag = "已刪除的標籤"

    /// 刪掉的標籤在分析裡的名字：原本的名字後面註明。
    static func removedName(_ name: String) -> String {
        "\(name)（已刪除）"
    }

    /// 數字照原樣寫：25 寫成 25，12.5 寫成 12.5。
    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    /// 一顆多長：不到一分鐘的只有開發期的測試顆，寫秒。
    static func typeLen(_ len: Double) -> String {
        len < 1 ? "\(Int((len * secondsPerMinute).rounded())) 秒" : "\(number(len)) 分"
    }

    /// 計時中、休息最上面那顆膠囊：「專注・25 分」。
    static func tagLabel(_ type: TagType) -> String {
        "\(type.name)・\(typeLen(type.len))"
    }

    /// 計時中的膠囊有寫在做什麼時，那句後面接的長度：「・25 分」。分開寫是為了那句太長時長度不會被截掉。
    static func lenTail(_ len: Double) -> String {
        "・\(typeLen(len))"
    }

    /// 計時中記一筆那顆的讀屏值：這顆記過幾筆。
    static func jotCount(_ count: Int) -> String {
        "\(count) 筆"
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
        "響了 \(minutes) 分鐘前"
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

    /// 設定裡智能調節的算法：「專注 ÷ 5，每滿 100 分 +10」。
    static var restSmartValue: String {
        let part = number(Params.SmartRest.divisor)
        let every = number(Params.SmartRest.bonusEvery)
        return "專注 ÷ \(part)，每滿 \(every) 分 +\(Params.SmartRest.bonusMinutes)"
    }

    static func shieldAppsCount(_ count: Int) -> String {
        "\(count) 項"
    }

    static func lastAutoBackup(_ when: String) -> String {
        "自動備份 \(when)"
    }

    static func ambienceKind(_ kind: AmbienceKind) -> String {
        switch kind {
        case .off: "關"
        case .rain: "雨"
        case .fire: "柴火"
        }
    }

    /// 背景音鈕上的字：現在播的那個，關著寫「背景音」。
    static func ambienceChip(_ kind: AmbienceKind) -> String {
        kind == .off ? ambienceTitle : ambienceKind(kind)
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

    /// 鈴響收據「今天」下面的總數：番茄還排一行時不寫。
    static func todayTotal(_ count: Int) -> String? {
        count >= Params.todayTotalFrom ? beansCount(count) : nil
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
        "\(beans) 顆・\(duration(minutes))"
    }

    static func blockTitle(_ name: String, len: Double, flow: Double) -> String {
        "\(name)・" + lenWithFlow(len, flow: flow)
    }

    /// 這顆多長：「25 分」，延長過是「25 分＋15」。
    static func lenWithFlow(_ len: Double, flow: Double) -> String {
        typeLen(len) + (flow > 0 ? "＋\(number(flow))" : "")
    }

    /// 鈴響收據上的起訖：「08:11–08:36」。
    static func clockRange(_ from: Millis, _ upTo: Millis) -> String {
        "\(TimeText.hhmm(from))–\(TimeText.hhmm(upTo))"
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

    /// 有寫在做什麼就放最前面。
    static func voidLine(
        minute: Int,
        reason: String,
        text: String,
        doing: String = ""
    ) -> String {
        let head = doing.isEmpty ? "" : "\(doing)・"
        let why = reason.isEmpty ? "" : "・\(voidReason(reason))"
        let note = text.isEmpty ? "" : "：\(text)"
        return head + "作廢，第 \(minute) 分鐘" + why + note
    }

    /// 月檢視清單的標題：「這個月做了什麼」，翻到以前的月份是「10月做了什麼」。
    static func doneTitle(_ key: String, todayKey: String) -> String {
        let isThisMonth = DayKeys.shiftMonth(key, months: 0)
            == DayKeys.shiftMonth(todayKey, months: 0)
        guard !isThisMonth, let date = DayKeys.dateOf(key) else { return "\(thisMonth)做了什麼" }
        return "\(Store.localCalendar().component(.month, from: date))月做了什麼"
    }

    /// 月檢視清單的主字：最多列幾個，再多寫「等」。
    static func doneNames(_ names: [String]) -> String {
        let more = names.count > Params.monthDoneNames ? "等" : ""
        return names.prefix(Params.monthDoneNames).joined(separator: "、") + more
    }

    /// 月檢視清單日期塊下面的字：「週二」。
    static func weekdayCompact(_ key: String) -> String {
        "週" + weekdayShort[DayKeys.weekdayIndex(key)]
    }

    /// 月檢視清單一張卡讀屏念的那一句。
    static func doneA11y(_ day: DoneDay) -> String {
        let sum = daySumLine(day.sum.beans, day.sum.minutes)
        return [dayTitle(day.key), doneNames(day.names), sum, day.clue]
            .filter { !$0.isEmpty }
            .joined(separator: "，")
    }
}
