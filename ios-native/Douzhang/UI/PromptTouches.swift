import SwiftUI
import UIKit

/// 放在捲動區的內容後面：手指一碰就把觸控交給裡面的按鈕，不先等 0.15 秒看是不是要捲。
/// 等的話點得快時，按下跟放開在手指離開之後才一起到，按鈕看起來沒反應（2026-11-25 模擬器量過）。
/// SwiftUI 沒有這個開關，只能往上找到捲動區自己關。一滑起來系統照樣取消按鈕的觸控。
struct PromptTouches: UIViewRepresentable {
    func makeUIView(context _: Context) -> UIView {
        Finder()
    }

    func updateUIView(_: UIView, context _: Context) {}

    private final class Finder: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            var parent = superview
            while let view = parent {
                if let scroll = view as? UIScrollView {
                    scroll.delaysContentTouches = false
                    return
                }
                parent = view.superview
            }
        }
    }
}
