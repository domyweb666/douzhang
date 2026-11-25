import Foundation
import UserNotifications

/// 通知權限三態。只有 denied 才顯示「沒開・打開」：還沒問過時，系統設定裡還沒有番茄帳的通知那一列。
enum NotifStatus {
    case granted, denied, undetermined
}

/// 前景收到通知：不跳橫幅、不進清單，只出聲（畫面那一刻已經是鈴響頁）。
final class ForegroundQuiet: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.sound]
    }
}

/// 跟系統的通知打交道。該排什麼由 Notify.planned 算；這裡每次都「全部取消再排」，不做差量。
/// 核心迴圈不靠通知：前景時 app 自己切鈴響頁，排不進去也照樣計時。
@MainActor
final class Notifier {
    private let center = UNUserNotificationCenter.current()
    private let quiet = ForegroundQuiet()
    private var lastPlan: [PlannedNotice] = []
    private var queue: Task<Void, Never>?

    init() {
        center.delegate = quiet
    }

    func status() async -> NotifStatus {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .notDetermined: return .undetermined
        case .denied: return .denied
        @unknown default: return .denied
        }
    }

    /// 只問一次：已允許回 true；被拒回 false、不跳框；只有還沒問過才跳系統框。
    /// 只要橫幅與聲音，不要徽章（只申請用得到的）。
    func askOnce() async -> Bool {
        switch await status() {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            let granted = try? await center.requestAuthorization(options: [.alert, .sound])
            return granted ?? false
        }
    }

    /// 狀態與通知對齊。內容沒變就不重排：存草稿每個字都會走到這裡，不該每個字都取消再排。
    /// 連續兩次轉態時，後一次要等前一次「取消＋排」做完，不然會排出兩則。
    func sync(_ state: AppState, now: Millis, force: Bool = false) {
        let plan = Notify.planned(state, now: now)
        if !force, plan == lastPlan {
            return
        }
        lastPlan = plan
        let sound = state.settings.sound
        let previous = queue
        queue = Task {
            await previous?.value
            await arm(plan, sound: sound)
        }
    }

    private func arm(_ plan: [PlannedNotice], sound: Bool) async {
        center.removeAllPendingNotificationRequests()
        for notice in plan {
            let content = UNMutableNotificationContent()
            content.title = notice.title
            content.body = notice.body
            // 專注的人常開著系統的專注模式：不設這個，到點那一則會被收起來
            content.interruptionLevel = .timeSensitive
            if sound {
                content.sound = .default
            }
            let wait = max(1, (notice.fireAt - TimeText.nowMillis()) / Params.msPerSecond)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            // 沒權限時排不進去：核心不靠通知，那一行提示由畫面顯示
            try? await center.add(request)
        }
    }
}
