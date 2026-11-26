import Foundation

/// 收下這顆之後休息多久、是不是長休息。
struct RestPlan: Equatable {
    var minutes: Int
    var long: Bool
}

/// 番茄帳 資料層的算法：空白狀態、日期鍵、一顆幾單位、休息多久。純函式，不碰檔案。
enum Store {
    /// 2＝每筆有編號與時區、刪掉的標籤另外留著；3＝標籤帶幾時改過（.analytics/04-資料結構.md）。
    /// 舊版讀得進去，只是不認得新欄位
    static let formatVersion = 3
    /// 一顆＝25 分；50 分的顆算兩單位
    static let minutesPerUnit = 25.0
    /// 「跟著長度」的休息＝長度 ÷ 5，最少 3 分
    static let restDivisor = 5.0
    static let restMinMinutes = 3
    static let defaultRestLongEvery = 4
    static let defaultRestLongMinutes = 15

    /// 新安裝的五個標籤。第一個是 t1、25 分：缺標籤時補的、選到不存在的標籤時退回的都是它
    static let presetTypes: [TagType] = Words.presetTags.indices.map { index in
        TagType(
            id: "t\(index + 1)",
            name: Words.presetTags[index],
            len: Params.presetLengths[index],
            color: Params.presetColors[index]
        )
    }

    static let defaultType = presetTypes[0]

    static func blankSettings() -> AppSettings {
        AppSettings(
            types: presetTypes,
            typeId: defaultType.id,
            restMode: .auto,
            sound: true,
            demo: false,
            tilt: true,
            restShort: .auto,
            restLongEvery: defaultRestLongEvery,
            restLongMinutes: defaultRestLongMinutes,
            shield: false,
            ambience: .off,
            ambienceVolume: .mid,
            autoNext: false
        )
    }

    static func blank() -> AppState {
        AppState(settings: blankSettings(), current: nil, days: [:], lastLine: -1)
    }

    /// 共用的那一份西曆：新建一份不便宜，月檢視一次重算就要建上百份（效能審查乙3）。
    /// 時區跟上次拿的不一樣才換（手機換時區、出國）；開機在背景讀檔時也會拿，所以上鎖。
    final class SharedCalendar: @unchecked Sendable {
        private let lock = NSLock()
        private var stored = Calendar(identifier: .gregorian)

        init(zone: TimeZone) {
            stored.timeZone = zone
        }

        func calendar(in zone: TimeZone) -> Calendar {
            lock.withLock {
                if stored.timeZone != zone {
                    stored.timeZone = zone
                }
                return stored
            }
        }
    }

    private static let sharedCalendar = SharedCalendar(zone: TimeZone.current)

    /// 一律用西曆算日期。手機設成民國曆或佛曆時，日期鍵也要跟 Expo 版同一種寫法，舊資料才對得上。
    /// 每次都照手機現在的時區：比一下就好，不用等系統換時區的通知。
    static func localCalendar() -> Calendar {
        sharedCalendar.calendar(in: TimeZone.current)
    }

    static func date(_ time: Millis) -> Date {
        Date(timeIntervalSince1970: time / Params.msPerSecond)
    }

    /// 本地日期鍵 YYYY-MM-DD（本地時區，不是 UTC）。
    /// zone 是那筆紀錄開始時的時區名：有就照它算（出國那幾天不會歪），沒有就照手機現在的時區。
    /// 一天從 Params.dayStartHour 點開始；「哪一天」每次讀檔都重算，改了這個數字不用動資料。
    static func dayKey(_ time: Millis, zone: String? = nil) -> String {
        var calendar = localCalendar()
        // 跟手機同一區的（幾乎每一筆）不換，換一次時區就要多建一份日曆
        if let zone, zone != calendar.timeZone.identifier, let known = TimeZone(identifier: zone) {
            calendar.timeZone = known
        }
        let shifted = time - Params.dayStartHour * Params.msPerHour
        let parts = calendar.dateComponents([.year, .month, .day], from: date(shifted))
        // 每讀一筆都要算一次：String(format:) 要繞一圈 NSString，自己補零寫法相同、輸出一樣
        let year = zeroPadded(parts.year ?? 0, width: 4)
        return year + "-" + zeroPadded(parts.month ?? 0, width: 2) + "-"
            + zeroPadded(parts.day ?? 0, width: 2)
    }

    /// 跟 String(format: "%0Nd") 一樣：補零到 width 位，負號也算一位。
    static func zeroPadded(_ number: Int, width: Int) -> String {
        let digits = String(number.magnitude)
        let sign = number < 0 ? "-" : ""
        let zeros = String(repeating: "0", count: max(0, width - sign.count - digits.count))
        return sign + zeros + digits
    }

    /// 一顆番茄自己的編號：從開始時刻來，同一支手機上不會撞。收下或作廢時跟著那筆紀錄走。
    static func recordId(_ start: Millis) -> String {
        "r" + String(format: "%.0f", start)
    }

    /// 手機現在的時區名（例如 Asia/Taipei）。開始一顆時記下來。
    static func zoneNow() -> String {
        TimeZone.current.identifier
    }

    /// 一顆占幾個單位：25→1、50→2、15→1（四捨五入，最少 1）。
    static func units(_ len: Double) -> Int {
        max(1, Int((len / minutesPerUnit).rounded()))
    }

    /// 「跟著長度」的休息幾分鐘：長度 ÷ 5，最少 3。25→5、50→10、15→3。
    static func restMinutes(_ len: Double) -> Int {
        max(restMinMinutes, Int((len / restDivisor).rounded()))
    }

    /// 收下這顆之後休息多久。beansToday＝含這顆在內，那天收下第幾顆。
    /// 那天每滿 restLongEvery 顆是長休息，其他是短休息。作廢的不算；延長過的還是一顆；跨日從頭數。
    static func restAfter(_ settings: AppSettings, len: Double, beansToday: Int) -> RestPlan {
        let every = settings.restLongEvery
        if every > 0, beansToday > 0, beansToday % every == 0 {
            return RestPlan(minutes: settings.restLongMinutes, long: true)
        }
        switch settings.restShort {
        case .auto: return RestPlan(minutes: restMinutes(len), long: false)
        case let .minutes(fixed): return RestPlan(minutes: fixed, long: false)
        }
    }

    /// 智能調節：這顆專注幾分（含延長）÷ 5；今天的專注每跨過一個 100 分再加 10，跨過的那次算長休息。
    /// 25 分休 5、第四顆跨過 100 休 15，就是原本的番茄鐘，換成任何長度都算得出來。
    /// before＝那天在這顆之前已經專注幾分。
    static func smartRest(focused: Double, before: Double) -> RestPlan {
        let every = Params.SmartRest.bonusEvery
        let crossed = Int((before + focused) / every) - Int(before / every)
        let base = Int((focused / Params.SmartRest.divisor).rounded())
        let minutes = base + crossed * Params.SmartRest.bonusMinutes
        let capped = min(Params.SmartRest.maxMinutes, max(Params.SmartRest.minMinutes, minutes))
        return RestPlan(minutes: capped, long: crossed > 0)
    }
}
