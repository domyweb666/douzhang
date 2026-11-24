@testable import Douzhang
import Foundation

/// 同步測試共用：兩台的編號、造一顆、造一份狀態、把一份狀態變成「別台」。
enum SyncSample {
    static let phone = "11111111-1111-4111-8111-111111111111"
    static let other = "22222222-2222-4222-8222-222222222222"
    static let third = "33333333-3333-4333-8333-333333333333"

    static func bean(_ id: String, at keptAt: Millis) -> Bean {
        Bean(
            keptAt: keptAt,
            typeId: "t1",
            len: 25,
            clue: "",
            notes: [],
            pings: [],
            flow: 0,
            start: nil,
            id: id
        )
    }

    static func voided(_ id: String, at voidedAt: Millis) -> VoidEntry {
        VoidEntry(voidedAt: voidedAt, typeId: "t1", minute: 8, reason: "訊息", text: "", id: id)
    }

    static func state(_ days: [String: DayRecord]) -> AppState {
        var state = Store.blank()
        state.days = days
        return state
    }

    /// 只有一筆的狀態，放在那一天。
    static func state(_ key: String, _ bean: Bean) -> AppState {
        state([key: DayRecord(beans: [bean])])
    }

    static func state(_ key: String, _ entry: VoidEntry) -> AppState {
        state([key: DayRecord(voids: [entry])])
    }

    /// 別台：走一遍寫檔再讀檔，跟真的同步一樣。
    static func remote(_ state: AppState, device: String = other) -> [SyncFiles.Remote] {
        let files = SyncFiles.outgoing(state, device: device)
        return SyncFiles.remotes(files.mapValues { Data($0.utf8) }, except: phone)
    }

    static func beans(_ state: AppState) -> [Bean] {
        state.days.keys.sorted().flatMap { state.days[$0]?.beans ?? [] }
    }

    static func voids(_ state: AppState) -> [VoidEntry] {
        state.days.keys.sorted().flatMap { state.days[$0]?.voids ?? [] }
    }
}
