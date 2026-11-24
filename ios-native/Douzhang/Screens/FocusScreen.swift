import SwiftUI

/// 聚焦模式：計時中橫放的整頁時鐘。黑底、分與秒兩個大數字，中間那顆在變色的番茄就是冒號，
/// 下面一行在做什麼（沒填就是標籤名）。淺色深色都是這一組。
/// 平常只有時鐘；點一下畫面，那一行收起來換成一排按鈕，過幾秒自己換回來。
/// 背景音、記一筆與結束都要打字或選，橫向時放不下也會被鍵盤蓋掉，所以按了先回直向的主畫面再開那張半頁。
struct FocusScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    var run: FocusRun
    var type: TagType

    @State private var controls = false
    @State private var hiding: Task<Void, Never>?

    var body: some View {
        let left = run.endAt - model.now
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                VStack(spacing: Tokens.Layout.group) {
                    clock(TimeText.clockParts(left), in: proxy)
                    doingLine
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: reveal)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Words.zenScreenA11y(TimeText.mmss(left)))
                .accessibilityAddTraits(.isButton)
            }
            // 上下照整個螢幕置中；左右留在安全區裡
            .ignoresSafeArea(edges: .vertical)
            pills
        }
        .background(Tokens.Zen.background.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onDisappear { hiding?.cancel() }
    }

    /// 分、番茄、秒。兩個數字各佔番茄旁邊一樣寬的一塊、靠著番茄排，換秒時番茄不會左右動。
    /// 字級照整個畫面的寬；左右安全區放不下（或分鐘有三位）就縮到剛好。
    private func clock(
        _ parts: (minutes: String, seconds: String),
        in proxy: GeometryProxy
    ) -> some View {
        let insets = proxy.safeAreaInsets
        let screen = proxy.size.width + insets.leading + insets.trailing
        let tomato = min(Tokens.ZenLayout.tomatoMax, screen * Tokens.ZenLayout.tomato)
        let room = max(0, (proxy.size.width - tomato) / 2 - Tokens.Layout.section)
        let digits = CGFloat(max(parts.minutes.count, parts.seconds.count))
        let size = min(
            screen * Tokens.ZenLayout.digit,
            room / (digits * Tokens.Fonts.zenDigitWidth)
        )
        return HStack(spacing: Tokens.Layout.section) {
            number(parts.minutes, size: size)
                .frame(width: room, alignment: .trailing)
            TomatoView(fill: ripeness, size: tomato)
            number(parts.seconds, size: size)
                .frame(width: room, alignment: .leading)
        }
    }

    private func number(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(Tokens.Fonts.zenDigit(size))
            .foregroundStyle(Tokens.Zen.digit)
            .modifier(NumberChange(value: text, countsDown: true))
            .fixedSize()
            .frame(height: size * Tokens.ZenLayout.digitRow)
    }

    /// 番茄大小固定，只從青變成標籤色。
    private var ripeness: Color {
        let progress = Grow.progress(.focus(run), now: model.now)
        let ripe = Tokens.Tomato.body(type.color)
        return Grow.ripeColor(progress, unripe: Tokens.Tomato.unripe, ripe: ripe).color
    }

    /// 太長就截掉，不換行。按鈕出來時收起來，位子留著，數字才不會動。
    private var doingLine: some View {
        Text(run.doing.isEmpty ? type.name : run.doing)
            .font(Tokens.Fonts.body)
            .foregroundStyle(Tokens.Zen.dim)
            .lineLimit(1)
            .padding(.horizontal, Tokens.Layout.screenMargin)
            .opacity(controls ? 0 : 1)
            .animation(Tokens.Motion.transition, value: controls)
    }

    /// 底下那排鈕：平常看不到、點不到（讀屏也讀不到）；點一下畫面才淡入。
    /// 「結束」在右邊隔開；字放大到一排放不下時改成左右捲。
    private var pills: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Layout.group) {
                // 左邊補一塊跟「結束」一樣寬的空，中間三顆才在畫面正中
                endPill.hidden()
                Spacer(minLength: .zero)
                mainPills
                Spacer(minLength: .zero)
                endPill
            }
            ScrollView(.horizontal) {
                HStack(spacing: Tokens.Layout.group) {
                    mainPills
                    endPill
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, Tokens.Layout.screenMargin)
        .padding(.bottom, Tokens.Layout.group)
        .opacity(controls ? 1 : 0)
        .allowsHitTesting(controls)
        .accessibilityHidden(!controls)
        .animation(Tokens.Motion.transition, value: controls)
    }

    @ViewBuilder private var mainPills: some View {
        let kind = model.state.settings.ambience
        pill(Words.ambienceChip(kind)) { model.leaveZen(opening: .sound) }
            .accessibilityLabel(Words.ambienceTitle)
            .accessibilityValue(Words.ambienceKind(kind))
        pill(Words.quickNote) { model.leaveZen(opening: .note) }
        pill(Words.zenLeave) { model.leaveZen() }
    }

    private var endPill: some View {
        pill(Words.endShort, fill: Tokens.Zen.pillDim) {
            let early = Machine.stoppedEarly(run, now: TimeText.nowMillis())
            model.leaveZen(opening: .end(early: early))
        }
        .accessibilityLabel(Words.endThis)
    }

    private func pill(
        _ label: String,
        fill: Color = Tokens.Zen.pill,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(Tokens.Fonts.chip)
                .foregroundStyle(Tokens.Zen.digit)
                .lineLimit(1)
                .frame(minHeight: Tokens.Shape.tapMin)
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .background(fill, in: Capsule())
                .contentShape(Capsule())
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
