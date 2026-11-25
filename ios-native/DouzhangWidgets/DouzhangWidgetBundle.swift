import SwiftUI
import WidgetKit

/// 即時動態與控制中心的開始鈕；不放主畫面小工具：小工具清單裡不會冒出沒有用的項目。
@main
struct DouzhangWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerLiveActivity()
        if #available(iOS 18.0, *) {
            StartControl()
        }
    }
}
