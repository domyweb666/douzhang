import Foundation

/// 把狀態寫成 JSON。欄位名跟 Expo 版相同，這裡匯出的備份 Expo 版也讀得進去。
enum StateEncoding {
    struct NotText: Error {}

    static func text(_ state: AppState) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object(state))
        guard let text = String(bytes: data, encoding: .utf8) else { throw NotText() }
        return text
    }

    static func object(_ state: AppState) -> JSONObject {
        var object: JSONObject = [
            "v": Store.formatVersion,
            "settings": writeSettings(state.settings),
            "days": state.days.mapValues(writeDay),
            "lastLine": state.lastLine,
            "doing": state.doing,
        ]
        if let current = state.current {
            object["current"] = writeCurrent(current)
        } else {
            object["current"] = NSNull()
        }
        return object
    }

    private static func writeSettings(_ settings: AppSettings) -> JSONObject {
        [
            "types": settings.types.map(writeTagType),
            "typeId": settings.typeId,
            "restMode": settings.restMode.rawValue,
            "sound": settings.sound,
            "demo": settings.demo,
            "tilt": settings.tilt,
            "restShort": writeRestShort(settings.restShort),
            "restLongEvery": settings.restLongEvery,
            "restLongMinutes": settings.restLongMinutes,
            "shield": settings.shield,
            "ambience": settings.ambience.rawValue,
            "ambienceVolume": settings.ambienceVolume.rawValue,
            "autoNext": settings.autoNext,
            "removedTypes": settings.removedTypes.map(writeRemoved),
        ]
    }

    /// 刪掉的標籤另外放一個陣列：舊版不認得這一欄，頂多看不到，不會把它當成還在。
    private static func writeRemoved(_ removed: RemovedTag) -> JSONObject {
        var object = writeTagType(removed.type)
        object["removedAt"] = removed.removedAt
        return object
    }

    private static func writeTagType(_ type: TagType) -> JSONObject {
        ["id": type.id, "name": type.name, "len": type.len, "color": type.color.rawValue]
    }

    private static func writeRestShort(_ value: RestShort) -> Any {
        if case let .minutes(fixed) = value {
            return fixed
        }
        return "auto"
    }

    private static func writeCurrent(_ current: Current) -> JSONObject {
        switch current {
        case let .focus(run): writeFocus(run)
        case let .rest(run): writeRest(run)
        }
    }

    private static func writeFocus(_ run: FocusRun) -> JSONObject {
        var object: JSONObject = [
            "phase": "focus",
            "typeId": run.typeId,
            "len": run.len,
            "startedAt": run.startedAt,
            "endAt": run.endAt,
            "notes": run.notes,
            "pings": run.pings,
            "flowed": run.flowed,
            "flowMin": run.flowMin,
            "done": run.done,
            "draft": run.draft,
            "id": run.id,
            "doing": run.doing,
        ]
        object["tz"] = run.zone
        object["doneAt"] = run.doneAt
        return object
    }

    private static func writeRest(_ run: RestRun) -> JSONObject {
        var object: JSONObject = [
            "phase": "rest",
            "typeId": run.typeId,
            "len": run.len,
            "restStart": run.restStart,
            "long": run.long,
            "msg": run.msg,
        ]
        if let endAt = run.endAt {
            object["endAt"] = endAt
        } else {
            object["endAt"] = NSNull()
        }
        return object
    }

    private static func writeDay(_ day: DayRecord) -> JSONObject {
        ["beans": day.beans.map(writeBean), "voids": day.voids.map(writeVoid)]
    }

    private static func writeBean(_ bean: Bean) -> JSONObject {
        var object: JSONObject = [
            "t": bean.keptAt,
            "typeId": bean.typeId,
            "len": bean.len,
            "clue": bean.clue,
            "notes": bean.notes,
            "pings": bean.pings,
            "flow": bean.flow,
        ]
        // 沒有的就不寫這一欄（設成 nil 等於不放進去）：不知道的不猜
        object["start"] = bean.start
        object["tz"] = bean.zone
        object["doneAt"] = bean.doneAt
        if bean.done {
            object["done"] = true
        }
        if !bean.id.isEmpty {
            object["id"] = bean.id
        }
        if !bean.doing.isEmpty {
            object["doing"] = bean.doing
        }
        return object
    }

    private static func writeVoid(_ entry: VoidEntry) -> JSONObject {
        var object: JSONObject = [
            "t": entry.voidedAt,
            "typeId": entry.typeId,
            "minute": entry.minute,
            "reason": entry.reason,
            "text": entry.text,
            "notes": entry.notes,
            "pings": entry.pings,
        ]
        object["start"] = entry.start
        object["tz"] = entry.zone
        object["len"] = entry.len
        if !entry.id.isEmpty {
            object["id"] = entry.id
        }
        if !entry.doing.isEmpty {
            object["doing"] = entry.doing
        }
        return object
    }
}
