import Foundation

/// 讀檔之後補的三件事（格式 v2，規格在 .analytics/04-資料結構.md）：
/// 沒有編號的紀錄補編號、每筆放回「開始那天」的格子、讀出刪掉的標籤。
/// 都是純函式：同一份資料每次讀出來結果一樣，讀進來再寫出去也一樣。
enum StateUpgrade {
    // MARK: 編號

    /// 舊資料沒有編號：照開始時刻（沒有就照收下、作廢的時刻）補一個。同一份檔裡撞到就加序號。
    static func numbered(_ days: [String: DayRecord]) -> [String: DayRecord] {
        var used = Set(days.values.flatMap { $0.beans.map(\.id) + $0.voids.map(\.id) })
        var next = days
        for key in days.keys.sorted() {
            guard var record = next[key] else { continue }
            for index in record.beans.indices where record.beans[index].id.isEmpty {
                let bean = record.beans[index]
                record.beans[index].id = fresh(bean.start ?? bean.keptAt, used: &used)
            }
            for index in record.voids.indices where record.voids[index].id.isEmpty {
                let entry = record.voids[index]
                record.voids[index].id = fresh(entry.start ?? entry.voidedAt, used: &used)
            }
            next[key] = record
        }
        return next
    }

    /// 進行中那顆沒有編號（舊版開始的）：照它的開始時刻補，跟新開始的同一種寫法。
    static func numbered(_ current: Current?) -> Current? {
        guard case var .focus(run)? = current, run.id.isEmpty else { return current }
        run.id = Store.recordId(run.startedAt)
        return .focus(run)
    }

    private static func fresh(_ time: Millis, used: inout Set<String>) -> String {
        let base = Store.recordId(time)
        var candidate = base
        var count = 1
        while used.contains(candidate) {
            count += 1
            candidate = "\(base)-\(count)"
        }
        used.insert(candidate)
        return candidate
    }

    // MARK: 哪一天

    /// 每筆放回它開始那天的格子。「哪一天」不照檔案裡的鍵，照開始時刻與當時的時區算（Store.dayKey），
    /// 所以以後改換日時間不用動資料。沒有時區的舊紀錄留在原本的格子：那個鍵是當時當地日期唯一的紀錄。
    static func regrouped(_ days: [String: DayRecord]) -> [String: DayRecord] {
        var next: [String: DayRecord] = [:]
        for key in days.keys.sorted() {
            guard let record = days[key] else { continue }
            // 原本的格子留著（就算搬空了）：讀進來再寫出去才會一模一樣
            next[key] = next[key] ?? DayRecord()
            for bean in record.beans {
                let day = home(bean.start, zone: bean.zone) ?? key
                next[day, default: DayRecord()].beans.append(bean)
            }
            for entry in record.voids {
                let day = home(entry.start, zone: entry.zone) ?? key
                next[day, default: DayRecord()].voids.append(entry)
            }
        }
        return next
    }

    /// 有開始時刻、也有認得的時區才算得出來；缺一個就回 nil（留在原本的格子）。
    private static func home(_ start: Millis?, zone: String?) -> String? {
        guard let start, let zone, TimeZone(identifier: zone) != nil else { return nil }
        return Store.dayKey(start, zone: zone)
    }

    // MARK: 刪掉的標籤

    /// 讀出刪掉的標籤。跟現有標籤同編號的不要（同一個標籤不會又在又被刪）。
    static func readRemoved(_ value: Any?, live: [TagType]) -> [RemovedTag] {
        let liveIds = Set(live.map(\.id))
        var list: [RemovedTag] = []
        for raw in JSONRead.objects(value) {
            guard let type = StateDecoding.readTagTypes([raw]).first,
                  !liveIds.contains(type.id) else { continue }
            list.append(RemovedTag(type: type, removedAt: JSONRead.number(raw["removedAt"]) ?? 0))
        }
        return list
    }
}
