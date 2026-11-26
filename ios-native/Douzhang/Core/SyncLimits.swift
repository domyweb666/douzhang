import Foundation

/// 讀雲端檔時擋極端數字：別台的壞檔不准讓這台每次打開都當掉。
/// 範圍外的那筆（或那個標籤）跳過，其他照收；沒有的欄位（nil）不擋。
enum SyncLimits {
    static func accepts(_ bean: Bean) -> Bool {
        isMinutes(bean.len) && isMinutes(bean.flow) && isTime(bean.keptAt)
            && isTime(bean.start) && isTime(bean.doneAt) && isTime(bean.wordsEditedAt)
    }

    static func accepts(_ entry: VoidEntry) -> Bool {
        isMinutes(entry.len) && isTime(entry.voidedAt) && isTime(entry.start)
    }

    /// 作廢在第幾分鐘夾住就好，不整筆擋：半頁開著放超過一天、手機時鐘往回調都會超出來，
    /// 那是真的紀錄；這個數字只拿來顯示與倒推時間軸。
    static func clamped(_ entry: VoidEntry) -> VoidEntry {
        var next = entry
        let range = Params.cloudVoidMinutes
        next.minute = min(range.upperBound, max(range.lowerBound, entry.minute))
        return next
    }

    static func accepts(_ type: TagType) -> Bool {
        Params.cloudTagMinutes.contains(type.len) && isTime(type.mod)
    }

    static func accepts(_ gone: RemovedTag) -> Bool {
        accepts(gone.type) && isTime(gone.removedAt)
    }

    private static func isMinutes(_ value: Double?) -> Bool {
        value.map { Params.cloudMinutes.contains($0) } ?? true
    }

    private static func isTime(_ value: Millis?) -> Bool {
        value.map { Params.cloudTimes.contains($0) } ?? true
    }
}
