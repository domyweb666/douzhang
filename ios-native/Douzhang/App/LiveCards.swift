import ActivityKit
import Foundation

/// 跟系統的即時動態打交道。該不該有、上面是什麼由 LiveCard.face 算，要不要去動系統由 LiveCardGate 算。
/// 核心迴圈不靠它：使用者關掉、系統不給、背景不准開，都照樣計時，回到前景再試一次。
@MainActor
final class LiveCards {
    private(set) var gate = LiveCardGate()
    /// 手上那張。開不成、系統不准時是 nil，回前景才會再開
    private var held: Activity<TimerActivity>?
    /// 自己收掉的：系統晚一點才把它標成結束，那之前不能再當成還活著的接手
    private var endedIds: Set<String> = []
    private var queue: Task<Void, Never>?

    /// 狀態與那一張對齊。連續兩次轉態時，後一次要等前一次做完，不然會開出兩張。
    func sync(_ state: AppState, now: Millis, isBack: Bool = false) {
        let face = LiveCard.face(state, now: now)
        // 單元測試寄生在 app 裡，不能真的在那台手機上開
        guard let cue = gate.cue(face, isBack: isBack), !LaunchOptions.isTesting else { return }
        let previous = queue
        queue = Task {
            await previous?.value
            await arm(face, cue: cue)
        }
    }

    /// 接手系統裡既有的那張（app 被殺掉再開也還在），多的收掉。
    private func arm(_ face: LiveCardFace?, cue: LiveCardCue) async {
        let cards = Activity<TimerActivity>.activities
        let mine = held ?? cards.first {
            LiveCard.isUp($0.activityState) && !endedIds.contains($0.id)
        }
        // 收之前先看：系統結束的那張收掉之後，就分不出是系統還是使用者
        let last = mine?.activityState
        let kept = face != nil && LiveCard.isUp(last) ? mine : nil
        for card in cards where card.id != kept?.id {
            endedIds.insert(card.id)
            await card.end(nil, dismissalPolicy: .immediate)
        }
        guard let face, ActivityAuthorizationInfo().areActivitiesEnabled else {
            held = nil
            return
        }
        let content = ActivityContent(state: face, staleDate: face.staleDate)
        if let kept {
            if cue == .changed || held == nil {
                await kept.update(content)
            }
            held = kept
        } else if LiveCard.opens(cue, after: last) {
            held = try? Activity.request(attributes: TimerActivity(), content: content)
        }
    }
}
