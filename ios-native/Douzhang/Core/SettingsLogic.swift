import Foundation

/// 設定裡有規則的那幾個改動：選標籤、加減標籤、改名、改長度與顏色、休息的刻度。純函式，不存檔。
/// 翻自 Expo 版 core/settings.js。單純的開關（聲音、傾斜、擋 app、自動開始、白噪音）
/// 型別本身就擋掉了不合法的值，畫面直接改欄位，不另外包一層。
enum SettingsLogic {
    static func pickType(_ state: AppState, typeId: String) -> AppState {
        guard state.settings.types.contains(where: { $0.id == typeId }) else { return state }
        var next = state
        next.settings.typeId = typeId
        return next
    }

    /// 新標籤拿第一個還沒人用的番茄色，都用過就從頭輪。
    private static func freeColor(_ types: [TagType]) -> TomatoColor {
        let all = TomatoColor.allCases
        let used = Set(types.map(\.color))
        let free = all.first { !used.contains($0) }
        return free ?? all[types.count % all.count]
    }

    /// 加一個標籤：排在最後，選中的不變。id 用按下那一刻的毫秒，不會撞到。
    static func addType(_ state: AppState, now: Millis) -> AppState {
        let type = TagType(
            id: "t\(Int(now))",
            name: Words.newTypeName,
            len: Params.newTypeMinutes,
            color: freeColor(state.settings.types)
        )
        var next = state
        next.settings.types.append(type)
        return next
    }

    private static func mapType(
        _ state: AppState,
        id: String,
        change: (inout TagType) -> Void
    ) -> AppState {
        var next = state
        for index in next.settings.types.indices where next.settings.types[index].id == id {
            change(&next.settings.types[index])
        }
        return next
    }

    /// 改名：頭尾空白去掉、最多 typeNameMaxChars 字，空的變「未命名」。
    static func renameType(_ state: AppState, id: String, name: String) -> AppState {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = String(trimmed.prefix(Params.typeNameMaxChars))
        return mapType(state, id: id) { $0.name = clean.isEmpty ? Words.unnamedType : clean }
    }

    /// 長度只能從刻度選（同一把尺）；刻度外的值不改。
    static func setTypeLen(_ state: AppState, id: String, len: Double) -> AppState {
        guard Params.typeLengths.contains(len) else { return state }
        return mapType(state, id: id) { $0.len = len }
    }

    static func setTypeColor(_ state: AppState, id: String, color: TomatoColor) -> AppState {
        mapType(state, id: id) { $0.color = color }
    }

    /// 刪到剩一個就不能再刪；刪掉的是選中的就退回第一個。
    static func removeType(_ state: AppState, id: String) -> AppState {
        let types = state.settings.types.filter { $0.id != id }
        guard !types.isEmpty, types.count != state.settings.types.count else { return state }
        var next = state
        next.settings.types = types
        if !types.contains(where: { $0.id == state.settings.typeId }) {
            next.settings.typeId = types[0].id
        }
        return next
    }

    /// 短休息、長休息：只准刻度上的值（下一次收下才用到，休息中改不影響這次）。
    static func setRestShort(_ state: AppState, value: RestShort) -> AppState {
        guard Params.restShortOptions.contains(value) else { return state }
        var next = state
        next.settings.restShort = value
        return next
    }

    static func setRestLongEvery(_ state: AppState, every: Int) -> AppState {
        guard Params.restLongEveryOptions.contains(every) else { return state }
        var next = state
        next.settings.restLongEvery = every
        return next
    }

    static func setRestLongMinutes(_ state: AppState, minutes: Int) -> AppState {
        guard Params.restLongMinuteOptions.contains(minutes) else { return state }
        var next = state
        next.settings.restLongMinutes = minutes
        return next
    }
}
