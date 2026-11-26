import Foundation

/// 番茄架月檢視下面那塊：選中那一天的番茄，與換月之後停在哪一天。純函式，只讀不寫。
enum MonthBoard {
    /// 那天的番茄，由早到晚。作廢不列：這一塊講的是做了什麼，作廢在收據上。
    static func beans(_ state: AppState, key: String) -> [TimelineItem] {
        Receipt.timeline(state.days[key]).filter { $0.kind == .bean }
    }

    /// 第一個有番茄的日子；一顆都沒有是 nil。
    static func firstKept(_ state: AppState) -> String? {
        state.days.filter { !$0.value.beans.isEmpty }.keys.min()
    }

    /// 這天掛不掛葉子（格子畫一片、下面那塊寫那句）：已經過完、沒有番茄，不算缺。
    /// 今天與以後不掛（今天還沒過完）；第一顆番茄那天（since）以前也不掛（那時還沒在用，不是「沒做」）。
    static func hasLeaf(_ state: AppState, key: String, todayKey: String, since: String?) -> Bool {
        guard let since, key >= since, key < todayKey else { return false }
        return state.days[key]?.beans.isEmpty ?? true
    }

    /// 換到 key 那個月之後選哪一天：這個月選今天；別的月選最後一個有番茄的日子，沒有就 1 號。
    /// 一律選 1 號的話，翻過去下面那塊幾乎都是空的。
    static func landing(_ state: AppState, month key: String, todayKey: String) -> String {
        let first = DayKeys.shiftMonth(key, months: 0)
        guard first != DayKeys.shiftMonth(todayKey, months: 0) else { return todayKey }
        let monthPrefix = String(first.dropLast(2))
        let kept = state.days.filter { $0.key.hasPrefix(monthPrefix) && !$0.value.beans.isEmpty }
        return kept.keys.max() ?? first
    }
}
