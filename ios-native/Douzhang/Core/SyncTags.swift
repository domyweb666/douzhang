import Foundation

/// 兩台的標籤合成一份。照編號：改得晚的贏，刪得比最後一次改還晚才算刪。
/// 沒動過的預設標籤 mod 是 0，永遠輸給動過的。番茄色不重新分配；同名不同編號的兩個都留。
enum SyncTags {
    /// removedAt 是 nil 就是還在。
    private struct Tag {
        var type: TagType
        var removedAt: Millis?
    }

    /// used：合完的紀錄掛在哪些標籤上。
    static func merged(
        _ local: AppSettings,
        _ remotes: [SyncFiles.Remote],
        used: Set<String>
    ) -> AppSettings {
        let mine = Set(local.types.map(\.id) + local.removedTypes.map(\.type.id))
        let wanted = mine.union(used)
        var table: [String: Tag] = [:]
        add(local.types, local.removedTypes, to: &table)
        for remote in remotes {
            // 別台全新安裝帶來、沒動過的預設標籤，這台沒有的不收：v1 刪標籤沒留紀錄，收了等於復活。
            // 有紀錄掛在上面的要收，不然那些番茄會變成「已刪除的標籤」
            let types = remote.types.filter { $0.mod.rounded(.down) > 0 || wanted.contains($0.id) }
            add(types, remote.removed, to: &table)
        }
        keepOne(local, &table)
        let live = table.filter { $0.value.removedAt == nil }
        var next = local
        next.types = inOrder(local.types.map(\.id), Set(live.keys)).compactMap { live[$0]?.type }
        next.removedTypes = removedList(local, table)
        if live[next.typeId] == nil, let first = next.types.first {
            next.typeId = first.id
        }
        return next
    }

    // MARK: 一個標籤

    private static func add(
        _ types: [TagType],
        _ removed: [RemovedTag],
        to table: inout [String: Tag]
    ) {
        for type in types {
            add(Tag(type: type, removedAt: nil), to: &table)
        }
        for gone in removed {
            add(Tag(type: gone.type, removedAt: goneAt(gone)), to: &table)
        }
    }

    private static func add(_ tag: Tag, to table: inout [String: Tag]) {
        let old = table[tag.type.id]
        table[tag.type.id] = old.map { joined($0, tag) } ?? tag
    }

    /// 刪一定晚於它自己最後一次改：沒記到時刻的舊資料（0）、同一毫秒改完就刪的，都補成晚一毫秒。
    /// 少了這一步，合的順序不同會有人復活、有人沒有。
    private static func goneAt(_ gone: RemovedTag) -> Millis {
        max(gone.removedAt.rounded(.down), gone.type.mod.rounded(.down) + 1)
    }

    private static func joined(_ left: Tag, _ right: Tag) -> Tag {
        let type = loses(left.type, to: right.type) ? right.type : left.type
        guard let gone = SyncJoin.later(left.removedAt, right.removedAt) else {
            return Tag(type: type, removedAt: nil)
        }
        // 刪掉後又改過：復活，那次刪除不用再記
        let revived = gone <= type.mod.rounded(.down)
        return Tag(type: type, removedAt: revived ? nil : gone)
    }

    /// 改得晚的贏；同一刻內容不同就照名字、長度、顏色比，跟順序無關。
    private static func loses(_ left: TagType, to right: TagType) -> Bool {
        let leftMod = left.mod.rounded(.down)
        let rightMod = right.mod.rounded(.down)
        if leftMod != rightMod {
            return leftMod < rightMod
        }
        return content(left).lexicographicallyPrecedes(content(right))
    }

    private static func content(_ type: TagType) -> [String] {
        [type.name, "\(type.len)", type.color.rawValue]
    }

    // MARK: 排回清單

    /// 兩台各刪一半，合起來會一個都不剩：救回本機選中的那個，至少要有一個標籤。
    /// 改動時刻補到刪除那一刻，是真的救回來：不然別台照樣當它刪了，這台一加新標籤它又會不見。
    private static func keepOne(_ local: AppSettings, _ table: inout [String: Tag]) {
        guard !table.values.contains(where: { $0.removedAt == nil }) else { return }
        let picked = local.types.first { $0.id == local.typeId } ?? local.types.first
        guard let picked, var tag = table[picked.id] else { return }
        tag.type.mod = max(tag.type.mod, tag.removedAt ?? 0)
        tag.removedAt = nil
        table[picked.id] = tag
    }

    private static func removedList(_ local: AppSettings, _ table: [String: Tag]) -> [RemovedTag] {
        let gone = table.filter { $0.value.removedAt != nil }
        let mine = local.removedTypes.reduce(into: [String: RemovedTag]()) { $0[$1.type.id] = $1 }
        let ids = inOrder(local.removedTypes.map(\.type.id), Set(gone.keys))
        return ids.compactMap { id -> RemovedTag? in
            guard let tag = gone[id], let when = tag.removedAt else { return nil }
            // 本機記的那一刻算出來一樣就照原樣留著，才不會每次同步都算成有變
            if let kept = mine[id], goneAt(kept) == when {
                return RemovedTag(type: tag.type, removedAt: kept.removedAt)
            }
            return RemovedTag(type: tag.type, removedAt: when)
        }
    }

    /// 本機原本的順序，新來的接在後面照編號排。
    private static func inOrder(_ mine: [String], _ ids: Set<String>) -> [String] {
        var seen: Set<String> = []
        let kept = mine.filter { ids.contains($0) && seen.insert($0).inserted }
        return kept + ids.subtracting(kept).sorted()
    }
}
