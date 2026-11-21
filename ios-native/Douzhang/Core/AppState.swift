import Foundation

/// 毫秒時刻（1970 起算）。跟 Expo 版狀態檔裡的數字同一種，匯出匯入不用換算。
typealias Millis = Double

enum TomatoColor: String, CaseIterable {
    case red, orange, yellow, purple, pink
}

/// 休息怎麼結束：到點提醒，或「我自己決定」（狀態檔裡寫成 self）。
enum RestMode: String {
    case auto
    case own = "self"
}

/// 短休息：跟著番茄長度（÷5 最少 3 分），或固定幾分。
enum RestShort: Equatable {
    case auto
    case minutes(Int)
}

enum AmbienceKind: String, CaseIterable {
    case off, rain, fire
}

enum AmbienceLevel: String, CaseIterable {
    case low, mid, high
}

/// 標籤（狀態檔沿用 types 這個欄位名）：名字、一顆多長、番茄什麼顏色。
struct TagType: Equatable, Identifiable {
    var id: String
    var name: String
    var len: Double
    var color: TomatoColor
}

struct AppSettings: Equatable {
    var types: [TagType]
    var typeId: String
    var restMode: RestMode
    var sound: Bool
    /// 開發期的測試模式；正式 build 一律關
    var demo: Bool
    var tilt: Bool
    var restShort: RestShort
    var restLongEvery: Int
    var restLongMinutes: Int
    var shield: Bool
    var ambience: AmbienceKind
    var ambienceVolume: AmbienceLevel
    var autoNext: Bool
}

/// 正在跑的那一顆。只存幾點結束，不存剩幾秒：背景、鎖屏、殺掉再開都靠時間差重算。
struct FocusRun: Equatable {
    var typeId: String
    var len: Double
    var startedAt: Millis
    var endAt: Millis
    var notes: [String] = []
    var pings: [String] = []
    var flowed = false
    var flowMin = 0.0
    var done = false
    var draft = ""
}

/// 收下之後的休息。endAt 是 nil 代表「我自己決定」：不倒數，按回來才結束。
struct RestRun: Equatable {
    var typeId: String
    var len: Double
    var restStart: Millis
    var endAt: Millis?
    var long: Bool
    var msg: String
}

enum Current: Equatable {
    case focus(FocusRun)
    case rest(RestRun)
}

/// 收下的一顆。start 是開始時刻；很舊的資料沒有這欄，畫時間軸時用收下時刻倒推。
struct Bean: Equatable {
    var keptAt: Millis
    var typeId: String
    var len: Double
    var clue: String
    var notes: [String]
    var pings: [String]
    var flow: Double
    var start: Millis?
}

/// 作廢的一筆：只記第幾分鐘、原因、選填那一行，什麼都不扣。
struct VoidEntry: Equatable {
    var voidedAt: Millis
    var typeId: String
    var minute: Int
    var reason: String
    var text: String
}

struct DayRecord: Equatable {
    var beans: [Bean] = []
    var voids: [VoidEntry] = []
}

/// 整份狀態。days 的鍵是本地日期 YYYY-MM-DD。
struct AppState: Equatable {
    var settings: AppSettings
    var current: Current?
    var days: [String: DayRecord]
    var lastLine: Int

    /// 正在跑（或已經響了還沒收）的那一顆；不在計時中是 nil。
    var focusRun: FocusRun? {
        if case let .focus(run)? = current { return run }
        return nil
    }

    /// 正在休息的那一段；不在休息是 nil。
    var restRun: RestRun? {
        if case let .rest(run)? = current { return run }
        return nil
    }
}
