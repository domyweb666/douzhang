import ActivityKit
import SwiftUI
import WidgetKit

/// 計時中、響了還沒收、休息：鎖定畫面與動態島。沒有按鈕，點下去打開番茄帳（系統預設）。
struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivity.self) { context in
            LiveLockView(look: LiveCardLook(context.state, isStale: context.isStale))
                .activityBackgroundTint(Tokens.Colors.card.opacity(Tokens.Live.tint))
        } dynamicIsland: { context in
            Self.island(LiveCardLook(context.state, isStale: context.isStale))
        }
    }

    private static func island(_ look: LiveCardLook) -> DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                LiveRing(look: look, size: Tokens.Live.islandRing)
            }
            DynamicIslandExpandedRegion(.trailing) {
                LiveIslandText(
                    look: look,
                    timeFont: Tokens.Fonts.clockIsland,
                    titleFont: Tokens.Fonts.section
                )
                .padding(.top, Tokens.Live.islandTop)
            }
        } compactLeading: {
            LiveRing(look: look, size: Tokens.Live.compactRing)
        } compactTrailing: {
            LiveIslandText(
                look: look,
                timeFont: Tokens.Fonts.chip,
                titleFont: Tokens.Fonts.chip
            )
        } minimal: {
            LiveMinimal(look: look)
        }
    }
}
