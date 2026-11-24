import Foundation

/// 把別台的紀錄合進本機。純函式：只動番茄、作廢、標籤，
/// 不碰進行中那顆、下一顆要做的事、任何偏好（選中的標籤被刪了才退回第一個）。
enum SyncMerge {
    /// 一筆紀錄跟它在哪一天。
    private struct Filed {
        var day: String
        var record: SyncRecord
    }

    /// 沒有別台就原封不動（本機那份不整理、不重排）。
    static func merged(_ local: AppState, _ remotes: [SyncFiles.Remote]) -> AppState {
        guard !remotes.isEmpty else { return local }
        var next = local
        next.days = days(local.days, remotes.map(\.days))
        let used = next.days.values.flatMap { $0.beans.map(\.typeId) + $0.voids.map(\.typeId) }
        next.settings = SyncTags.merged(local.settings, remotes, used: Set(used))
        return next
    }

    private static func days(
        _ local: [String: DayRecord],
        _ remotes: [[String: DayRecord]]
    ) -> [String: DayRecord] {
        var table: [String: Filed] = [:]
        add(local, to: &table, isLocal: true)
        for remote in remotes {
            add(remote, to: &table, isLocal: false)
        }
        // 本機原本的格子留著（就算空了），沒有編號的也留著：同步不丟本機的東西
        var next = local.mapValues { day in
            DayRecord(
                beans: day.beans.filter(\.id.isEmpty),
                voids: day.voids.filter(\.id.isEmpty)
            )
        }
        for filed in table.values {
            switch filed.record {
            case let .kept(bean): next[filed.day, default: DayRecord()].beans.append(bean)
            case let .voided(entry): next[filed.day, default: DayRecord()].voids.append(entry)
            }
        }
        return next.mapValues { inOrder($0) }
    }

    /// 沒有編號的不收。本機的格子讀檔時就照開始那天歸好了（StateUpgrade），不用每次同步都重算一遍。
    private static func add(
        _ days: [String: DayRecord],
        to table: inout [String: Filed],
        isLocal: Bool
    ) {
        for (key, day) in days {
            let beans = day.beans.map { SyncRecord.kept($0) }
            let voids = day.voids.map { SyncRecord.voided($0) }
            for record in beans + voids where !record.id.isEmpty {
                if let old = table[record.id] {
                    table[record.id] = joined(old, Filed(day: key, record: record))
                } else {
                    let home = isLocal ? key : record.home ?? key
                    table[record.id] = Filed(day: home, record: record)
                }
            }
        }
    }

    /// 同編號的兩份。只差不到一毫秒的就是同一份：留本機那份，才不會每次同步都算成有變。
    private static func joined(_ old: Filed, _ fresh: Filed) -> Filed {
        let isSame = old.record.whole == fresh.record.whole
        if isSame, old.day == fresh.day {
            return old
        }
        let record = isSame ? old.record : SyncJoin.records(old.record, fresh.record)
        return Filed(day: record.home ?? earlierDay(old, fresh), record: record)
    }

    /// 算不出哪一天的舊紀錄：兩邊的鍵不同取較早的。一邊收下一邊作廢就照收下那邊的鍵，
    /// 作廢那筆的鍵不算：它已經輸了，算進來結果會看合併順序。
    private static func earlierDay(_ old: Filed, _ fresh: Filed) -> String {
        switch (old.record, fresh.record) {
        case (.kept, .voided): old.day
        case (.voided, .kept): fresh.day
        default: min(old.day, fresh.day)
        }
    }

    /// 收下的先後（Machine.keep 一顆一顆接在後面）：合完跟只在一台收的順序一樣。
    /// 照整毫秒比：本機帶小數、別台沒有，同一毫秒的兩筆才不會一台一個順序。
    private static func inOrder(_ day: DayRecord) -> DayRecord {
        DayRecord(
            beans: day.beans.sorted {
                ($0.keptAt.rounded(.down), $0.id) < ($1.keptAt.rounded(.down), $1.id)
            },
            voids: day.voids.sorted {
                ($0.voidedAt.rounded(.down), $0.id) < ($1.voidedAt.rounded(.down), $1.id)
            }
        )
    }
}
