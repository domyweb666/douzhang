import SwiftUI
import UniformTypeIdentifiers
import VeggieKit

/// 設定頁的「資料」那一區：iCloud 同步（買了才列）、匯出（右邊是上次自動備份那天）、匯入、
/// 最後一列清除；出錯原因（有才出）在卡片下。
struct SettingsData: View {
    @Environment(AppModel.self) private var model
    @Environment(Purchases.self) private var shop
    @State private var importing = false
    @State private var askingWipe = false

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: Tokens.Layout.item) {
            rows
            SettingsCloudLine()
            if let problem = model.backupProblem {
                Text(problem.words)
                    .font(Tokens.Fonts.sub)
                    .foregroundStyle(Tokens.Colors.danger)
                    .padding(.horizontal, Tokens.Layout.cardPad)
            }
        }
        .sheet(item: $model.exportFile, onDismiss: model.exportFinished) { export in
            ShareSheet(url: export.url) { model.exportFinished() }
                .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            model.importPicked(result)
        }
        .alert(
            Words.importConfirm,
            isPresented: importAsk,
            presenting: model.pendingImport
        ) { incoming in
            Button(Words.cancel, role: .cancel) { model.cancelImport() }
            // 要換上的那一份由框自己帶著：框收掉時 pendingImport 可能先被清成 nil
            Button(Words.importConfirmOk) { model.confirmImport(incoming) }
        } message: { incoming in
            Text(preview(incoming))
        }
        .modifier(WipeAsk(isAsking: $askingWipe))
    }

    private var rows: some View {
        SettingsSection(title: VeggieText.data) {
            if shop.allows(.cloud) {
                SettingsCloud()
                SettingsDivider()
            }
            SettingsRow(
                icon: "square.and.arrow.up",
                label: VeggieText.exportData,
                value: lastBackup
            ) {
                model.exportBackup()
            }
            SettingsDivider()
            SettingsRow(icon: "square.and.arrow.down", label: VeggieText.importData) {
                importing = true
            }
            SettingsDivider()
            SettingsRow(
                icon: "xmark.circle",
                label: VeggieText.eraseAll,
                accessory: .none,
                danger: true
            ) {
                askingWipe = true
            }
        }
    }

    /// 匯入的確認框：有等著換上的那一份才問。
    private var importAsk: Binding<Bool> {
        Binding(
            get: { model.pendingImport != nil },
            set: { isOn in
                if !isOn {
                    model.cancelImport()
                }
            }
        )
    }

    private func preview(_ incoming: AppState) -> String {
        let current = model.unreadable ? nil : BeanTally(model.state)
        return Words.importPreview(BeanTally(incoming), current: current)
    }

    private var lastBackup: String? {
        model.lastBackup.map { Words.lastAutoBackup(Words.monthDay(Store.dayKey($0))) }
    }
}
