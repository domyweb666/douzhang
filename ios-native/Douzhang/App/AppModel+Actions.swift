import Foundation

/// 畫面叫的動作。每個都先用純函式算新狀態，再 commit（存檔＋對齊通知）。
/// 要看時鐘的動作都在「按下那一刻」看。
extension AppModel {
    // MARK: 一顆的一生

    /// 開始一顆。只有第一次（還沒問過）才會真的跳通知權限的框；問不到也照樣開始。
    func start(typeId: String? = nil) {
        Task {
            let granted = await notifier.askOnce()
            notif = granted ? .granted : .denied
            let zone = Store.zoneNow()
            idleLine = nil
            commit(Machine.start(settled(), now: TimeText.nowMillis(), typeId: typeId, zone: zone))
        }
    }

    func keep(text: String) {
        commit(Machine.keep(settled(), now: TimeText.nowMillis(), text: text))
        pulses.kept += 1
    }

    func backFromRest() {
        commit(Machine.backFromRest(settled()))
    }

    func flow(minutes: Int) {
        commit(Machine.flow(settled(), now: TimeText.nowMillis(), minutes: Double(minutes)))
    }

    /// 每個字都存：殺掉再開草稿才在。
    func setDraft(_ text: String) {
        commit(Machine.setDraft(settled(), text: text))
    }

    /// 計時中記一筆：點種類那一下先記一筆沒寫字的。
    func jot(_ kind: JotKind) {
        commit(Machine.jot(settled(), kind: kind))
    }

    /// 剛記的那一筆改種類，或補上那一行。
    func amendJot(from: JotKind, into: JotKind, text: String) {
        commit(Machine.amendJot(settled(), from: from, into: into, text: text))
    }

    func markDone() {
        commit(Machine.markDone(settled(), now: TimeText.nowMillis()))
    }

    /// 作廢這顆，記原因與那一行。回待機後開始鈕上面多一行：這週同一個原因第幾顆。
    /// 沒留紀錄（開始不到五分鐘）或沒選原因就沒有那一行。
    func voidBean(reason: String, text: String) {
        let now = TimeText.nowMillis()
        let next = Machine.voidBean(settled(), now: now, reason: reason, text: text)
        let recorded = next.days != state.days
        commit(next)
        let nth = Insights.voidsThisWeek(next, reason: reason, todayKey: Store.dayKey(now))
        idleLine = recorded ? nth.map { Words.voidedThisWeek($0, reason: reason) } : nil
        pulses.removed += 1
    }

    /// 停下來：開始不到五分鐘，什麼都不記。
    func stopEarly() {
        commit(Machine.voidBean(settled(), now: TimeText.nowMillis(), early: true))
        pulses.removed += 1
    }

    /// 改「正在做什麼」：計時中改這一顆的，同時留給下一顆。
    func setDoing(_ text: String) {
        commit(Machine.setDoing(settled(), text: text))
    }

    // MARK: 標籤

    func pickType(_ id: String) {
        commit(SettingsLogic.pickType(settled(), typeId: id))
    }

    /// 加一個標籤，回它的 id（接著直接開它的編輯）。
    func addType() -> String {
        let next = SettingsLogic.addType(settled(), now: TimeText.nowMillis())
        commit(next)
        return next.settings.types.last?.id ?? ""
    }

    func renameType(_ id: String, name: String) {
        commit(SettingsLogic.renameType(settled(), id: id, name: name))
    }

    func setTypeLen(_ id: String, len: Double) {
        commit(SettingsLogic.setTypeLen(settled(), id: id, len: len))
    }

    func setTypeColor(_ id: String, color: TomatoColor) {
        commit(SettingsLogic.setTypeColor(settled(), id: id, color: color))
    }

    func removeType(_ id: String) {
        commit(SettingsLogic.removeType(settled(), id: id, now: TimeText.nowMillis()))
        pulses.removed += 1
    }

    // MARK: 設定

    func setRestShort(_ value: RestShort) {
        commit(SettingsLogic.setRestShort(settled(), value: value))
    }

    func setRestLongEvery(_ every: Int) {
        commit(SettingsLogic.setRestLongEvery(settled(), every: every))
    }

    func setRestLongMinutes(_ minutes: Int) {
        commit(SettingsLogic.setRestLongMinutes(settled(), minutes: minutes))
    }

    /// 單純的開關與選項（聲音、傾斜、自動開始、休息怎麼結束、白噪音）：直接改那一欄。
    func update(_ change: (inout AppSettings) -> Void) {
        var next = settled()
        change(&next.settings)
        commit(next)
    }
}
