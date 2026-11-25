import ActivityKit
import Foundation

/// 鎖定畫面與動態島那一張（AI27）。app 與擴充要編進同一份定義，系統才對得起來。
struct TimerActivity: ActivityAttributes {
    typealias ContentState = LiveCardFace
}

/// 卡上是什麼。只有哪一態、番茄色、時刻：鎖定畫面誰都看得到，使用者寫的字不准進來（安全標準 P3）。
/// 只存時刻、不存剩幾秒：數字與環由系統照時刻自己走，app 睡著也走。
enum LiveCardFace: Codable, Hashable {
    /// 還在計時。ripe：再做的那段，番茄已經熟了
    case growing(TomatoColor, from: Date, until: Date, ripe: Bool)
    /// 響了還沒收
    case rang(TomatoColor)
    case resting(from: Date, until: Date)
    /// 「我自己決定」的休息：沒有終點
    case restingOpen

    /// 過了這一刻系統把這張標成過時，畫面換成到點的樣子：那時 app 多半睡著，沒人更新。
    var staleDate: Date? {
        switch self {
        case let .growing(_, _, until, _), let .resting(_, until): until
        case .rang, .restingOpen: nil
        }
    }
}

extension TomatoColor: Codable {}
