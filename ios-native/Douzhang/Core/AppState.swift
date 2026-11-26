import Foundation

/// 毫秒時刻（1970 起算）。跟 Expo 版狀態檔裡的數字同一種，匯出匯入不用換算。
typealias Millis = Double

enum TomatoColor: String, CaseIterable {
    case red, orange, yellow, purple, pink
}

/// 休息多久、怎麼結束：到點提醒（照短休息、長休息的設定）、智能調節（照專注多久算，一樣到點提醒），
/// 或「我自己決定」（狀態檔裡寫成 self）。
enum RestMode: String {
    case auto
    case smart
    case own = "self"
}

/// 短休息：跟著番茄長度（÷5 最少 3 分），或固定幾分。
enum RestShort: Hashable {
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
/// mod 是格式 v3 加的：最後一次改它的時刻，兩台手機改了同一個標籤時晚的算數；沒動過的預設標籤是 0。
struct TagType: Equatable, Identifiable {
    var id: String
    var name: String
    var len: Double
    var color: TomatoColor
    var mod: Millis = 0
}

/// 刪掉的標籤：不丟，留著名字與顏色，舊番茄才不會被算到別的標籤上。
struct RemovedTag: Equatable {
    var type: TagType
    var removedAt: Millis
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
    /// 刪掉的標籤（格式 v2 起）
    var removedTypes: [RemovedTag] = []
}

/// 正在跑的那一顆。只存幾點結束，不存剩幾秒：背景、鎖屏、殺掉再開都靠時間差重算。
/// id、zone、doneAt 是格式 v2 加的：這顆自己的編號、開始那一刻的時區名、按「提早做完」的時刻。
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
    var id = ""
    var zone: String?
    var doneAt: Millis?
    /// 正在做什麼（選填，空的就是沒填）：開始時抄下一顆填的那句，途中可以改
    var doing = ""
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
/// id、zone、done、doneAt 是格式 v2 加的；舊資料沒有時區就留空，不猜。
struct Bean: Equatable {
    var keptAt: Millis
    var typeId: String
    var len: Double
    var clue: String
    var notes: [String]
    var pings: [String]
    var flow: Double
    var start: Millis?
    var id = ""
    var zone: String?
    var done = false
    var doneAt: Millis?
    var doing = ""
    /// 在番茄架的收據裡最後一次改在做什麼與那句的時刻；沒改過是 nil。
    /// 同步合併同一顆時，改得晚的那份字整組贏（SyncJoin），不然另一台的舊字會被併回來。
    /// 選填欄位，不升格式版本：舊版讀到多一欄照樣讀得懂，只是不認得它。
    var wordsEditedAt: Millis?
}

/// 作廢的一筆：只記第幾分鐘、原因、選填那一行，什麼都不扣。
/// 格式 v2 加：編號、開始時刻、時區、這顆原訂多長、作廢前記的念頭與有人找（以前會跟著消失）。
struct VoidEntry: Equatable {
    var voidedAt: Millis
    var typeId: String
    var minute: Int
    var reason: String
    var text: String
    var id = ""
    var start: Millis?
    var zone: String?
    var len: Double?
    var notes: [String] = []
    var pings: [String] = []
    var doing = ""
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
    /// 下一顆要做的事（選填）。收下、作廢都留著：常常接著做同一件
    var doing = ""

    /// 正在跑（或已經響了還沒收）的那一顆；不在計時中是 nil。
    var focusRun: FocusRun? {
        if case let .focus(run)? = current {
            return run
        }
        return nil
    }

    /// 正在休息的那一段；不在休息是 nil。
    var restRun: RestRun? {
        if case let .rest(run)? = current {
            return run
        }
        return nil
    }
}
