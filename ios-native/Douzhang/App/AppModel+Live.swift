import Foundation

/// 鎖定畫面與動態島的卡片（Live Activity）跟 app 的接頭。卡片怎麼開、換、收在 LiveIsland。
extension AppModel {
    /// 整個 app 用的那一份。卡片上按「開始」時系統可能在背景叫醒 app、畫面還沒出來，
    /// 動作要找得到同一份狀態，所以不在畫面的 @State 裡建。
    static let main = AppModel()

    /// 卡片上按了「開始」：同一個標籤開始下一顆，走跟主畫面開始鈕同一個動作（通知、擋 app 照舊）。
    /// 已經不在待機（例如休息完自己開始了）就只把卡片對齊現在。
    func startFromLive(typeId: String) async {
        await loadOnce()
        guard loaded else { return }
        if Machine.phaseOf(settled(), now: TimeText.nowMillis()) == .idle {
            await startNow(typeId: typeId)
        } else {
            live.sync(state, now: TimeText.nowMillis(), force: true)
        }
        await live.flush()
    }
}

/// StartNextIntent 在 app 這邊的那一頭（擴充那邊有一份空的，系統不會在擴充裡叫）。
enum LiveStart {
    @MainActor
    static func run(typeId: String) async {
        await AppModel.main.startFromLive(typeId: typeId)
    }
}
