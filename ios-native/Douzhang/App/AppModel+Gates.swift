import FamilyControls
import UIKit

/// 跟著狀態走的三樣：白噪音、擋 app、聚焦模式。每次狀態或哪一態變了就對齊一次；
/// 各自分辨答案有沒有變，沒變就不去吵系統（存草稿每個字都會走到這裡）。
extension AppModel {
    func syncGates() {
        guard loaded else { return }
        let time = TimeText.nowMillis()
        let settings = state.settings
        // 待機時開著背景音半頁：邊選邊聽。計時中本來就在播
        let isPreview = previewing && state.current == nil
        let kind = isPreview ? settings.ambience : Gates.ambience(state, now: time)
        soundscape.apply(kind, level: settings.ambienceVolume)
        // 響的那一刻 app 在背景的話時鐘不走，擋板要等回到番茄帳才解開（第一版的取捨）；
        // 白噪音在背景播的時候 app 還醒著，到點那一刻聲音會自己停，擋板也跟著解開
        shield.apply(Gates.shouldShield(state, now: time))
        syncZen()
    }

    // MARK: 白噪音

    func previewAmbience(_ isOn: Bool) {
        previewing = isOn
        syncGates()
    }

    // MARK: 擋 app

    /// 開關：要打開才問授權；不允許就不開。回有沒有授權，設定頁靠它決定要不要寫那一行。
    func setShield(_ isOn: Bool) async -> Bool {
        if isOn {
            let allowed = await shield.authorize()
            if !allowed { return false }
        }
        update { $0.shield = isOn }
        return true
    }

    /// 選完要擋的：存起來、更新選了幾項；計時中改的就照新選的重蓋一次。
    func shieldPicked(_ selection: FamilyActivitySelection) {
        shield.saveSelection(selection)
        shieldCount = shield.count()
        shield.reapply(Gates.shouldShield(state, now: TimeText.nowMillis()))
    }

    func forgetShield() {
        shield.forget()
        shieldCount = 0
    }

    // MARK: 聚焦模式

    /// 計時中那顆的記號：再做一下會換結束時刻，所以延長後是新的記號。沒在計時是 nil。
    var zenKey: String? {
        guard phase == .focus, let run = state.focusRun else { return nil }
        return "\(run.startedAt)-\(run.endAt)"
    }

    /// 聚焦只跟著那一顆：響了、結束、再做一下都從直向重新開始。
    var zenOn: Bool {
        zenKey != nil && zenFor == zenKey
    }

    func enterZen() {
        zenFor = zenKey
        syncZen()
    }

    /// 離開聚焦回主畫面。sheet 是回去要直接開的半頁（記一筆、結束這顆），沒有就只是回去。
    func leaveZen(opening sheet: HomeSheet? = nil) {
        homeSheetRequest = sheet
        page = .home
        zenFor = nil
        syncZen()
    }

    /// 聚焦模式開著：畫面轉橫、螢幕不自己熄。計時中一直看手機是直拿還是橫放：
    /// 橫放就進聚焦，直拿回來就離開。
    private func syncZen() {
        let isOn = zenOn
        ScreenTurn.lock(isOn ? .landscape : .portrait)
        if UIApplication.shared.isIdleTimerDisabled != isOn {
            UIApplication.shared.isIdleTimerDisabled = isOn
        }
        guard let key = zenKey else {
            poseWatch.stop()
            return
        }
        poseWatch.start(for: key) { [weak self] pose in
            switch pose {
            case .landscape: self?.enterZen()
            case .portrait: self?.leaveZen()
            }
        }
    }
}
