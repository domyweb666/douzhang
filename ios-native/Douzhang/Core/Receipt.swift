import Foundation

enum ItemKind {
    case bean, voided
}

/// 時間軸上的一塊：一顆番茄或一筆作廢，在哪個時刻、多長。
struct TimelineItem: Equatable {
    var kind: ItemKind
    var start: Millis
    var end: Millis
    var typeId = ""
    var doing = ""
    var len = 0.0
    var flow = 0.0
    var clue = ""
    var minute = 0
    var reason = ""
    var text = ""
}

/// 一天的收據裡的一列。time 是畫在左邊的時刻：番茄是開始、作廢是作廢那一刻。
/// id 是那一顆的編號：點收下的那一列改字時拿來找它。
struct ReceiptRow: Equatable, Identifiable {
    var kind: ItemKind
    var time: Millis
    var id = ""
    var doing = ""
    var clue = ""
    var isDouble = false
    var flow = 0.0
    var notes = 0
    var pings = 0
    var minute = 0
    var reason = ""
    var text = ""
}

/// 番茄串上的一格：番茄（幾單位）或作廢（空心）。
struct PodItem: Equatable {
    var kind: ItemKind
    var units = 1
}

/// 一天的小計：幾顆、幾分鐘（含延長）。
struct DaySum: Equatable {
    var beans: Int
    var minutes: Double
}

/// 番茄帳 收據計算：一天有沒有紀錄、一天的收據、時間軸、小計。純函式，只讀不寫。
/// 翻自 Expo 版 core/receipt.js 還在用的部分；估算對帳、一週的收據已經拿掉，沒有搬。
enum Receipt {
    /// 一天有沒有東西：有番茄或有作廢。
    static func hasRecord(_ day: DayRecord?) -> Bool {
        guard let day else { return false }
        return !day.beans.isEmpty || !day.voids.isEmpty
    }

    /// 整份資料裡有沒有任何一天有紀錄（番茄架要不要顯示空狀態）。
    static func hasAnyRecord(_ state: AppState) -> Bool {
        state.days.values.contains { hasRecord($0) }
    }

    /// 一筆紀錄做的是什麼：有寫在做什麼就是那句，沒寫就是標籤名。
    static func workName(_ doing: String, type: TagType) -> String {
        doing.isEmpty ? type.name : doing
    }

    /// 番茄串上的格子，依時間排。
    static func podItems(_ day: DayRecord) -> [PodItem] {
        let beans = day.beans.map { bean in
            (time: bean.keptAt, item: PodItem(kind: .bean, units: Store.units(bean.len)))
        }
        let voids = day.voids.map { (time: $0.voidedAt, item: PodItem(kind: .voided)) }
        return (beans + voids).stableSorted { $0.time }.map(\.item)
    }

    /// 一天的收據：番茄與作廢依時間排成一列列。
    static func rows(_ day: DayRecord) -> [ReceiptRow] {
        let beans = day.beans.map { bean in
            let row = ReceiptRow(
                kind: .bean,
                time: bean.start ?? bean.keptAt,
                id: bean.id,
                doing: bean.doing,
                clue: bean.clue,
                isDouble: Store.units(bean.len) > 1,
                flow: bean.flow,
                notes: bean.notes.count,
                pings: bean.pings.count
            )
            return (time: bean.keptAt, row: row)
        }
        let voids = day.voids.map { entry in
            let row = ReceiptRow(
                kind: .voided,
                time: entry.voidedAt,
                doing: entry.doing,
                minute: entry.minute,
                reason: entry.reason,
                text: entry.text
            )
            return (time: entry.voidedAt, row: row)
        }
        return (beans + voids).stableSorted { $0.time }.map(\.row)
    }

    /// 一天的時間軸，依開始時刻排。
    /// 番茄的開始取 start（很舊的資料沒有，用收下時刻倒推長度）；結束＝開始＋長度＋延長，
    /// 不用收下時刻（鈴響後可能很久才收）。作廢：開始＝作廢時刻倒推第幾分鐘。
    static func timeline(_ day: DayRecord?) -> [TimelineItem] {
        guard let day else { return [] }
        let beans = day.beans.map { bean in
            let start = bean.start ?? bean.keptAt - bean.len * Params.msPerMinute
            return TimelineItem(
                kind: .bean,
                start: start,
                end: start + (bean.len + bean.flow) * Params.msPerMinute,
                typeId: bean.typeId,
                doing: bean.doing,
                len: bean.len,
                flow: bean.flow,
                clue: bean.clue
            )
        }
        let voids = day.voids.map { entry in
            TimelineItem(
                kind: .voided,
                start: entry.voidedAt - Double(entry.minute) * Params.msPerMinute,
                end: entry.voidedAt,
                typeId: entry.typeId,
                doing: entry.doing,
                minute: entry.minute,
                reason: entry.reason,
                text: entry.text
            )
        }
        return (beans + voids).stableSorted { $0.start }
    }

    /// 一天的小計。沒番茄回 nil，畫面就不寫（不出現 0）。
    static func daySum(_ day: DayRecord?) -> DaySum? {
        guard let day, !day.beans.isEmpty else { return nil }
        let minutes = day.beans.reduce(0) { $0 + $1.len + $1.flow }
        return DaySum(beans: day.beans.count, minutes: minutes)
    }
}
