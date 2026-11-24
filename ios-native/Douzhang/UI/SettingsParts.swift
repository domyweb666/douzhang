import SwiftUI
import UIKit
import VeggieKit

/// 設定頁的一區：標題、白卡（裡面是一列列）。footer 只給出錯與結果用，不放常駐說明。
struct SettingsSection<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Layout.item) {
            if let title {
                Text(title)
                    .font(Tokens.Fonts.title3)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: .zero) { content }
                .padding(.horizontal, Tokens.Layout.cardPad)
                .background(
                    Tokens.Colors.card,
                    in: RoundedRectangle(cornerRadius: Tokens.Shape.radiusCard)
                )
            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(Tokens.Fonts.caption)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                    .padding(.horizontal, Tokens.Layout.cardPad)
            }
        }
    }
}

/// 列與列之間的分隔線。
struct SettingsDivider: View {
    var body: some View {
        Tokens.Colors.separator.frame(height: Tokens.Shape.hairline)
    }
}

/// 設定頁的一列（樣子是全家共用的 VeggieRow）：圖示、名字、右邊的值；可點的列尾有箭頭。
/// danger＝紅字（只有清除所有資料）。
struct SettingsRow: View {
    var icon: String
    var label: String
    var value: String?
    var accessory = VeggieRow.Accessory.push
    var danger = false
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { row(accessory) }.buttonStyle(FadeStyle())
        } else {
            row(.none)
        }
    }

    private func row(_ tail: VeggieRow.Accessory) -> some View {
        VeggieRow(icon: icon, title: label, value: value, accessory: tail, destructive: danger)
    }
}

/// 設定頁的一列開關。
struct SettingsToggle: View {
    var icon: String
    var label: String
    var isOn: Bool
    var onChange: (Bool) -> Void

    var body: some View {
        VeggieToggleRow(icon: icon, title: label, isOn: Binding(get: { isOn }, set: onChange))
    }
}

/// 系統的分享選單（匯出備份用）。關掉時回報，呼叫端刪暫存檔。
struct ShareSheet: UIViewControllerRepresentable {
    var url: URL
    var onDone: () -> Void

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onDone() }
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
