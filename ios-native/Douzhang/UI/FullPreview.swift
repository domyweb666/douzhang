import SwiftUI

/// 付費頁的聚焦模式預覽：真的時鐘排版、真的番茄，資料寫死成範例。
/// 一張不會動的圖：不跑計時、不看感測器、不轉方向，所以番茄用 TomatoView 照範例的進度縮。
struct FullPreview: View {
    var width: CGFloat
    var height: CGFloat

    private var progress: Double {
        1 - Params.FullSample.leftMs / Params.FullSample.totalMs
    }

    private var ripeness: Color {
        let ripe = Tokens.Tomato.body(.red)
        return Grow.ripeColor(progress, unripe: Tokens.Tomato.unripe, ripe: ripe).color
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Shape.radiusCard)
        VStack(spacing: Tokens.Layout.item) {
            ZenClock(
                parts: TimeText.clockParts(Params.FullSample.leftMs),
                screen: width,
                width: width,
                gap: Tokens.Layout.item
            ) { size in
                TomatoView(fill: ripeness, size: size)
                    .scaleEffect(CGFloat(Grow.scale(progress)))
            }
            caption(Words.fullSampleDoing)
        }
        .frame(width: width, height: height)
        .background(Tokens.Zen.background, in: shape)
        // 深色外觀的畫布也接近黑，靠這條線看得出是一塊
        .overlay {
            shape.strokeBorder(Tokens.Colors.separator, lineWidth: Tokens.Shape.hairline)
        }
        .overlay(alignment: .topTrailing) {
            caption(Words.fullSample)
                .padding(.horizontal, Tokens.Layout.cardPad)
                .padding(.vertical, Tokens.Layout.rowPadV)
        }
        // 這是一張圖，數字不跟系統字級放大，圖裡的小字也不放到撐破
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Words.fullSampleA11y(TimeText.mmss(Params.FullSample.leftMs)))
        .accessibilityAddTraits(.isImage)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Fonts.caption)
            .foregroundStyle(Tokens.Zen.dim)
            .lineLimit(1)
    }
}
