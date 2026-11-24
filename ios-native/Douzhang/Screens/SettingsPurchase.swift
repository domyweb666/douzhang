import SwiftUI
import VeggieKit

/// 設定頁的「購買」那一區：完整版（沒買點進付費頁，買了寫「已購買」不能點）、恢復購買（都在）。
/// 這裡不讀價格、不連線。還不知道買了沒照沒買的畫；知道了只換這一列右邊，列不增不減。
struct SettingsPurchase: View {
    @Environment(Purchases.self) private var shop
    @State private var isOpen = false
    /// 付費頁蓋著，含收起來的那段動畫
    @State private var isCovered = false

    var body: some View {
        @Bindable var shop = shop
        let note = shop.lastNote
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
            FullScreen(note: $shop.lastNote) { isOpen = false }
        }
        .onChange(of: shop.status, initial: true) { _, status in forget(status) }
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
        shop.lastNote = shop.lastNote?.kept(shop.status)
        isCovered = true
        isOpen = true
    }

    /// 在付費頁講過的不在這裡再講一次，錢還沒定論的例外；買到一半關掉的還沒講，留著等結果。
    private func uncover() {
        if !shop.isBusy {
            shop.lastNote = shop.lastNote?.kept(shop.status)
        }
        isCovered = false
    }

    /// 別處核准了：沒定論的那句不留著，不然哪天退款，「在等核准」又冒出來。
    /// 付費頁還開著的先不動（那一頁要換成「買好了」），關掉的時候再忘。
    private func forget(_ status: FullStatus) {
        if status == .owned, !isCovered, shop.lastNote?.isUnsettled == true {
            shop.lastNote = nil
        }
    }

    private func restore() {
        shop.lastNote = shop.lastNote?.kept(shop.status)
        Task {
            let result = await shop.restore()
            shop.lastNote = FullNote.after(shop.lastNote, .restored(result))
        }
    }

    /// 開發版截圖走查：排版好了再開，跟點那一列同一條路。
    private func openForShot() async {
        guard LaunchOptions.opensFull else { return }
        try? await Task.sleep(for: .milliseconds(Params.tickMs))
        openFull()
    }
}
