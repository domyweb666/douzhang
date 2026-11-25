import SwiftUI
import WidgetKit

/// 環包番茄。環照結束時刻自己走，粗細與底圈由系統定；滿的、空的也用同一個元件，看起來才是同一個環。
/// 讀屏在這裡念哪一態，剩多久由旁邊的時間自己念。
struct LiveRing: View {
    var look: LiveCardLook
    /// 環的直徑
    var size: CGFloat

    var body: some View {
        ZStack {
            progress
                .progressViewStyle(.circular)
                .tint(look.ringColor.color)
            TomatoView(fill: look.fill.color, size: tomato)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(look.spoken)
    }

    private var tomato: CGFloat {
        let full = size * Tokens.Shape.ringTomato
        return look.isSmall ? full * CGFloat(Params.restTomatoScale) : full
    }

    @ViewBuilder private var progress: some View {
        switch look.ring {
        case let .running(span):
            ProgressView(timerInterval: span, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        case .full:
            ProgressView(value: 1)
        case .empty:
            ProgressView(value: 0)
        }
    }
}

/// 系統自己倒數的時間。先放一串看不見、一樣寬的字占位置，計時疊在上面，才不會把動態島撐開。
struct LiveTimer: View {
    var look: LiveCardLook

    var body: some View {
        if let timer = look.timer {
            Text(look.timerTemplate)
                .hidden()
                .overlay(alignment: .trailing) {
                    // 90 分鐘寫 90:00，跟 app 裡一樣不寫小時
                    Text(timerInterval: timer, countsDown: true, showsHours: false)
                        .multilineTextAlignment(.trailing)
                }
                .monospacedDigit()
        }
    }
}

/// 鎖定畫面那一張：環包番茄在左、時間在右；沒有時間可看時換成字。
struct LiveLockView: View {
    var look: LiveCardLook

    var body: some View {
        HStack(spacing: Tokens.Live.pad) {
            LiveRing(look: look, size: Tokens.Live.ring)
            words
                .accessibilityHidden(true)
            Spacer(minLength: .zero)
            LiveTimer(look: look)
                .font(Tokens.Fonts.clockLock)
                .foregroundStyle(Tokens.Colors.textPrimary)
        }
        .lineLimit(1)
        .minimumScaleFactor(Tokens.Live.shrink)
        .padding(Tokens.Live.pad)
        // 一張最高 160，再大會被切掉
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .combine)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            if let caption = look.caption {
                Text(caption)
                    .font(Tokens.Fonts.bodyStrong)
                    .foregroundStyle(Tokens.Colors.textPrimary)
            }
            if let title = look.title {
                Text(title)
                    .font(Tokens.Fonts.section)
                    .foregroundStyle(Tokens.Colors.textPrimary)
            }
            if let note = look.note {
                Text(note)
                    .font(Tokens.Fonts.sub)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
        }
    }
}

/// 動態島右邊：時間，沒有時間可看時是那句大字。
/// 動態島的底永遠是黑的，字用聚焦模式那組（淺深色同值）。
struct LiveIslandText: View {
    var look: LiveCardLook
    var timeFont: Font
    var titleFont: Font

    var body: some View {
        Group {
            if let title = look.title {
                Text(title)
                    .font(titleFont)
                    .accessibilityHidden(true)
            } else {
                LiveTimer(look: look)
                    .font(timeFont)
            }
        }
        .foregroundStyle(Tokens.Zen.digit)
        .lineLimit(1)
        .minimumScaleFactor(Tokens.Live.shrink)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

/// 兩個 app 同時在島上時的小圓：沒地方放時間，讀屏還是要念得出來。
struct LiveMinimal: View {
    var look: LiveCardLook

    var body: some View {
        let ring = LiveRing(look: look, size: Tokens.Live.compactRing)
        if let timer = look.timer {
            ring.accessibilityValue(
                Text(timerInterval: timer, countsDown: true, showsHours: false)
            )
        } else {
            ring
        }
    }
}
