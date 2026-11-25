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
}
