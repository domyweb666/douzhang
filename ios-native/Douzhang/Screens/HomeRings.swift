import SwiftUI

/// 番茄就是時鐘：一圈進度環圍著那顆番茄，走完一圈就熟。
/// 多大、什麼顏色由 Core/Grow.swift 算；這裡只畫。純裝飾，讀屏略過（剩多久在下面的時間）。
struct RingTomato: View {
    /// 環的直徑
    var size: CGFloat
    /// 環走了幾成（0–1）
    var progress: Double
    /// 走過那段的顏色
    var ringColor: Color
    /// 裡面那顆的顏色，以及它是全熟大小的幾成
    var fill: Color
    var scale: Double

    var body: some View {
        let done = min(1, max(0, progress))
        let line = StrokeStyle(lineWidth: Tokens.Shape.ringStroke, lineCap: .round)
        ZStack {
            Circle().stroke(Tokens.Colors.separator, lineWidth: Tokens.Shape.ringStroke)
            Circle()
                .trim(from: 0, to: done)
                .stroke(ringColor, style: line)
                .rotationEffect(.degrees(Tokens.Motion.ringStart))
                .animation(.linear(duration: Tokens.Motion.tick), value: done)
            TomatoView(fill: fill, size: size * Tokens.Shape.ringTomato * scale)
        }
        .padding(Tokens.Shape.ringStroke / 2)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 進度環加下面的時間與小字，放在中間那一塊的正中央。
/// 環最大 ringSize，不超過這一塊的寬，也不超過它高度的 ringRoom 成（下面要放時間）。
struct RingBlock<Below: View>: View {
    var progress: Double
    var ringColor: Color
    var fill: Color
    var scale: Double
    var time: String
    @ViewBuilder var below: Below

    var body: some View {
        GeometryReader { proxy in
            let room = proxy.size.height * Tokens.Shape.ringRoom
            let size = min(Tokens.Shape.ringSize, proxy.size.width, room)
            VStack(spacing: .zero) {
                RingTomato(
                    size: size,
                    progress: progress,
                    ringColor: ringColor,
                    fill: fill,
                    scale: scale
                )
                Text(time)
                    .font(Tokens.Fonts.clockRing)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .padding(.top, Tokens.Space.m)
                below
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }
}

/// 計時中：環是標籤的番茄色，裡面那顆從青長成標籤色；整塊點一下開記一筆。
struct FocusRing: View {
    var run: FocusRun
    var type: TagType
    var now: Millis
    var onNote: () -> Void

    var body: some View {
        let progress = Grow.progress(.focus(run), now: now)
        let ripe = Tokens.Tomato.body(type.color)
        let fill = Grow.ripeColor(progress, unripe: Tokens.Tomato.unripe, ripe: ripe)
        Button(action: onNote) {
            RingBlock(
                progress: progress,
                ringColor: ripe.color,
                fill: fill.color,
                scale: Grow.scale(progress),
                time: TimeText.mmss(run.endAt - now)
            ) {
                if run.done { HomeCaption(text: Words.doneEarlyLine) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Words.quickNote)
        .accessibilityHint(Words.tapNoteHint)
    }
}

/// 休息：環是藤的綠、倒數休息；裡面一顆還沒長的小青番茄。
/// 「我自己決定」的休息沒有終點，環不走、時間往上數。看資料不看設定：休息中改設定也不會卡住。
struct RestRing: View {
    var run: RestRun
    var now: Millis

    private var progress: Double {
        guard let endAt = run.endAt, endAt > run.restStart else { return 0 }
        return (now - run.restStart) / (endAt - run.restStart)
    }

    private var time: String {
        guard let endAt = run.endAt else { return TimeText.mmss(now - run.restStart) }
        return TimeText.mmss(endAt - now)
    }

    var body: some View {
        RingBlock(
            progress: progress,
            ringColor: Tokens.Tomato.vine.color,
            fill: Tokens.Tomato.unripe.color,
            scale: Params.growMinScale,
            time: time
        ) {
            HomeCaption(text: run.long ? Words.restLongRow : Words.rest)
            HomeCaption(text: Words.restBody)
            if !run.msg.isEmpty { HomeCaption(text: run.msg) }
        }
    }
}
