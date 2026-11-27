import ActivityKit
import SwiftUI
import WidgetKit

/// 番茄帳的擴充只有一樣：鎖定畫面與動態島那張卡。
@main
struct LiveBundle: WidgetBundle {
    var body: some Widget {
        FocusLive()
    }
}

/// 從開始一顆一路活到休息完的那張卡。四態（計時中、熟了、休息中、休息完）由 app 算好放進 LiveCard；
/// app 不在前景時，到點那一刻靠 staleDate 讓系統重畫，LiveCard.shown 自己換成下一態。
/// 點卡片本身打開番茄帳（系統預設），開始鈕在休息完才出現。
struct FocusLive: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivity.self) { context in
            LockCard(card: context.state, shown: Self.shown(context))
                .activityBackgroundTint(LiveTokens.paper)
                .activitySystemActionForegroundColor(LiveTokens.text)
        } dynamicIsland: { context in
            Self.island(context.state, shown: Self.shown(context))
        }
    }

    private static func shown(_ context: ActivityViewContext<FocusActivity>) -> LiveStage {
        context.state.shown(at: .now, isStale: context.isStale)
    }

    /// 靈動島的底永遠是黑的：字用系統的（白），只有番茄上色。
    private static func island(_ card: LiveCard, shown: LiveStage) -> DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                LiveTitle(card: card, shown: shown)
            }
            DynamicIslandExpandedRegion(.trailing) {
                LiveTally(card: card, shown: shown)
            }
            DynamicIslandExpandedRegion(.bottom) {
                HStack(spacing: LiveTokens.gap) {
                    LiveHeadline(card: card, shown: shown)
                    Spacer(minLength: LiveTokens.gap)
                    if card.startsFrom(shown) {
                        LiveStartButton(card: card)
                    }
                }
            }
        } compactLeading: {
            LiveTomato(card: card, size: LiveTokens.tomatoCompact)
        } compactTrailing: {
            LiveCompactTime(card: card, shown: shown)
        } minimal: {
            LiveTomato(card: card, size: LiveTokens.tomatoCompact)
        }
    }
}
