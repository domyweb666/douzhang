import Foundation

/// 鎖定畫面與動態島那張卡該寫什麼、什麼時候收。純函式，不碰 ActivityKit；跟系統打交道在 App/LiveIsland。
enum LivePlan {
    /// 色碼一個分量的最大值（0xFF）
    private static let channelMax = 255.0

    /// 現在的狀態畫成一張卡。計時中、熟了照這顆；休息中照這段休息的標籤；其他都是待機，
    /// 開始鈕開設定選中的那個標籤（跟主畫面的開始鈕同一個）。
    static func card(_ state: AppState, now: Millis) -> LiveCard {
        let kept = state.days[Store.dayKey(now)]?.beans.count ?? 0
        let phase = Machine.phaseOf(state, now: now)
        if let run = state.focusRun {
            let type = Machine.typeOf(state, run.typeId)
            let stage: LiveStage = phase == .bell ? .bell : .focus
            var card = base(type, typeId: run.typeId, stage: stage, kept: kept)
            card.lenText = Words.typeLen(run.len)
            card.startAt = date(run.startedAt)
            card.endAt = date(run.endAt)
            return card
        }
        if let run = state.restRun, phase == .rest {
            let type = Machine.liveType(state, run.typeId)
            var card = base(type, typeId: run.typeId, stage: .rest, kept: kept)
            card.startAt = date(run.restStart)
            card.endAt = run.endAt.map(date)
            card.autoNext = state.settings.autoNext && run.endAt != nil
            return card
        }
        let typeId = state.settings.typeId
        return base(Machine.liveType(state, typeId), typeId: typeId, stage: .idle, kept: kept)
    }

    /// 卡片上現在那張（shown）換成 next 之前，該不該直接收掉。
    /// 計時中、熟了直接回待機是作廢、停下來、清空（收下會先進休息）：人就在 app 裡，卡片不用留。
    /// 待機超過 Params.liveIdleHours 也收：不是要接著做的時候，鎖定畫面不留一顆開始鈕。
    static func shouldEnd(shown: LiveCard, next: LiveCard, now: Date) -> Bool {
        guard next.stage == .idle else { return false }
        switch shown.stage {
        case .focus, .bell:
            return true
        case .rest:
            return false
        case .idle:
            guard let since = shown.idleSince else { return false }
            let limit = Params.liveIdleHours * Params.msPerHour / Params.msPerSecond
            return now.timeIntervalSince(since) >= limit
        }
    }

    /// 系統什麼時候把內容標成過期、重畫一次：計時中、休息中是到點那一刻（卡片自己換成熟了、休息完）。
    static func staleDate(_ card: LiveCard) -> Date? {
        switch card.stage {
        case .focus, .rest: card.endAt
        case .bell, .idle: nil
        }
    }

    private static func base(
        _ type: TagType,
        typeId: String,
        stage: LiveStage,
        kept: Int
    ) -> LiveCard {
        LiveCard(
            stage: stage,
            typeId: typeId,
            name: type.name,
            lenText: Words.typeLen(type.len),
            kept: kept,
            tint: hex(Tokens.Tomato.body(type.color)),
            leaf: hex(Tokens.Tomato.leaf),
            words: LiveWords(
                ripe: Words.liveRipe,
                resting: Words.liveResting,
                restDone: Words.restDone,
                start: Words.start
            )
        )
    }

    private static func date(_ time: Millis) -> Date {
        Date(timeIntervalSince1970: time / Params.msPerSecond)
    }

    /// Tokens 的顏色（三個 0–1 的分量）換成色碼，擴充用 DomyTokens 的 UIColor(domyHex:) 畫回來。
    static func hex(_ rgb: RGB) -> UInt32 {
        channel(rgb.red) << 16 | channel(rgb.green) << 8 | channel(rgb.blue)
    }

    private static func channel(_ value: Double) -> UInt32 {
        UInt32((min(1, max(0, value)) * channelMax).rounded())
    }
}
