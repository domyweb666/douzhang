import Foundation

/// 分析看多長一段：日、週、月。
enum StatsRange: CaseIterable {
    case day, week, month

    /// 換一段的算法跟番茄架的檢視共用。
    var view: RackView {
        switch self {
        case .day: .day
        case .week: .week
        case .month: .month
        }
    }
}

/// 一天裡某個標籤的分鐘數。
struct StatsPart: Equatable {
    var type: TagType
    var minutes: Double
}

/// 每天一筆。parts 照標籤在設定裡的順序。
struct StatsDay: Equatable {
    var key: String
    var minutes: Double
    var parts: [StatsPart]
}

/// 每個有番茄的標籤一筆。share 是占總分鐘的幾成。removed＝這個標籤已經刪掉了（名字還留著）。
struct StatsTag: Equatable {
    var type: TagType
    var minutes: Double
    var beans: Int
    var share: Double
    var removed = false
}

/// 這幾天的每一顆。
struct StatsBean: Equatable {
    var keptAt: Millis
    var type: TagType
    var len: Double
}

struct StatsResult: Equatable {
    /// 總分鐘（含延長）
    var minutes: Double
    var beans: Int
    var days: [StatsDay]
    /// 由多到少
    var tags: [StatsTag]
    /// 依收下的時間排
    var list: [StatsBean]
}

/// 番茄帳 分析：一段時間裡專注多久、收了幾顆、每天各標籤多少、各標籤占多少。純函式，只讀不寫。
/// 只陳述，不跟上一段比（不做「比上週少幾 %」）。翻自 Expo 版 core/stats.js。
enum Stats {
    /// 這一段包含哪幾天：日＝選中那天；週＝那一週七天；月＝那個月每一天。
    static func rangeDays(_ range: StatsRange, selected: String) -> [String] {
        switch range {
        case .day:
            return [selected]
        case .week:
            return DayKeys.weekDays(DayKeys.weekStart(selected))
        case .month:
            let first = DayKeys.shiftMonth(selected, months: 0)
            let next = DayKeys.shiftMonth(selected, months: 1)
            var keys: [String] = []
            var key = first
            while key < next {
                keys.append(key)
                key = DayKeys.shift(key, days: 1)
            }
            return keys
        }
    }

    /// 這幾天的小計。刪掉的標籤自己一列、不併進別的標籤（跟番茄架、番茄堆同一條規則，Machine.typeOf）。
    static func stats(_ state: AppState, keys: [String]) -> StatsResult {
        var tags: [StatsTag] = []
        var list: [StatsBean] = []
        let days = keys.map { key in
            var perTag: [String: Double] = [:]
            for bean in state.days[key]?.beans ?? [] {
                let type = Machine.typeOf(state, bean.typeId)
                let minutes = bean.len + bean.flow
                perTag[type.id, default: 0] += minutes
                add(&tags, type: type, minutes: minutes)
                list.append(StatsBean(keptAt: bean.keptAt, type: type, len: bean.len))
            }
            let parts = tagOrder(state).compactMap { type in
                perTag[type.id].map { StatsPart(type: type, minutes: $0) }
            }
            let minutes = parts.reduce(0) { $0 + $1.minutes }
            return StatsDay(key: key, minutes: minutes, parts: parts)
        }
        let total = days.reduce(0) { $0 + $1.minutes }
        let removedIds = Set(state.settings.removedTypes.map(\.type.id))
        for index in tags.indices {
            tags[index].share = total > 0 ? tags[index].minutes / total : 0
            tags[index].removed = removedIds.contains(tags[index].type.id)
        }
        return StatsResult(
            minutes: total,
            beans: list.count,
            days: days,
            tags: tags.stableSorted { -$0.minutes },
            list: list.stableSorted { $0.keptAt }
        )
    }

    /// 一天那根長條由下往上疊的順序：現有標籤照設定裡的順序，再來是刪掉的，最後是名字沒留下來的。
    private static func tagOrder(_ state: AppState) -> [TagType] {
        let settings = state.settings
        let gone = Machine.typeOf(state, Machine.goneTypeId)
        return settings.types + settings.removedTypes.map(\.type) + [gone]
    }

    private static func add(_ tags: inout [StatsTag], type: TagType, minutes: Double) {
        if let index = tags.firstIndex(where: { $0.type.id == type.id }) {
            tags[index].minutes += minutes
            tags[index].beans += 1
        } else {
            tags.append(StatsTag(type: type, minutes: minutes, beans: 1, share: 0))
        }
    }
}
