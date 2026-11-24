import SwiftUI
import VeggieKit

/// 設定頁的「購買」那一區：完整版（沒買點進付費頁，買了寫「已購買」不能點）、恢復購買（都在）。
/// 這裡不讀價格、不連線。還不知道買了沒照沒買的畫；知道了只換這一列右邊，列不增不減。
struct SettingsPurchase: View {
    @Environment(Purchases.self) private var shop
    @State private var isOpen = false
    /// 付費頁蓋著，含收起來的那段動畫
    @State private var isCovered = false
    @State private var note: FullNote?

    var body: some View {
        let line = note?.settingsLine(shop.status)
        VStack(alignment: .leading, spacing: Tokens.Layout.item) {
            rows
            if let line, !isCovered {
                FullLine(text: line, isProblem: note?.isProblem == true)
                    .padding(.horizontal, Tokens.Layout.cardPad)
            }
        }
        .modifier(FullEffects(note: note, line: line, isOn: !isCovered))
        .fullScreenCover(isPresented: $isOpen, onDismiss: uncover) {
            FullScreen(note: $note) { isOpen = false }
        }
        .task { await openForShot() }
    }

    private var rows: some View {
        let value = Words.fullRowValue(shop.status)
        return SettingsSection(title: VeggieText.purchase) {
            SettingsRow(
                icon: "bag",
                label: Words.fullRow,
                value: value,
                action: value == nil ? { openFull() } : nil
            )
            SettingsDivider()
            SettingsRow(
                icon: "arrow.clockwise",
                label: VeggieText.restore,
                value: shop.doing == .restoring ? Words.fullRestoring : nil,
                accessory: .none,
                action: restore
            )
            .disabled(shop.isBusy)
        }
    }

    private func openFull() {
        note = nil
        isCovered = true
        isOpen = true
    }

    /// 在付費頁講過的不在這裡再講一次；買到一半關掉的還沒講，留著等結果。
    private func uncover() {
        if !shop.isBusy {
            note = nil
        }
        isCovered = false
    }

    private func restore() {
        note = nil
        Task {
            let result = await shop.restore()
            note = FullNote(result: .restored(result))
        }
    }

    /// 開發版截圖走查：排版好了再開，跟點那一列同一條路。
    private func openForShot() async {
        guard LaunchOptions.opensFull else { return }
        try? await Task.sleep(for: .milliseconds(Params.tickMs))
        openFull()
    }
}
