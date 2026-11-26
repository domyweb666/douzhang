import Foundation

/// 雲端檔案的寫法與讀法。純函式，不碰檔案系統。
/// `<這台的編號>/2026-11.json` 是那個月的番茄與作廢，`<這台的編號>/tags.json` 是標籤。
/// 每台寫的是自己現在的整份（含從別台合進來的），只寫自己的資料夾。
enum SyncFiles {
    private static let tagsFile = "tags.json"
    private static let fileEnding = ".json"
    /// 日期鍵 YYYY-MM-DD 的前幾個字是月份
    private static let monthChars = 7
    private static let monthPattern = #"^20[0-9]{2}-(0[1-9]|1[0-2])\z"#
    private static let dayPattern = #"^20[0-9]{2}-[0-9]{2}-[0-9]{2}\z"#

    /// 別台的一份：那台資料夾裡讀得懂的檔合起來。
    struct Remote: Equatable {
        var device: String
        var days: [String: DayRecord] = [:]
        var types: [TagType] = []
        var removed: [RemovedTag] = []
    }

    /// 認得的路徑。month 是 nil 就是標籤檔。
    struct Place: Equatable {
        var device: String
        var month: String?
    }

    // MARK: 路徑

    /// 只認「編號／YYYY-MM.json」與「編號／tags.json」，其他一律 nil（CWE-22：不拿外來的字當路徑用）。
    static func locate(_ path: String) -> Place? {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map { String($0) }
        guard parts.count == 2, isDevice(parts[0]) else { return nil }
        if parts[1] == tagsFile {
            return Place(device: parts[0], month: nil)
        }
        guard parts[1].hasSuffix(fileEnding) else { return nil }
        let month = String(parts[1].dropLast(fileEnding.count))
        return matches(month, monthPattern) ? Place(device: parts[0], month: month) : nil
    }

    /// 讀成 UUID 再寫回來要一樣（大小寫不管）：夾帶別的字元就過不了。
    private static func isDevice(_ text: String) -> Bool {
        UUID(uuidString: text)?.uuidString == text.uppercased()
    }

    /// 寫法對、而且真的有這一天（2 月 31 日不算）。
    private static func isDay(_ key: String) -> Bool {
        guard matches(key, dayPattern) else { return false }
        let numbers = key.split(separator: "-").compactMap { Int($0) }
        let parts = DateComponents(year: numbers[0], month: numbers[1], day: numbers[2])
        return parts.isValidDate(in: Calendar(identifier: .gregorian))
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: 寫

    /// 這台要寫的檔：相對路徑 → 內容。鍵排序過，同樣的內容每次寫出來一樣，才比得出有沒有變。
    /// 空的月份不寫；進行中那顆、下一顆要做的事、偏好、測試顆不寫。
    static func outgoing(_ state: AppState, device: String) -> [String: String] {
        var files: [String: String] = [:]
        files["\(device)/\(tagsFile)"] = text([
            "types": state.settings.types.map { StateEncoding.writeTagType(whole($0)) },
            "removed": state.settings.removedTypes.map { StateEncoding.writeRemoved(whole($0)) },
        ])
        for (month, days) in months(state.days) {
            // 現在的紀錄刪不掉，gone 先留空欄：以後能刪時，格式不用再動一次
            files["\(device)/\(month)\(fileEnding)"] = text(["days": days, "gone": JSONObject()])
        }
        return files
    }

    private static func months(_ days: [String: DayRecord]) -> [String: JSONObject] {
        var found: [String: JSONObject] = [:]
        for (key, day) in days where isDay(key) {
            let mine = shared(day)
            if mine == DayRecord() {
                continue
            }
            let exact = DayRecord(
                beans: mine.beans.map(\.wholeMs),
                voids: mine.voids.map(\.wholeMs)
            )
            let month = String(key.prefix(monthChars))
            found[month, default: [:]][key] = StateEncoding.writeDay(exact)
        }
        return found
    }

    /// 時刻寫整毫秒（原因見 SyncRecord.whole）。
    private static func whole(_ type: TagType) -> TagType {
        var next = type
        next.mod = type.mod.rounded(.down)
        return next
    }

    private static func whole(_ gone: RemovedTag) -> RemovedTag {
        RemovedTag(type: whole(gone.type), removedAt: gone.removedAt.rounded(.down))
    }

    private static func text(_ content: JSONObject) -> String? {
        var object = content
        object["v"] = Store.formatVersion
        let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return data.flatMap { String(bytes: $0, encoding: .utf8) }
    }

    // MARK: 讀

    /// 讀到的檔（相對路徑 → 內容）照裝置分好。own 是這台自己的編號，不讀自己寫的。
    /// 路徑不認得、太大、讀不懂、版本比自己新的檔都跳過，不影響別的檔。
    static func remotes(_ files: [String: Data], except own: String) -> [Remote] {
        joined(files.compactMap { piece($0.key, $0.value, except: own) })
    }

    /// 一個檔讀出來的那一份：只有那個月的日子，或只有標籤。跳過的檔是 nil。
    /// 拆成一檔一份，沒改過的檔下一趟才能直接拿上次讀出來的，不用再解析一次。
    static func piece(_ path: String, _ data: Data, except own: String) -> Remote? {
        guard let place = locate(path), place.device.uppercased() != own.uppercased(),
              let object = readable(data) else { return nil }
        var remote = Remote(device: place.device)
        if let month = place.month {
            remote.days = readDays(object["days"], month: month)
        } else {
            let types = StateDecoding.readTagTypes(object["types"])
            let removed = StateUpgrade.readRemoved(object["removed"], live: types)
            remote.types = types.filter { SyncLimits.accepts($0) }
            remote.removed = removed.filter { SyncLimits.accepts($0) }
        }
        return remote
    }

    /// 同一台的每一份併成一份，照編號排。
    /// 一個月一個檔、一台一個標籤檔：日子不會撞到同一天，標籤只有一份，先後不影響結果。
    static func joined(_ pieces: [Remote]) -> [Remote] {
        var found: [String: Remote] = [:]
        for piece in pieces {
            var remote = found[piece.device] ?? Remote(device: piece.device)
            remote.days.merge(piece.days) { first, _ in first }
            remote.types += piece.types
            remote.removed += piece.removed
            found[piece.device] = remote
        }
        return found.values.sorted { $0.device < $1.device }
    }

    private static func readable(_ data: Data) -> JSONObject? {
        guard data.count <= Params.importMaxBytes,
              let object = (try? JSONSerialization.jsonObject(with: data)) as? JSONObject,
              let version = JSONRead.int(object["v"]),
              version <= Store.formatVersion else { return nil }
        return object
    }

    private static func readDays(_ value: Any?, month: String) -> [String: DayRecord] {
        var days: [String: DayRecord] = [:]
        for (key, raw) in JSONRead.object(value) ?? [:] {
            guard key.hasPrefix(month), isDay(key),
                  let object = JSONRead.object(raw) else { continue }
            let day = shared(StateDecoding.readDay(object))
            days[key] = DayRecord(
                beans: day.beans.filter { SyncLimits.accepts($0) },
                voids: day.voids.filter { SyncLimits.accepts($0) }.map { SyncLimits.clamped($0) }
            )
        }
        return days
    }

    /// 同步的只有：有編號的（沒有就合不起來）、不是開發期測試顆的。
    private static func shared(_ day: DayRecord) -> DayRecord {
        DayRecord(
            beans: day.beans.filter { !$0.id.isEmpty && $0.typeId != Machine.devTypeId },
            voids: day.voids.filter { !$0.id.isEmpty && $0.typeId != Machine.devTypeId }
        )
    }
}
