import ActivityKit
import Foundation
import os

/// 鎖定畫面與動態島那張卡（Live Activity）。該寫什麼由 LivePlan 算；這裡只管跟系統開、換、收。
/// 跟通知一樣：狀態改了就對齊一次，內容沒變就不吵系統；前後兩次排隊做，不然會開出兩張。
/// 開：開始一顆的時候（系統只准 app 在前景時開）。換：每次轉態、收下、改標籤。
/// 收：從計時中直接回待機（作廢、停下來、清空），或待機太久。其他交給系統（一張最長 8 小時）。
/// 任何失敗都只是鎖定畫面少一張卡，計時照常。
@MainActor
final class LiveIsland {
    private static let log = Logger(subsystem: "org.domyweb.douzhang", category: "live")

    private var lastCard: LiveCard?
    private var queue: Task<Void, Never>?

    /// force：開機、回到前景時不管內容變了沒都對一次（接回殺掉前那張、收掉待機太久的）。
    func sync(_ state: AppState, now: Millis, force: Bool = false) {
        let card = LivePlan.card(state, now: now)
        if !force, card == lastCard {
            return
        }
        lastCard = card
        let previous = queue
        queue = Task {
            await previous?.value
            await Self.apply(card)
        }
    }

    /// 等排著的都做完。卡片上按開始時，要等卡片換好才回給系統。
    func flush() async {
        await queue?.value
    }

    private static func apply(_ card: LiveCard) async {
        // 殺掉再開時接回原本那張；系統已經收掉的（滿 8 小時、被滑掉）不算，可以再開
        let onScreen = Activity<FocusActivity>.activities.filter(isOnScreen)
        for extra in onScreen.dropFirst() {
            await extra.end(nil, dismissalPolicy: .immediate)
        }
        guard let activity = onScreen.first else {
            request(card)
            return
        }
        let shown = activity.content.state
        let now = Date()
        if LivePlan.shouldEnd(shown: shown, next: card, now: now) {
            await activity.end(nil, dismissalPolicy: .immediate)
            return
        }
        var next = card
        if next.stage == .idle {
            next.idleSince = shown.stage == .idle ? shown.idleSince ?? now : now
        }
        await activity.update(ActivityContent(state: next, staleDate: LivePlan.staleDate(next)))
    }

    /// 只在開始一顆時開新的：待機、休息中沒有卡片就不冒出來。
    private static func request(_ card: LiveCard) {
        guard card.stage == .focus, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: card, staleDate: LivePlan.staleDate(card))
        do {
            _ = try Activity.request(attributes: FocusActivity(), content: content, pushType: nil)
        } catch {
            log.error("live activity not started: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func isOnScreen(_ activity: Activity<FocusActivity>) -> Bool {
        activity.activityState == .active || activity.activityState == .stale
    }
}
