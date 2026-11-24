import SwiftUI

/// 完整版的整頁（付費頁）：上面的聚焦預覽與四樣可捲，下面決定的那一塊固定。
/// 只從設定頁「完整版」那一列進來，付完或關掉都回到那裡；關閉鍵一打開就在。
/// 做到一半不出現：開著的時候下一顆自己開始了，就收起來（正在付款不收，會看不到結果）。
struct FullScreen: View {
    @Binding var note: FullNote?
    var onClose: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(Purchases.self) private var shop

    var body: some View {
        GeometryReader { proxy in
            let isShort = proxy.size.height < Tokens.Full.shortPage
            let width = max(0, proxy.size.width - Tokens.Layout.screenMargin * 2)
            VStack(spacing: .zero) {
                TextButton(label: Words.close, flush: true, action: onClose)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Tokens.Layout.screenMargin)
                ScrollView {
                    offered(isShort: isShort, width: width)
                }
                .scrollBounceBehavior(.basedOnSize)
                FullOfferBlock(note: $note, onClose: onClose)
                    // 沒有 Home 指示條的矮手機，安全區到底，自己留一點
                    .padding(.bottom, isShort ? Tokens.Layout.group : .zero)
            }
        }
        .background(Tokens.Colors.background.ignoresSafeArea())
        // 退款（變成沒買）也要再讀：買過的人一打開時沒有讀
        .onChange(of: shop.status, initial: true) { _, status in
            if status != .owned {
                Task { await shop.loadPrice() }
            }
        }
        .onChange(of: model.phase) { _, phase in
            if phase == .focus, !shop.isBusy {
                onClose()
            }
        }
    }

    private func offered(isShort: Bool, width: CGFloat) -> some View {
        let part = isShort ? Tokens.Full.previewShort : Tokens.Full.preview
        let gap = isShort ? Tokens.Layout.group : Tokens.Layout.section
        return VStack(alignment: .leading, spacing: .zero) {
            Text(Words.fullName)
                .font(Tokens.Fonts.title)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, isShort ? .zero : Tokens.Layout.item)
            FullPreview(width: width, height: width * part)
                .padding(.top, gap)
            VStack(alignment: .leading, spacing: Tokens.Layout.group) {
                item(Words.zenEnter, Words.fullZenNote)
                item(Words.cloudRow, Words.fullCloudNote)
                item(Words.shieldRow, Words.fullShieldNote)
                item(Words.fullLater, Words.fullLaterNote)
            }
            .padding(.top, gap)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Layout.screenMargin)
    }

    private func item(_ name: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Layout.tight) {
            Text(name)
                .font(Tokens.Fonts.body)
                .foregroundStyle(Tokens.Colors.textPrimary)
            Text(detail)
                .font(Tokens.Fonts.sub)
                .foregroundStyle(Tokens.Colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
