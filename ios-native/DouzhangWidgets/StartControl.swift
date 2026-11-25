import AppIntents
import SwiftUI
import WidgetKit

/// 控制中心與鎖定畫面的開始鈕（AI28b）。跟捷徑、Siri 同一個動作，字也用同一份。
@available(iOS 18.0, *)
struct StartControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "org.domyweb.douzhang.start") {
            ControlWidgetButton(action: StartTomatoIntent()) {
                Label(StartTomatoIntent.title, systemImage: "timer")
            }
        }
        .displayName(StartTomatoIntent.title)
        .description(StartTomatoIntent.description.descriptionText)
    }
}
