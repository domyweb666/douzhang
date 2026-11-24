import Foundation

/// 月檢視清單的一天：做了什麼、那天寫的第一句、幾顆多久。
struct DoneDay: Equatable {
    var key: String
    /// 那天最多分鐘的標籤色
    var color: TomatoColor
    /// 同名合併，分鐘多的在前
    var names: [String]
    /// 沒寫是空的
    var clue: String
    var sum: DaySum
}

/// 番茄架月檢視下面那張「這個月做了什麼」。純函式，只讀不寫。
enum MonthDone {
    /// key 那個月有番茄的日子，新的在上。只有作廢的日子不列：清單講的是做了什麼。
    static func days(_ state: AppState, key: String) -> [DoneDay] {
        guard DayKeys.dateOf(key) != nil else { return [] }
        let monthPrefix = String(DayKeys.shiftMonth(key, months: 0).dropLast(2))
        return state.days.keys
            .filter { $0.hasPrefix(monthPrefix) }
            .sorted(by: >)
            .compactMap { doneDay(state, key: $0) }
    }

    private static func doneDay(_ state: AppState, key: String) -> DoneDay? {
        guard let day = state.days[key], let sum = Receipt.daySum(day) else { return nil }
        let beans = day.beans.stableSorted { $0.keptAt }
        let tags = merged(beans) { Machine.typeOf(state, $0.typeId).id }
        let names = merged(beans) { bean in
            Receipt.workName(bean.doing, type: Machine.typeOf(state, bean.typeId))
        }
        return DoneDay(
            key: key,
            color: Machine.typeOf(state, tags.first ?? "").color,
            names: names,
            clue: beans.first { !$0.clue.isEmpty }?.clue ?? "",
            sum: sum
        )
    }

    /// 同一個名字的分鐘（含延長）加在一起，多的在前；一樣多的照先做的。
    private static func merged(_ beans: [Bean], by name: (Bean) -> String) -> [String] {
        var order: [String] = []
        var minutes: [String: Double] = [:]
        for bean in beans {
            let found = name(bean)
            if minutes[found] == nil {
                order.append(found)
            }
            minutes[found, default: 0] += bean.len + bean.flow
        }
        return order.stableSorted { -(minutes[$0] ?? 0) }
    }
}
