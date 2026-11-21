import Foundation

/// 該排的一則通知：標題、內文、幾點響。
struct PlannedNotice: Equatable {
    var title: String
    var body: String
    var fireAt: Millis
}

/// 番茄帳 通知：只有「到點」一種（這顆到點、休息到點），文案固定、不含使用者寫的那句。
/// 這裡只算「現在這個狀態該排哪些」；跟系統打交道的部分等殼搬過來那一片再加。
enum Notify {
    /// 已經過了的時刻不排（鈴響頁等人回來時沒有通知可排）。
    static func planned(_ state: AppState, now: Millis) -> [PlannedNotice] {
        guard let current = state.current else { return [] }
        var list: [PlannedNotice] = []
        switch current {
        case let .focus(run):
            list.append(PlannedNotice(title: Words.rang, body: Words.bellSub, fireAt: run.endAt))
        case let .rest(run):
            list += restNotices(state, run: run)
        }
        return list.filter { $0.fireAt > now }
    }

    /// 開了「休息完自動開始」：休息時連下一顆的到點一起排，下一顆在背景自己開始時才有人叫；
    /// 休息完那則的內文改成下一顆自己開始了。「我自己決定」的休息沒有結束時刻，不排。
    private static func restNotices(_ state: AppState, run: RestRun) -> [PlannedNotice] {
        guard state.settings.restMode == .auto, let endAt = run.endAt else { return [] }
        let isAuto = state.settings.autoNext
        let body = isAuto ? Words.autoNextStarted : Words.backFromRest
        var list = [PlannedNotice(title: Words.restDone, body: body, fireAt: endAt)]
        if isAuto {
            let nextStart = endAt + Params.autoNextDelayMs
            let nextLen = Machine.typeOf(state, run.typeId).len
            let nextEnd = nextStart + nextLen * Params.msPerMinute
            list.append(PlannedNotice(title: Words.rang, body: Words.bellSub, fireAt: nextEnd))
        }
        return list
    }
}
