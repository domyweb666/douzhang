import SwiftUI

/// 一張牌。數字換了：牌往後倒、換上新數字、再立回來。減少動態時不翻，直接是新數字。
/// shown 是牌面上現在畫的數字，翻到一半才換成新的。
struct FlipCard: View {
    var digit: String
    var width: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = ""
    @State private var fold = 0.0

    var body: some View {
        let layout = Tokens.ZenLayout.self
        let height = width * layout.cardHeight / layout.cardWidth
        let radius = width * layout.cardRadius / layout.cardWidth
        Text(reduceMotion ? digit : shown)
            .font(Tokens.Fonts.zenDigit(width * layout.digitSize / layout.cardWidth))
            .foregroundStyle(Tokens.Zen.digit)
            .frame(width: width, height: height)
            .background(Tokens.Zen.card, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                // 每張牌中間那道橫縫
                Tokens.Zen.background.frame(height: Tokens.Shape.zenSeam)
            }
            .rotation3DEffect(.degrees(fold * Tokens.Motion.zenFlipFold), axis: (x: 1, y: 0, z: 0))
            .onAppear { shown = digit }
            .onChange(of: digit) { _, next in flip(to: next) }
    }

    private func flip(to next: String) {
        if reduceMotion {
            shown = next
            return
        }
        let half = Tokens.Motion.zenFlip
        withAnimation(half) {
            fold = 1
        } completion: {
            shown = next
            withAnimation(half) { fold = 0 }
        }
    }
}

/// 聚焦模式：計時中橫放的整頁時鐘。黑底、四張深灰牌倒數，左邊一顆在變色的番茄，
/// 下面一行這顆的標籤。淺色深色都是這一組。
/// 平常只有時鐘；點一下畫面，底下出現「記一筆」「結束這顆」「回主畫面」，過幾秒自己收起來。
/// 記一筆與結束都要打字或選，橫向時鍵盤會蓋掉大半個畫面，所以按了先回直向的主畫面再開那張半頁。
struct FocusScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    var run: FocusRun
    var type: TagType

    @State private var controls = false
    @State private var hiding: Task<Void, Never>?

    var body: some View {
        let left = run.endAt - model.now
        GeometryReader { proxy in
            let width = proxy.size.width
            let layout = Tokens.ZenLayout.self
            VStack(spacing: width * layout.lineGap) {
                HStack(spacing: width * layout.tomatoGap) {
                    tomato(box: width * layout.tomato)
                    clock(TimeText.clockDigits(left), width: width * layout.clockScale)
                }
                doingLine.frame(maxWidth: width * (1 - layout.cardWidth))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: reveal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Words.zenScreenA11y(TimeText.mmss(left)))
            .accessibilityAddTraits(.isButton)
        }
        .overlay(alignment: .bottom) { pills }
        .background(Tokens.Zen.background.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onDisappear { hiding?.cancel() }
    }

    /// 翻牌左邊那顆番茄：大小固定，只從青變成標籤色。
    private func tomato(box: CGFloat) -> some View {
        let progress = Grow.progress(.focus(run), now: model.now)
        let ripe = Tokens.Tomato.body(type.color)
        let fill = Grow.ripeColor(progress, unripe: Tokens.Tomato.unripe, ripe: ripe)
        return TomatoView(fill: fill.color, size: box)
    }

    /// 四張牌：分分：秒秒。
    private func clock(_ digits: [String], width: CGFloat) -> some View {
        let layout = Tokens.ZenLayout.self
        let card = width * layout.cardWidth
        let dot = width * layout.colonDot
        return HStack(spacing: width * layout.gap) {
            FlipCard(digit: digits[0], width: card)
            FlipCard(digit: digits[1], width: card)
            VStack(spacing: width * layout.colonGap) {
                Circle().fill(Tokens.Zen.dim).frame(width: dot, height: dot)
                Circle().fill(Tokens.Zen.dim).frame(width: dot, height: dot)
            }
            .padding(.horizontal, dot / 2)
            FlipCard(digit: digits[2], width: card)
            FlipCard(digit: digits[3], width: card)
        }
    }

    /// 時鐘下面那一行：這個標籤的小番茄＋標籤與長度。太長就截掉，不換行。
    private var doingLine: some View {
        HStack(spacing: Tokens.Space.s) {
            TomatoView(color: type.color, size: Tokens.Shape.blockIcon * 1.5)
            Text(Words.tagLabel(type))
                .font(Tokens.Fonts.body)
                .foregroundStyle(Tokens.Zen.dim)
                .lineLimit(1)
        }
    }

    /// 底下三顆鈕：平常看不到、點不到（讀屏也讀不到）；點一下畫面才淡入。
    private var pills: some View {
        HStack(spacing: Tokens.Space.m) {
            pill(Words.quickNote) { model.leaveZen(opening: .note) }
            pill(Words.endThis) {
                let early = Machine.stoppedEarly(run, now: TimeText.nowMillis())
                model.leaveZen(opening: .end(early: early))
            }
            pill(Words.zenLeave) { model.leaveZen() }
        }
        .padding(.bottom, Tokens.Space.m)
        .opacity(controls ? 1 : 0)
        .allowsHitTesting(controls)
        .accessibilityHidden(!controls)
        .animation(Tokens.Motion.transition, value: controls)
    }

    private func pill(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Tokens.Fonts.chip)
                .foregroundStyle(Tokens.Zen.digit)
                .frame(minHeight: Tokens.Shape.tapMin)
                .padding(.horizontal, Tokens.Space.l)
                .background(Tokens.Zen.pill, in: Capsule())
        }
        .buttonStyle(FadeStyle())
    }

    /// 點一下畫面顯示按鈕，過幾秒自己收起來。開著讀屏時不自動收：幾秒不夠滑到按鈕上。
    private func reveal() {
        controls = true
        hiding?.cancel()
        if voiceOver {
            return
        }
        hiding = Task {
            try? await Task.sleep(for: .seconds(Tokens.ZenLayout.controlsSeconds))
            if !Task.isCancelled {
                controls = false
            }
        }
    }
}
