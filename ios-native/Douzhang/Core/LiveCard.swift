import ActivityKit
import Foundation

/// 鎖定畫面與動態島現在該不該有那一張、上面是什麼。純函式；叫系統的在 App/LiveCards.swift。
enum LiveCard {
    static func face(_ state: AppState, now: Millis) -> LiveCardFace? {
        switch state.current {
        case let .focus(run)?: focusFace(state, run: run, now: now)
        case let .rest(run)?: restFace(state, run: run, now: now)
        case nil: nil
        }
    }

    private static func focusFace(_ state: AppState, run: FocusRun, now: Millis) -> LiveCardFace {
        let color = Machine.typeOf(state, run.typeId).color
        if now >= run.endAt {
            return .rang(color)
        }
        return .growing(
            color,
            from: Store.date(run.startedAt),
            until: Store.date(run.endAt),
            ripe: run.flowed
        )
    }

    /// 開了「休息完自動開始」時，到點到下一顆之間那 autoNextDelayMs 留著原本那張：
    /// 收掉再開一張新的，app 剛好在背景就開不成。
    private static func restFace(_ state: AppState, run: RestRun, now: Millis) -> LiveCardFace? {
        guard let endAt = run.endAt else { return .restingOpen }
        if now >= endAt, !state.settings.autoNext {
            return nil
        }
        return .resting(from: Store.date(run.restStart), until: Store.date(endAt))
    }

    static func isUp(_ state: ActivityState?) -> Bool {
        state == .active || state == .stale
    }

    /// 沒有還掛著的那張時要不要開。last 是手上那張的下場，沒有是 nil。
    /// 使用者自己滑掉的，同一個內容不再冒出來；滿 8 小時被系統結束的、上次開不成的要補。
    static func opens(_ cue: LiveCardCue, after last: ActivityState?) -> Bool {
        cue == .changed || last != .dismissed
    }
}

/// 為什麼要去動系統那一張：內容換了，或同一個內容但回到前景、再看一眼。
enum LiveCardCue {
    case changed, back
}

/// 要不要去動系統。存草稿每個字都會走到這裡：內容沒變就不動，上次開不成也一樣，等回前景。
struct LiveCardGate {
    private(set) var face: LiveCardFace?
    /// 剛開機不知道系統裡留著什麼，一定對齊一次
    private var isAligned = false

    mutating func cue(_ next: LiveCardFace?, isBack: Bool) -> LiveCardCue? {
        let isNew = !isAligned || next != face
        isAligned = true
        face = next
        if isNew {
            return .changed
        }
        return isBack ? .back : nil
    }
}
