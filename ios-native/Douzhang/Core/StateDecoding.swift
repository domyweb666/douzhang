import Foundation

/// 把外部讀進來的狀態補成完整格式（Expo 版 store.js 的 normalize）。缺什麼補什麼，型別不對就用預設。
/// 格式跟 Expo 版、PWA 匯出的備份相同。只讀現在還在用的欄位：
/// 收工、估幾顆、葉子那幾欄（clue、planted、tasks、closed、leaf、closeTime）不讀也不寫回去。
enum StateDecoding {
    struct NotAState: Error {}

    /// 讀本機存著的字。讀不懂就丟例外，呼叫端要把原本存的東西原封不動留著。
    static func parse(_ text: String) throws -> AppState {
        try normalize(JSONSerialization.jsonObject(with: Data(text.utf8)))
    }

    /// 讀備份檔的字（匯入）：多要求有數字的 v。讀不懂就丟例外，資料不動。
    static func parseBackup(_ text: String) throws -> AppState {
        let raw = try JSONSerialization.jsonObject(with: Data(text.utf8))
        guard let object = raw as? JSONObject,
              JSONRead.number(object["v"]) != nil else { throw NotAState() }
        return try normalize(object)
    }

    static func normalize(_ raw: Any) throws -> AppState {
        guard let object = raw as? JSONObject, let rawSettings = JSONRead.object(
            object["settings"]
        ),
            let rawDays = JSONRead.object(object["days"]) else { throw NotAState() }
        let settings = readSettings(rawSettings)
        var days: [String: DayRecord] = [:]
        for (key, value) in rawDays {
            if let rawDay = JSONRead.object(value) {
                days[key] = readDay(rawDay)
            }
        }
        // 補編號、把每筆放回它「開始那天」的格子：哪一天是讀的時候算的（StateUpgrade）
        return AppState(
            settings: settings,
            current: StateUpgrade.numbered(readCurrent(object["current"], settings: settings)),
            days: StateUpgrade.regrouped(StateUpgrade.numbered(days)),
            lastLine: JSONRead.int(object["lastLine"]) ?? -1,
            doing: JSONRead.string(object["doing"]) ?? ""
        )
    }

    /// 設定這一層：每欄驗型別、不對就用預設；選到的標籤不存在就退回第一個。
    static func readSettings(_ raw: JSONObject) -> AppSettings {
        let base = Store.blankSettings()
        let types = readTagTypes(raw["types"])
        // 會進算術的（休息幾分鐘、每幾顆）只收刻度上的值，其他一律預設
        let every = onScale(Params.restLongEveryOptions, raw["restLongEvery"])
        let longMinutes = onScale(Params.restLongMinuteOptions, raw["restLongMinutes"])
        let ambience = JSONRead.string(raw["ambience"]).flatMap(AmbienceKind.init(rawValue:))
        let volume = JSONRead.string(raw["ambienceVolume"]).flatMap(AmbienceLevel.init(rawValue:))
        let restMode = JSONRead.string(raw["restMode"]).flatMap(RestMode.init(rawValue:))
        let live = types.isEmpty ? base.types : types
        var settings = AppSettings(
            types: live,
            typeId: JSONRead.string(raw["typeId"]) ?? base.typeId,
            restMode: restMode ?? base.restMode,
            sound: JSONRead.bool(raw["sound"], or: base.sound),
            demo: readDemo(raw["demo"]),
            tilt: JSONRead.bool(raw["tilt"], or: base.tilt),
            restShort: readRestShort(raw["restShort"]),
            restLongEvery: every ?? base.restLongEvery,
            restLongMinutes: longMinutes ?? base.restLongMinutes,
            shield: JSONRead.bool(raw["shield"], or: base.shield),
            ambience: ambience ?? base.ambience,
            ambienceVolume: volume ?? base.ambienceVolume,
            autoNext: JSONRead.bool(raw["autoNext"], or: base.autoNext),
            removedTypes: StateUpgrade.readRemoved(raw["removedTypes"], live: live)
        )
        if !settings.types.contains(where: { $0.id == settings.typeId }) {
            settings.typeId = settings.types[0].id
        }
        return settings
    }

    /// 標籤：要有字串的 id 與名字才算；長度不是數字用 25；沒有顏色的依序分配，一開始就不同色。
    /// 沒有「幾時改過」的（v1、v2）由 StateUpgrade 補。
    static func readTagTypes(_ value: Any?) -> [TagType] {
        let colors = TomatoColor.allCases
        var types: [TagType] = []
        for raw in JSONRead.objects(value) {
            guard let id = JSONRead.string(raw["id"]),
                  let name = JSONRead.string(raw["name"]) else { continue }
            let named = JSONRead.string(raw["color"]).flatMap(TomatoColor.init(rawValue:))
            var type = TagType(
                id: id,
                name: name,
                len: JSONRead.number(raw["len"]) ?? Store.defaultType.len,
                color: named ?? colors[types.count % colors.count]
            )
            type.mod = StateUpgrade.tagMod(type, stored: JSONRead.number(raw["mod"]))
            types.append(type)
        }
        return types
    }

    private static func onScale(_ scale: [Int], _ value: Any?) -> Int? {
        guard let found = JSONRead.int(value), scale.contains(found) else { return nil }
        return found
    }

