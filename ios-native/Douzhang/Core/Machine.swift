import Foundation

enum Phase {
    case idle, focus, bell, rest
}

/// 計時中記一筆的兩種：冒出念頭、有人找。
enum JotKind {
    case notes, pings
}

/// 番茄帳 狀態機：待機／計時中／鈴響／休息。純函式，吃狀態回新狀態，不碰畫面、不存檔、不排通知。
/// 翻自 Expo 版 core/machine.js；收工、葉子、估幾顆那幾個已經拿掉的流程沒有搬過來。
enum Machine {
    static let devTypeId = "dev-test"

    /// 開發期專用的測試標籤。正式 build 的畫面選不到它。
    static let devType = TagType(
        id: devTypeId,
        name: Words.devTypeName,
        len: Params.devTestSeconds / Params.secondsPerMinute,
        color: .red
    )

    /// 標籤被刪掉的舊番茄算在第一個標籤上。
    static func typeOf(_ state: AppState, _ typeId: String) -> TagType {
        if typeId == devTypeId {
            return devType
        }
        let types = state.settings.types
        let found = types.first { $0.id == typeId }
        return found ?? types.first ?? Store.defaultType
    }

    /// 現在該顯示哪一態：由 current 與時鐘算出來，不另外存。
    static func phaseOf(_ state: AppState, now: Millis) -> Phase {
        guard let current = state.current else { return .idle }
        switch current {
        case let .focus(run): return now >= run.endAt ? .bell : .focus
        case let .rest(run): return restEnded(run, now: now) ? .idle : .rest
        }
    }

    /// 休息有沒有到點。「我自己決定」的休息沒有結束時刻，永遠不自己結束。
    private static func restEnded(_ run: RestRun, now: Millis) -> Bool {
        guard let endAt = run.endAt else { return false }
        return now >= endAt
    }

    private static func with(_ state: AppState, current: Current?) -> AppState {
        var next = state
        next.current = current
        return next
    }

    /// 休息到點就算回待機了：把過期的休息收掉。每一拍與開機讀檔後呼叫。
    /// 開了「休息完自動開始」：到點先回待機 autoNextDelayMs（剛收的那顆在這段掉進番茄堆），
    /// 這段時間 current 還留著休息那筆（記得是哪個標籤）；過了就用同一個標籤開始下一顆。
    /// 開始時刻是算的，不是看到的那一刻：app 在背景時也一樣，回來時可能已經走了一段，甚至已經到點。
    static func settle(_ state: AppState, now: Millis) -> AppState {
        guard case let .rest(run)? = state.current, let endAt = run.endAt,
              now >= endAt else { return state }
        let idle = with(state, current: nil)
        guard state.settings.autoNext else { return idle }
        let startAt = endAt + Params.autoNextDelayMs
        if now < startAt {
            return state
        }
        return start(idle, now: startAt, typeId: run.typeId)
    }

    /// 開始一顆。不用先寫一句：按了就開始。typeId 沒給就用設定選中的那個標籤。
    static func start(_ state: AppState, now: Millis, typeId: String? = nil) -> AppState {
        let type = typeOf(state, typeId ?? state.settings.typeId)
        let run = FocusRun(
            typeId: type.id,
            len: type.len,
            startedAt: now,
            endAt: now + type.len * Params.msPerMinute
        )
        return with(state, current: .focus(run))
    }

    /// 收下後那句：輪替，不跟上一次同一句。roll 是擲出來的位置。
    static func pickLine(after last: Int, roll: Int) -> Int {
        roll == last ? (roll + 1) % Words.restLines.count : roll
    }

