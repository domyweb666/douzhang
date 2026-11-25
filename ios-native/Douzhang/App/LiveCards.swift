import ActivityKit
import Foundation

/// 跟系統的即時動態打交道。該不該有、上面是什麼由 LiveCard.face 算。
/// 核心迴圈不靠它：使用者關掉、系統不給、背景不准開，都照樣計時，下次對齊再試。
@MainActor
final class LiveCards {
    private var lastFace: LiveCardFace?
    /// 系統那邊已經跟 lastFace 一樣。剛開機不知道留著什麼，一定對齊一次
    private var isAligned = false
    private var queue: Task<Void, Never>?

    /// 狀態與那一張對齊。內容沒變就不重送：存草稿每個字都會走到這裡。
    /// 連續兩次轉態時，後一次要等前一次做完，不然會開出兩張。
    func sync(_ state: AppState, now: Millis) {
        // 單元測試寄生在 app 裡，不能真的在那台手機上開
        guard !LaunchOptions.isTesting else { return }
        let face = LiveCard.face(state, now: now)
        if isAligned, face == lastFace {
            return
        }
        isAligned = true
        lastFace = face
        let previous = queue
        queue = Task {
            await previous?.value
            await arm(face)
        }
    }

    /// 接手系統裡既有的那張（app 被殺掉再開也還在），多的收掉。
    private func arm(_ face: LiveCardFace?) async {
        let cards = Activity<TimerActivity>.activities
        let kept = face == nil ? nil : cards.first {
            $0.activityState == .active || $0.activityState == .stale
        }
        for card in cards where card.id != kept?.id {
            await card.end(nil, dismissalPolicy: .immediate)
        }
        guard let face else { return }
        let content = ActivityContent(state: face, staleDate: face.staleDate)
        if let kept {
            await kept.update(content)
            return
        }
        do {
            _ = try Activity.request(attributes: TimerActivity(), content: content)
        } catch {
            isAligned = false
        }
    }
}
