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
        ]
    }

    private static func writeTagType(_ type: TagType) -> JSONObject {
        ["id": type.id, "name": type.name, "len": type.len, "color": type.color.rawValue]
    }

    private static func writeRestShort(_ value: RestShort) -> Any {
        if case let .minutes(fixed) = value { return fixed }
        return "auto"
    }

    private static func writeCurrent(_ current: Current) -> JSONObject {
        switch current {
        case let .focus(run): writeFocus(run)
        case let .rest(run): writeRest(run)
        }
    }

    private static func writeFocus(_ run: FocusRun) -> JSONObject {
        [
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
        ]
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
        if let start = bean.start { object["start"] = start }
        return object
    }

    private static func writeVoid(_ entry: VoidEntry) -> JSONObject {
        [
            "t": entry.voidedAt,
            "typeId": entry.typeId,
            "minute": entry.minute,
            "reason": entry.reason,
            "text": entry.text,
        ]
    }
}
