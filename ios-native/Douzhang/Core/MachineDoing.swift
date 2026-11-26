import Foundation

// MARK: 正在做什麼

extension Machine {
    /// 改「正在做什麼」：下一顆的一定改；這顆還沒收下的話，連這顆的一起改。空的就是清掉。
    /// 頭尾空白去掉、最多 doingMaxChars 字。
    static func setDoing(_ state: AppState, text: String) -> AppState {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let line = String(trimmed.prefix(Params.doingMaxChars))
        var next = state
        next.doing = line
        if var run = state.focusRun {
            run.doing = line
            next.current = .focus(run)
        }
        return next
    }
}

// MARK: 收下的那顆改字

extension Machine {
    /// 番茄架的收據裡改收下的那一顆：在做什麼與寫給自己的那句，記下改的時刻（同步時改得晚的整組贏）。
    /// 跟寫的時候同一套：頭尾空白去掉，在做什麼最多 doingMaxChars 字、那句最多 noteMaxChars 字。
    /// 找不到這顆、或兩樣都沒變，原封不動：只按「好」不算改過，不然會蓋掉另一台同時改的字。
    static func editWords(
        _ state: AppState,
        id: String,
        doing: String,
        clue: String,
        now: Millis
    ) -> AppState {
        guard !id.isEmpty else { return state }
        var next = state
        for (key, day) in state.days {
            guard let index = day.beans.firstIndex(where: { $0.id == id }) else { continue }
            var bean = day.beans[index]
            let newDoing = edited(doing, was: bean.doing, limit: Params.doingMaxChars)
            let newClue = edited(clue, was: bean.clue, limit: Params.noteMaxChars)
            if newDoing == bean.doing, newClue == bean.clue {
                return state
            }
            bean.doing = newDoing
            bean.clue = newClue
            bean.wordsEditedAt = now
            next.days[key]?.beans[index] = bean
            return next
        }
        return state
    }

    /// 兩台合過的字可能超過上限（兩句分行併在一起）：沒動的照原樣留著，不要被切掉。
    private static func edited(_ typed: String, was: String, limit: Int) -> String {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == was ? was : String(trimmed.prefix(limit))
    }
}
