import SwiftUI
import VeggieKit

extension View {
    /// 畫面上的震動都走這裡：設定頁「觸覺回饋」關著就不震。
    /// 每次要震的那一刻才看開關，改了立刻生效。condition 用換成的新值判斷這次要不要震。
    func haptic<Value: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: Value,
        condition: @escaping (Value) -> Bool = { _ in true }
    ) -> some View {
        sensoryFeedback(feedback, trigger: trigger) { _, next in
            VeggieHaptics.isEnabled && condition(next)
        }
    }
}
