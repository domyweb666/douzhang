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
            color: freeColor(state.settings.types),
            mod: now
        )
        var next = state
        next.settings.types.append(type)
        return next
    }

    /// 這次改（或刪）算在幾時：一定比上一次晚。兩台手機的時鐘不會一樣準，
    /// 另一台快幾分鐘改過之後這台再改，照這台的時鐘寫會比較早，同步時後改的反而輸。
    private static func stamp(_ now: Millis, after mod: Millis) -> Millis {
        max(now, mod + 1)
    }

    /// 改一個標籤並記下幾時改的。值沒變就不算改過：不然打開編輯按「好」也會蓋掉另一台手機改的。
    private static func mapType(
        _ state: AppState,
        id: String,
        now: Millis,
        change: (inout TagType) -> Void
    ) -> AppState {
        var next = state
        for index in next.settings.types.indices where next.settings.types[index].id == id {
            var type = next.settings.types[index]
            change(&type)
            if type != next.settings.types[index] {
                type.mod = stamp(now, after: type.mod)
                next.settings.types[index] = type
            }
        }
        return next
    }

    /// 改名：頭尾空白去掉、最多 typeNameMaxChars 字，空的變「未命名」。
    static func renameType(
        _ state: AppState,
        id: String,
        name: String,
        now: Millis
    ) -> AppState {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = String(trimmed.prefix(Params.typeNameMaxChars))
        return mapType(state, id: id, now: now) {
            $0.name = clean.isEmpty ? Words.unnamedType : clean
        }
    }

    /// 長度只能從刻度選（同一把尺）；刻度外的值不改。
    static func setTypeLen(_ state: AppState, id: String, len: Double, now: Millis) -> AppState {
        guard Params.typeLengths.contains(len) else { return state }
        return mapType(state, id: id, now: now) { $0.len = len }
    }

    /// 刻度上離這個長度最近的一格：舊檔的 12.5 分這種，打開滾輪與刻度尺時停在這裡。
    static func nearestLen(_ len: Double) -> Double {
        let scale = Params.typeLengths
        return min(scale[scale.count - 1], max(scale[0], len.rounded()))
    }

    static func setTypeColor(
        _ state: AppState,
        id: String,
        color: TomatoColor,
        now: Millis
    ) -> AppState {
        mapType(state, id: id, now: now) { $0.color = color }
    }

    /// 刪到剩一個就不能再刪；刪掉的是選中的就退回第一個。
    /// 刪掉的那個不丟，搬到 removedTypes：舊番茄照原本的名字與顏色算，不會併進別的標籤。
    static func removeType(_ state: AppState, id: String, now: Millis) -> AppState {
        let types = state.settings.types.filter { $0.id != id }
        guard !types.isEmpty, types.count != state.settings.types.count else { return state }
        var next = state
        next.settings.types = types
        for gone in state.settings.types where gone.id == id {
            let removedAt = stamp(now, after: gone.mod)
            next.settings.removedTypes.append(RemovedTag(type: gone, removedAt: removedAt))
        }
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
