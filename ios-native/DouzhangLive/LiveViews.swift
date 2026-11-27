import AppIntents
import SwiftUI

/// 鎖定畫面那張卡（版面照 FocusPomo 的鎖定畫面：左上標籤、大字、下面一排、右下開始鈕；配色用自己的）。
/// shown 是這一刻該畫的那一態（LiveCard.shown），到點後由系統重畫時換掉。
struct LockCard: View {
    let card: LiveCard
    let shown: LiveStage

    var body: some View {
        VStack(alignment: .leading, spacing: LiveTokens.tight) {
            LiveTitle(card: card, shown: shown)
            HStack(alignment: .bottom, spacing: LiveTokens.gap) {
                VStack(alignment: .leading, spacing: LiveTokens.tight) {
                    LiveHeadline(card: card, shown: shown)
                    LiveTally(card: card, shown: shown)
                }
                Spacer(minLength: LiveTokens.gap)
                if card.startsFrom(shown) {
                    LiveStartButton(card: card)
                }
            }
        }
        .foregroundStyle(LiveTokens.text)
        .padding(LiveTokens.pad)
        .dynamicTypeSize(...LiveTokens.largestType)
    }
}

/// 番茄＋標籤名，後面接這一態那一行（休息中、休息完了）。
struct LiveTitle: View {
    let card: LiveCard
    let shown: LiveStage

    var body: some View {
        HStack(spacing: LiveTokens.tight) {
            LiveTomato(card: card, size: LiveTokens.tomatoSmall)
            Text(card.name)
            if !card.note(for: shown).isEmpty {
                Text(card.note(for: shown))
                    .foregroundStyle(.secondary)
            }
        }
        .font(LiveTokens.small)
        .lineLimit(1)
        .minimumScaleFactor(LiveTokens.smallestScale)
    }
}

/// 大字：倒數由系統自己走（不用每秒推）；不倒數的時候寫熟了、休息中、一顆多長。
struct LiveHeadline: View {
    let card: LiveCard
    let shown: LiveStage

    var body: some View {
        Group {
            if let range = card.timerRange(for: shown) {
                Text(timerInterval: range, countsDown: true)
            } else {
                Text(card.headline(for: shown))
            }
        }
        .font(LiveTokens.big)
        .lineLimit(1)
        .minimumScaleFactor(LiveTokens.smallestScale)
    }
}

/// 大字下面那一排：今天收了幾顆（0 不寫）、一顆多長（待機時大字已經是長度，不重寫）。
struct LiveTally: View {
    let card: LiveCard
    let shown: LiveStage

    var body: some View {
        HStack(spacing: LiveTokens.gap) {
            if card.kept > 0 {
                HStack(spacing: LiveTokens.tight) {
                    LiveTomato(card: card, size: LiveTokens.tomatoSmall)
                    Text(card.kept, format: .number)
                }
            }
            if shown != .idle {
                Text(card.lenText)
            }
        }
        .font(LiveTokens.row)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

/// 開始鈕：同一個標籤開始下一顆，在 app 的行程裡跑（StartNextIntent）。
struct LiveStartButton: View {
    let card: LiveCard

    var body: some View {
        Button(intent: StartNextIntent(typeId: card.typeId)) {
            Text(card.words.start)
                .font(LiveTokens.button)
                .foregroundStyle(LiveTokens.text)
                .padding(.horizontal, LiveTokens.pillWide)
                .padding(.vertical, LiveTokens.pillTall)
                .background(LiveTokens.pill, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 靈動島縮起來時右邊：倒數，或不倒數時那兩個字。系統的倒數字會撐滿能用的寬度，
/// 先放一串看不見、一樣寬的字佔位置，倒數疊在上面（照米說）。
struct LiveCompactTime: View {
    let card: LiveCard
    let shown: LiveStage

    var body: some View {
        if let range = card.timerRange(for: shown) {
            Text(card.timerTemplate)
                .hidden()
                .overlay(alignment: .trailing) {
                    Text(timerInterval: range, countsDown: true)
                        .multilineTextAlignment(.trailing)
                }
                .font(LiveTokens.small)
                .monospacedDigit()
                .lineLimit(1)
        } else {
            Text(card.headline(for: shown))
                .font(LiveTokens.small)
                .lineLimit(1)
        }
    }
}

/// 簡化的番茄：圓＋蒂。顏色是這個標籤的番茄色（app 從 Tokens.Tomato 抄進卡片）。
struct LiveTomato: View {
    let card: LiveCard
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(LiveTokens.color(card.tint))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(LiveTokens.color(card.leaf))
                    .frame(width: size * LiveTokens.stemWide, height: size * LiveTokens.stemTall)
                    .offset(y: -size * LiveTokens.stemLift)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
