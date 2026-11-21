import Foundation

enum Phase {
    case idle, focus, bell, rest
}

/// 計時中記一筆的兩種：冒出念頭、有人找。記一筆的函式在 MachineJot.swift。
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
    static func settle(_ state: AppState, now: Millis, zone: String? = nil) -> AppState {
        guard case let .rest(run)? = state.current, let endAt = run.endAt,
              now >= endAt else { return state }
        let idle = with(state, current: nil)
        guard state.settings.autoNext else { return idle }
        let startAt = endAt + Params.autoNextDelayMs
        if now < startAt {
            return state
        }
        return start(idle, now: startAt, typeId: run.typeId, zone: zone)
    }

    /// 開始一顆。不用先寫一句：按了就開始。typeId 沒給就用設定選中的那個標籤。
    /// 這顆的編號在這裡定；zone 是手機這一刻的時區名，殼給的（這裡是純函式，不自己看系統）。
    static func start(
        _ state: AppState,
        now: Millis,
        typeId: String? = nil,
        zone: String? = nil
    ) -> AppState {
        let type = liveType(state, typeId ?? state.settings.typeId)
        let run = FocusRun(
            typeId: type.id,
            len: type.len,
            startedAt: now,
            endAt: now + type.len * Params.msPerMinute,
            id: Store.recordId(now),
            zone: zone
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
        let key = dayKey(of: run)
        var next = with(state, current: nil)
        next.days[key, default: DayRecord()].beans.append(bean(from: run, now: now, text: text))
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

    /// 提早做完了：剩下的時間繼續倒數，鈴響再停；畫面多一行提醒。
    /// now 是按下的時刻，只記第一次；之後用來看這個長度是不是太長。
    static func markDone(_ state: AppState, now: Millis? = nil) -> AppState {
        guard var run = state.focusRun else { return state }
        if !run.done {
            run.doneAt = now
        }
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
        // 這顆記過的念頭與有人找跟著留下來，不然作廢就一起不見
        let entry = VoidEntry(
            voidedAt: now,
            typeId: run.typeId,
            minute: Int((now - run.startedAt) / Params.msPerMinute),
            reason: reason,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            id: run.id,
            start: run.startedAt,
            zone: run.zone,
            len: run.len,
            notes: run.notes,
            pings: run.pings
        )
        next.days[dayKey(of: run), default: DayRecord()].voids.append(entry)
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

// MARK: 標籤與紀錄的對應

extension Machine {
    /// 升級前就刪掉的標籤：名字已經沒了，那些舊番茄都掛在這個編號下。
    static let goneTypeId = "gone"

    /// 現在還在的標籤裡找；找不到就退回第一個。開始一顆、排下一顆用這個：不會開出一顆已刪標籤的番茄。
    static func liveType(_ state: AppState, _ typeId: String) -> TagType {
        if typeId == devTypeId {
            return devType
        }
        let types = state.settings.types
        let found = types.first { $0.id == typeId }
        return found ?? types.first ?? Store.defaultType
    }

    /// 一筆紀錄掛在哪個標籤（畫面與分析用）。刪掉的標籤照原本的名字與顏色，不併進別的標籤。
    /// 升級前就刪掉的（名字沒留下來）：叫「已刪除的標籤」，顏色沿用第一個標籤（多米 2026-11-22 定）。
    /// 很舊的資料沒有標籤（空字串）：那是沒分類，不是被刪，照舊算在第一個。
    static func typeOf(_ state: AppState, _ typeId: String) -> TagType {
        let settings = state.settings
        let isLive = settings.types.contains { $0.id == typeId }
        if isLive || typeId.isEmpty || typeId == devTypeId {
            return liveType(state, typeId)
        }
        if let removed = settings.removedTypes.first(where: { $0.type.id == typeId }) {
            return removed.type
        }
        let first = liveType(state, typeId)
        return TagType(id: goneTypeId, name: Words.removedTag, len: first.len, color: first.color)
    }

    /// 這顆算哪一天：開始那一刻、照開始時的時區。
    static func dayKey(of run: FocusRun) -> String {
        Store.dayKey(run.startedAt, zone: run.zone)
    }

    /// 進行中那顆身上帶的東西，收下時全部抄進番茄：編號、時區、有沒有提早做完與幾點按的。
    private static func bean(from run: FocusRun, now: Millis, text: String) -> Bean {
        Bean(
            keptAt: now,
            typeId: run.typeId,
            len: run.len,
            clue: text.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: run.notes,
            pings: run.pings,
            flow: run.flowMin,
            start: run.startedAt,
            id: run.id,
            zone: run.zone,
            done: run.done,
            doneAt: run.doneAt
        )
    }
}
