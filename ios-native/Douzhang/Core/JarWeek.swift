import Foundation

/// 番茄堆放的是這一週的番茄（週一起算，跟番茄架的週一樣）：同一週換日不清空，到下週一才清。
enum JarWeek {
    /// 這週每一天收的番茄，照收下的時間排；這台最近收的那顆（fresh）排最後：番茄堆只掉最後一顆。
    /// 照時間排不夠：休息中合進來的、別支手機時鐘快的，會排到它後面，掉下來的就是別人的。
    static func beans(_ state: AppState, todayKey: String, fresh: String?) -> [Bean] {
        var list = days(todayKey)
            .flatMap { state.days[$0]?.beans ?? [] }
            .stableSorted { $0.keptAt }
        if let mine = list.firstIndex(where: { $0.id == fresh }) {
            list.append(list.remove(at: mine))
        }
        return list
    }

    /// 這週一共幾顆。
    static func count(_ state: AppState, todayKey: String) -> Int {
        days(todayKey).reduce(0) { $0 + (state.days[$1]?.beans.count ?? 0) }
    }

    private static func days(_ todayKey: String) -> [String] {
        DayKeys.weekDays(DayKeys.weekStart(todayKey))
    }
}
