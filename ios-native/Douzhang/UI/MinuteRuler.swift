import SwiftUI

/// 刻度尺上的一分鐘：每 5 分長線加數字，其他短線；選中的那格用產品色、比較高也比較粗。
struct MinuteTick: View {
    var minute: Int
    var isOn: Bool

    private var isMajor: Bool {
        minute.isMultiple(of: Params.rulerMajorEvery)
    }

    private var height: CGFloat {
        if isOn {
            return Tokens.Dial.tickOn
        }
        return isMajor ? Tokens.Dial.tickLong : Tokens.Dial.tickShort
    }

    private var ink: Color {
        if isOn {
            return Tokens.Colors.accent
        }
        return isMajor ? Tokens.Colors.textSecondary : Tokens.Colors.textTertiary
    }

    var body: some View {
        VStack(spacing: Tokens.Layout.item) {
            // 數字比一格寬：疊在上面，不撐開格子。選中的那個數字就是尺上面的大字，這裡不重複
            Color.clear
                .frame(height: Tokens.Dial.label)
                .overlay(alignment: .bottom) {
                    if isMajor {
                        Text(String(minute))
                            .font(Tokens.Fonts.caption)
                            .foregroundStyle(Tokens.Colors.textSecondary)
                            .fixedSize()
                            .opacity(isOn ? 0 : 1)
                    }
                }
            Capsule()
                .fill(ink)
                .frame(
                    width: isOn ? Tokens.Dial.tickWidthOn : Tokens.Dial.tickWidth,
                    height: height
                )
                .frame(height: Tokens.Dial.tickOn, alignment: .bottom)
        }
        .frame(width: Tokens.Dial.slot)
    }
}

/// 橫向的刻度尺：左右滑，停在哪一格就是幾分鐘；每換一格輕觸一下。讀屏用上下滑一分鐘一分鐘調。
struct MinuteRuler: View {
    @Binding var minutes: Int

    /// 第一次排版完才把位置交給捲動區：還沒排好就給，會停在最左邊（跟 RootView 指定頁同一個做法）
    @State private var ready = false
    /// 打開時停在哪一格，用整條尺的幾成表示：第一次畫就在那一格，不會從 1 分跳過去
    @State private var start: UnitPoint

    private let marks = Params.typeLengths.map { Int($0) }

    init(minutes: Binding<Int>) {
        _minutes = minutes
        let marks = Params.typeLengths.map { Int($0) }
        let index = marks.firstIndex(of: minutes.wrappedValue) ?? 0
        let share = Double(index) / Double(max(1, marks.count - 1))
        _start = State(initialValue: UnitPoint(x: share, y: UnitPoint.center.y))
    }

    private var position: Binding<Int?> {
        Binding(
            get: { ready ? minutes : nil },
            set: { next in
                if ready, let next {
                    minutes = next
                }
            }
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: .zero) {
                    ForEach(marks, id: \.self) { mark in
                        MinuteTick(minute: mark, isOn: mark == minutes)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            // 不限一次滑幾格：甩一下就能從 5 分滑到 60 分
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .scrollPosition(id: position, anchor: .center)
            .defaultScrollAnchor(start)
            // 兩側留半個畫面寬：第一格與最後一格也停得到正中央
            .safeAreaPadding(.horizontal, max(0, (proxy.size.width - Tokens.Dial.slot) / 2))
            .task {
                try? await Task.sleep(for: .milliseconds(Params.tickMs))
                ready = true
            }
        }
        .frame(height: Tokens.Dial.height)
        .haptic(.selection, trigger: minutes)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Words.lengthA11y)
        .accessibilityValue(Words.minutes(minutes))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(1)
            case .decrement: move(-1)
            @unknown default: break
            }
        }
    }

    private func move(_ step: Int) {
        if marks.contains(minutes + step) {
            minutes += step
        }
    }
}
