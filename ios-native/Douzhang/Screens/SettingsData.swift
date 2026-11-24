import SwiftUI
import UniformTypeIdentifiers
import VeggieKit

/// 設定頁的「資料」那一區：匯出（右邊是上次自動備份那天）、匯入、最後一列清除；
/// 出錯原因（有才出）紅字在卡片下。
struct SettingsData: View {
    @Environment(AppModel.self) private var model
    @State private var importing = false
    @State private var askingWipe = false
    @State private var askingWipeAgain = false

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: Tokens.Layout.item) {
            rows
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
        // 清除問兩次、兩次的按鈕字不一樣、第一次附匯出（準則 3-3）。
        // 下一個框、分享選單等這個框收掉那一拍過了再開：同一拍開，系統會吞掉
        .alert(Words.wipeTitle, isPresented: $askingWipe) {
            Button(Words.wipeExportFirst, action: exportFirst)
            Button(VeggieText.eraseAll, role: .destructive) { Task { askingWipeAgain = true } }
            Button(Words.cancel, role: .cancel) {}
        }
        .alert(Words.wipeAgainTitle, isPresented: $askingWipeAgain) {
            Button(Words.wipeAgainOk, role: .destructive) { model.wipeAll() }
            Button(Words.cancel, role: .cancel) {}
        }
    }

    private var rows: some View {
        SettingsSection(title: VeggieText.data) {
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

    private func exportFirst() {
        Task { model.exportBackup() }
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