    private static func readRestShort(_ value: Any?) -> RestShort {
        guard let minutes = JSONRead.int(value) else { return .auto }
        let fixed = RestShort.minutes(minutes)
        return Params.restShortOptions.contains(fixed) ? fixed : .auto
    }

    /// 測試模式：開發版照存檔讀；正式 build 一律關（正式版不帶試玩速度）。
    private static func readDemo(_ value: Any?) -> Bool {
        #if DEBUG
            return JSONRead.bool(value, or: false)
        #else
            return false
        #endif
    }

    static func readDay(_ raw: JSONObject) -> DayRecord {
        DayRecord(
            beans: JSONRead.objects(raw["beans"]).map(readBean),
            voids: JSONRead.objects(raw["voids"]).map(readVoid)
        )
    }

    /// 每一顆的長度之後要進算術，不是數字就補成 25。收下時刻不是數字的顆留著（算那天的顆數），時刻當 0。
    private static func readBean(_ raw: JSONObject) -> Bean {
        let start = JSONRead.number(raw["start"])
        return Bean(
            keptAt: JSONRead.number(raw["t"]) ?? 0,
            typeId: JSONRead.string(raw["typeId"]) ?? "",
            len: JSONRead.number(raw["len"]) ?? Store.defaultType.len,
            clue: JSONRead.string(raw["clue"]) ?? "",
            notes: JSONRead.strings(raw["notes"]),
            pings: JSONRead.strings(raw["pings"]),
            flow: JSONRead.number(raw["flow"]) ?? 0,
            start: start == 0 ? nil : start,
            id: JSONRead.string(raw["id"]) ?? "",
            zone: JSONRead.string(raw["tz"]),
            done: JSONRead.bool(raw["done"], or: false),
            doneAt: JSONRead.number(raw["doneAt"]),
            doing: JSONRead.string(raw["doing"]) ?? ""
        )
    }

    private static func readVoid(_ raw: JSONObject) -> VoidEntry {
        VoidEntry(
            voidedAt: JSONRead.number(raw["t"]) ?? 0,
            typeId: JSONRead.string(raw["typeId"]) ?? "",
            minute: JSONRead.int(raw["minute"]) ?? 0,
            reason: JSONRead.string(raw["reason"]) ?? "",
            text: JSONRead.string(raw["text"]) ?? "",
            id: JSONRead.string(raw["id"]) ?? "",
            start: JSONRead.number(raw["start"]),
            zone: JSONRead.string(raw["tz"]),
            len: JSONRead.number(raw["len"]),
            notes: JSONRead.strings(raw["notes"]),
            pings: JSONRead.strings(raw["pings"]),
            doing: JSONRead.string(raw["doing"]) ?? ""
        )
    }

    /// 進行中那顆。PWA 的寫法不一樣，匯入時要轉：延長中是 flow、響了是 bell，這裡都存成計時中。
    static func readCurrent(_ value: Any?, settings: AppSettings) -> Current? {
        guard let raw = JSONRead.object(value) else { return nil }
        switch JSONRead.string(raw["phase"]) ?? "" {
        case "focus", "flow", "bell": return readFocus(raw).map(Current.focus)
        case "rest": return readRest(raw, settings: settings).map(Current.rest)
        default: return nil
        }
    }

    /// 會進算術的欄位（開始、結束時刻、長度）不是數字就整顆不要，回待機。
    private static func readFocus(_ raw: JSONObject) -> FocusRun? {
        guard let startedAt = JSONRead.number(raw["startedAt"]),
              let endAt = JSONRead.number(raw["endAt"]),
              let len = JSONRead.number(raw["len"]) else { return nil }
        let wasFlow = JSONRead.string(raw["phase"]) == "flow"
        return FocusRun(
            typeId: JSONRead.string(raw["typeId"]) ?? "",
            len: len,
            startedAt: startedAt,
            endAt: endAt,
            notes: JSONRead.strings(raw["notes"]),
            pings: JSONRead.strings(raw["pings"]),
            flowed: wasFlow || JSONRead.bool(raw["flowed"], or: false),
            flowMin: JSONRead.number(raw["flowMin"]) ?? 0,
            done: JSONRead.bool(raw["done"], or: false),
            draft: JSONRead.string(raw["draft"]) ?? "",
            id: JSONRead.string(raw["id"]) ?? "",
            zone: JSONRead.string(raw["tz"]),
            doneAt: JSONRead.number(raw["doneAt"]),
            doing: JSONRead.string(raw["doing"]) ?? ""
        )
    }

    /// 「我自己決定」的休息 PWA 也存了結束時刻，這裡一律當沒有（不自己結束）。
    private static func readRest(_ raw: JSONObject, settings: AppSettings) -> RestRun? {
        guard let restStart = JSONRead.number(raw["restStart"]) else { return nil }
        let endAt = JSONRead.number(raw["endAt"])
        let isOwn = settings.restMode == .own
        if !isOwn, endAt == nil {
            return nil
        }
        return RestRun(
            typeId: JSONRead.string(raw["typeId"]) ?? "",
            len: JSONRead.number(raw["len"]) ?? Store.defaultType.len,
            restStart: restStart,
            endAt: isOwn ? nil : endAt,
            long: JSONRead.bool(raw["long"], or: false),
            msg: JSONRead.string(raw["msg"]) ?? ""
        )
    }
}