    /// 收下這顆：番茄進「開始那天」的帳、進休息。空白也收。
    static func keep(_ state: AppState, now: Millis, text: String) -> AppState {
        guard let run = state.focusRun else { return state }
        let bean = Bean(
            keptAt: now,
            typeId: run.typeId,
            len: run.len,
            clue: text.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: run.notes,
            pings: run.pings,
            flow: run.flowMin,
            start: run.startedAt
        )
        let key = Store.dayKey(run.startedAt)
        var next = with(state, current: nil)
        next.days[key, default: DayRecord()].beans.append(bean)
        // 那天第幾顆決定這次是短休息還是長休息
        let count = next.days[key]?.beans.count ?? 0
        let plan = Store.restAfter(state.settings, len: run.len, beansToday: count)
        var restMs = Double(plan.minutes) * Params.msPerMinute
        // 測試顆的休息跟它一樣短，不然看一次掉番茄要等好幾分鐘；輪到長休息時照樣標成長休息
        if run.typeId == devTypeId {
            restMs = Params.devTestSeconds * Params.msPerSecond
        }
        // 響了沒理、拖到超過這顆的休息長度才回來收：休息早過了，直接待機
        if now - run.endAt >= restMs {
            return next
        }
        let isOwn = state.settings.restMode == .own
        next.lastLine = pickLine(
            after: state.lastLine,
            roll: Int.random(in: 0 ..< Words.restLines.count)
        )
        let rest = RestRun(
            typeId: run.typeId,
            len: run.len,
            restStart: now,
            endAt: isOwn ? nil : now + restMs,
            long: !isOwn && plan.long,
            msg: Words.restLines[next.lastLine]
        )
        next.current = .rest(rest)
        return next
    }

    /// 計時中記一筆。倒數不停，只是往這顆裡推一行。
    static func jot(_ state: AppState, kind: JotKind, text: String) -> AppState {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var run = state.focusRun, !line.isEmpty else { return state }
        switch kind {
        case .notes: run.notes.append(line)
        case .pings: run.pings.append(line)
        }
        return with(state, current: .focus(run))
    }

    /// 提早做完了：剩下的時間繼續倒數，鈴響再停；畫面多一行提醒。
    static func markDone(_ state: AppState) -> AppState {
        guard var run = state.focusRun else { return state }
        run.done = true
        return with(state, current: .focus(run))
    }

    /// 開始不到 stopNoRecordMinutes 分：這時結束叫「停下來」，不留紀錄。
    static func stoppedEarly(_ run: FocusRun, now: Millis) -> Bool {
        now - run.startedAt < Params.stopNoRecordMinutes * Params.msPerMinute
    }

    /// 作廢這顆：只在開始那天記一筆，番茄不扣、什麼都不扣；回待機。停下來（early）什麼都不記。
    /// early 是畫面在打開半頁那一刻固定的判斷：半頁開著的時候跨過五分鐘，也照打開時說的做。
    static func voidBean(
        _ state: AppState,
        now: Millis,
        reason: String = "",
        text: String = "",
        early: Bool
    ) -> AppState {
        guard let run = state.focusRun else { return state }
        var next = with(state, current: nil)
        if early {
            return next
        }
        let entry = VoidEntry(
            voidedAt: now,
            typeId: run.typeId,
            minute: Int((now - run.startedAt) / Params.msPerMinute),
            reason: reason,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        next.days[Store.dayKey(run.startedAt), default: DayRecord()].voids.append(entry)
        return next
    }

    /// 畫面沒有先固定判斷時：看按下這一刻是不是還在「停下來不留紀錄」的那段。
    static func voidBean(
        _ state: AppState,
        now: Millis,
        reason: String = "",
        text: String = ""
    ) -> AppState {
        guard let run = state.focusRun else { return state }
        let early = stoppedEarly(run, now: now)
        return voidBean(state, now: now, reason: reason, text: text, early: early)
    }

    /// 鈴響後再做 15／30 分：一顆只能一次。到點再響，收下時 flow 記總延長分鐘。
    static func flow(_ state: AppState, now: Millis, minutes: Double) -> AppState {
        guard var run = state.focusRun, now >= run.endAt, !run.flowed else { return state }
        run.endAt = now + minutes * Params.msPerMinute
        run.flowed = true
        run.flowMin += minutes
        return with(state, current: .focus(run))
    }

    /// 回來了：結束休息回待機（不自動開始，開始要人按）。
    static func backFromRest(_ state: AppState) -> AppState {
        guard case .rest? = state.current else { return state }
        return with(state, current: nil)
    }

    /// 鈴響頁打到一半的字：存進這顆，切走或殺掉再開還在；收下時隨這顆一起消失。
    static func setDraft(_ state: AppState, text: String) -> AppState {
        guard var run = state.focusRun else { return state }
        run.draft = text
        return with(state, current: .focus(run))
    }
}
