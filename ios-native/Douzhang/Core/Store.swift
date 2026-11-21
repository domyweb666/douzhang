import Foundation

/// 收下這顆之後休息多久、是不是長休息。
struct RestPlan: Equatable {
    var minutes: Int
    var long: Bool
}

/// 番茄帳 資料層的算法：空白狀態、日期鍵、一顆幾單位、休息多久。純函式，不碰檔案。
enum Store {
    static let formatVersion = 1
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

    /// 一律用西曆算日期。手機設成民國曆或佛曆時，日期鍵也要跟 Expo 版同一種寫法，舊資料才對得上。
    static func localCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    static func date(_ time: Millis) -> Date {
        Date(timeIntervalSince1970: time / Params.msPerSecond)
    }

    /// 本地日期鍵 YYYY-MM-DD（本地時區，不是 UTC）。
    static func dayKey(_ time: Millis) -> String {
        let parts = localCalendar().dateComponents([.year, .month, .day], from: date(time))
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
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
}
