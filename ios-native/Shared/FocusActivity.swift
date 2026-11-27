import ActivityKit
import Foundation

/// 鎖定畫面與動態島那張卡（Live Activity）。App 與 DouzhangLive 擴充都編這個檔，系統才對得起來。
/// 卡上的字、番茄色、時刻都由 app 算好放進 LiveCard（Core/LivePlan.swift）；擴充只排版。
/// 擴充編不進 Words、Tokens（它們連著整份資料型別），這樣字與番茄色才不會有兩份。
struct FocusActivity: ActivityAttributes {
    typealias ContentState = LiveCard
}

/// 卡上是哪一態。跟 Phase 一樣四態，另外定一份是因為擴充沒有 Core。
enum LiveStage: String, Codable, Hashable {
    case focus, bell, rest, idle
}

/// 卡上會用到的固定字，app 從 Words 抄進來。
struct LiveWords: Codable, Hashable {
    var ripe: String
    var resting: String
    var restDone: String
    var start: String
}

/// 卡的內容。時刻用 Date：倒數（Text(timerInterval:)）與過期時刻都吃 Date。
struct LiveCard: Codable, Hashable {
    var stage: LiveStage
    /// 開始鈕要開的標籤
    var typeId: String
    var name: String
    /// 一顆多長：「25 分」
    var lenText: String
    /// 今天收了幾顆；0 不寫（不出現「0 顆」）
    var kept: Int
    /// 番茄身體與蒂的色碼（0xRRGGBB），app 從 Tokens.Tomato 抄來
    var tint: UInt32
    var leaf: UInt32
    /// 倒數那段：計時中是這顆，休息中是這段休息。「我自己決定」的休息沒有 endAt
    var startAt: Date?
    var endAt: Date?
    /// 休息到點後 app 會自己開始下一顆：休息完不放開始鈕，免得按了跟自動開始的撞成兩顆
    var autoNext = false
    /// 從什麼時候開始待機（app 填）：待機太久就收掉這張卡
    var idleSince: Date?
    var words: LiveWords
}

extension LiveCard {
    /// 這一刻該畫哪一態。app 不在前景時沒人換卡片：到點那一刻系統把內容標成過期（staleDate＝endAt）
    /// 重畫一次，或畫的時候已經過了 endAt，就自己換成下一態：計時中 → 熟了，休息中 → 休息完（待機）。
    func shown(at date: Date, isStale: Bool) -> LiveStage {
        guard let endAt, isStale || date >= endAt else { return stage }
        switch stage {
        case .focus: return .bell
        case .rest: return .idle
        case .bell, .idle: return stage
        }
    }

    /// 大字要倒數的那段；不倒數（熟了、休息完、我自己決定的休息、已經到點）是 nil。
    /// 頭尾顛倒的區間會當掉，起點不准晚於終點。
    func timerRange(for shown: LiveStage) -> ClosedRange<Date>? {
        guard shown == stage, stage == .focus || stage == .rest, let endAt else { return nil }
        return min(startAt ?? endAt, endAt) ... endAt
    }

    /// 不倒數時的大字。
    func headline(for shown: LiveStage) -> String {
        switch shown {
        case .focus, .idle: lenText
        case .bell: words.ripe
        case .rest: words.resting
        }
    }

    /// 標籤名旁邊那一行。計時中、熟了、我自己決定的休息沒有：大字已經說了。
    func note(for shown: LiveStage) -> String {
        switch shown {
        case .focus, .bell: ""
        case .rest: endAt == nil ? "" : words.resting
        case .idle: words.restDone
        }
    }

    /// 只有休息完（待機）放開始鈕；休息完會自己開始下一顆的不放。
    func startsFrom(_ shown: LiveStage) -> Bool {
        shown == .idle && !autoNext
    }

    /// 倒數最寬多寬。系統的倒數字會撐滿能用的寬度，靈動島靠這串看不見的字框住（照米說的做法）。
    var timerTemplate: String {
        guard let endAt else { return "00:00" }
        let longest = endAt.timeIntervalSince(startAt ?? endAt)
        return longest >= Self.secondsPerHour ? "0:00:00" : "00:00"
    }

    private static let secondsPerHour: TimeInterval = 3600
}
