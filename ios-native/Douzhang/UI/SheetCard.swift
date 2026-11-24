import SwiftUI

/// 半頁的內容：標題，下面是各張半頁自己的東西。沒有副標：半頁不放常駐的說明字。放在系統的 .sheet 裡，
/// 高度跟著內容走；內容太高或鍵盤開著放不下時可以往上拉成整頁、裡面可捲。
struct SheetCard<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    @State private var fitted: CGFloat = Tokens.Shape.sheetScrollMax

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .zero) {
                Text(title)
                    .font(Tokens.Fonts.section)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                content.padding(.top, Tokens.Space.card)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.Space.screen)
            .padding(.top, Tokens.Space.xl)
            .padding(.bottom, Tokens.Space.l)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                fitted = height
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(Tokens.Colors.card)
        .presentationDetents([.height(fitted), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Tokens.Shape.radiusSheet)
    }
}

/// 半頁裡的一列：左邊主字、右邊選中打勾。
struct SheetRow: View {
    var title: String
    var selected = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.m) {
                Text(title)
                    .font(Tokens.Fonts.body)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    Text(Words.check)
                        .font(Tokens.Fonts.bodyStrong)
                        .foregroundStyle(Tokens.Colors.accentText)
                }
            }
            .padding(.vertical, Tokens.Space.m)
            .frame(minHeight: Tokens.Shape.row)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Tokens.Colors.separator.frame(height: Tokens.Shape.hairline)
            }
        }
        .buttonStyle(FadeStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
