import SwiftUI
import UIKit

/// 手感的共用件：資料變化的動畫、數字換值的過渡。曲線都從 Tokens.Motion 拿。
enum Feel {
    /// 資料變了（切換選項、加刪標籤、展開收合、換檢視）：帶著動畫換，看得出東西去哪了。
    /// 開了「減少動態」就直接換，不滑。
    @MainActor
    static func change(_ body: () -> Void) {
        if UIAccessibility.isReduceMotionEnabled {
            body()
        } else {
            withAnimation(Tokens.Motion.change, body)
        }
    }
}

/// 數字換值：一位一位滾過去，不直接跳。倒數的往下滾；減少動態時只淡入淡出。
/// value 是用來判斷「換了沒」的那個值（通常就是畫出來的那串字）。
struct NumberChange<Value: Equatable>: ViewModifier {
    var value: Value
    var countsDown = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .opacity : .numericText(countsDown: countsDown))
            .animation(Tokens.Motion.change, value: value)
    }
}
