import SwiftUI
import UniformTypeIdentifiers

/// 設定頁現在開著哪張半頁。
enum SettingsSheet: Identifiable, Hashable {
    case tag(String), restShort, restLong

    var id: Self {
        self
    }
}

/// 設定（左右滑三頁的右邊那頁）。順序照多米 iOS 開發準則 3-3：
/// app 專屬（標籤、節奏、專注、手感）→ 一般（通知、聲音）→ 資料（匯出、匯入、清空排最後）。
/// 改完立刻生效（下一拍就讀新設定）。卡片下不放常駐說明，只有出錯與結果才出現一行（3-4）。
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: SettingsSheet?
    @State private var importing = false
    @State private var askingWipe = false
    @State private var askingWipeAgain = false

    var body: some View {
        @Bindable var model = model
        VStack(spacing: .zero) {
            PageTitle(text: Words.settings)
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Layout.section) {
                    types
                    SettingsRhythm { sheet = $0 }
                    SettingsShield()
                    feel
                    developer
                    general
                    backup
                }
                .padding(.top, Tokens.Layout.section)
                .padding(.bottom, Tokens.Layout.bottomClear)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(item: $sheet) { which in sheetBody(which) }
        .sheet(item: $model.exportFile, onDismiss: model.exportFinished) { export in
            ShareSheet(url: export.url) { model.exportFinished() }
                .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            model.importPicked(result)
        }
        .alert(Words.importConfirm, isPresented: importAsk) {
            Button(Words.cancel, role: .cancel) { model.cancelImport() }
            Button(Words.importConfirmOk) { model.confirmImport() }
        }
        // 清空問兩次、兩次的按鈕字不一樣、第一次附匯出（準則 3-3）。
        // 下一個框、分享選單等這個框收掉那一拍過了再開：同一拍開，系統會吞掉
        .alert(Words.wipeTitle, isPresented: $askingWipe) {
            Button(Words.wipeExportFirst, action: exportFirst)
            Button(Words.wipeAll, role: .destructive) { Task { askingWipeAgain = true } }
            Button(Words.cancel, role: .cancel) {}
        }
        .alert(Words.wipeAgainTitle, isPresented: $askingWipeAgain) {
            Button(Words.wipeAgainOk, role: .destructive) { model.wipeAll() }
            Button(Words.cancel, role: .cancel) {}
        }
    }

    private func exportFirst() {
        Task { model.exportBackup() }
    }

    /// 匯入的確認框：有等著覆蓋的那一份才問。
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

    // MARK: 標籤

    private var types: some View {
        let settings = model.state.settings
        return SettingsSection(title: Words.taskType) {
            ForEach(settings.types) { type in
                typeRow(type)
                SettingsDivider()
            }
            TextButton(label: Words.addType, flush: true) {
                Feel.change { _ = model.addType() }
            }
            .frame(maxWidth: .infinity, minHeight: Tokens.Shape.row, alignment: .leading)
        }
    }

    /// 一個標籤：前面一顆它的番茄色、名字，右邊長度＋箭頭。
    private func typeRow(_ type: TagType) -> some View {
        Button {
            sheet = .tag(type.id)
        } label: {
            HStack(spacing: Tokens.Layout.group) {
                TomatoView(color: type.color, size: Tokens.Shape.colorSwatch / 1.5)
                Text(type.name)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Words.typeLen(type.len)).foregroundStyle(Tokens.Colors.textSecondary)
                Text(Words.chevron).foregroundStyle(Tokens.Colors.textTertiary)
            }
            .font(Tokens.Fonts.body)
            .frame(minHeight: Tokens.Shape.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(FadeStyle())
        .accessibilityLabel("\(type.name)，\(Words.typeLen(type.len))")
    }

    @ViewBuilder
    private func sheetBody(_ which: SettingsSheet) -> some View {
        let settings = model.state.settings
        switch which {
        case let .tag(id):
            if let type = settings.types.first(where: { $0.id == id }) {
                TagEditor(type: type, canDelete: settings.types.count > 1) { sheet = nil }
            }
        case .restShort:
            RestShortSheet()
        case .restLong:
            RestLongSheet()
        }
    }

    // MARK: 一般、手感、開發

    /// 到點通知：允許「開著」；被拒「沒開」＋點了去系統設定；
    /// 還沒問過整列不出現（第一次按開始才問，那時系統設定裡也還沒有這一列）。
    private var general: some View {
        SettingsSection(title: Words.general) {
            switch model.notif {
            case .undetermined:
                EmptyView()
            case .granted:
                SettingsRow(label: Words.notifRow, value: Words.notifOn)
                SettingsDivider()
            case .denied:
                SettingsRow(label: Words.notifRow, value: Words.notifOff) {
                    SystemSettings.openNotifications()
                }
                SettingsDivider()
            }
            SettingsToggle(label: Words.soundRow, isOn: model.state.settings.sound) { isOn in
                model.update { $0.sound = isOn }
            }
        }
    }

    private var feel: some View {
        SettingsSection(title: Words.feel) {
            SettingsToggle(label: Words.tiltRow, isOn: model.state.settings.tilt) { isOn in
                model.update { $0.tilt = isOn }
            }
        }
    }

    /// 開發期才有的測試模式開關（正式 build 整區不畫）。
    @ViewBuilder private var developer: some View {
        #if DEBUG
            SettingsSection(title: Words.devSection) {
                SettingsToggle(label: Words.testModeRow, isOn: model.state.settings.demo) { isOn in
                    model.update { $0.demo = isOn }
                }
            }
        #endif
    }

    // MARK: 資料

    /// 匯出（右邊是上次自動備份那天）、匯入、最後一列清空；出錯原因（有才出）紅字在卡片下。
    private var backup: some View {
        VStack(alignment: .leading, spacing: Tokens.Layout.item) {
            SettingsSection(title: Words.dataSection) {
                SettingsRow(label: Words.exportBackup, value: lastBackup) { model.exportBackup() }
                SettingsDivider()
                SettingsRow(label: Words.importBackup) { importing = true }
                SettingsDivider()
                SettingsRow(label: Words.wipeAll, danger: true) { askingWipe = true }
            }
            if let problem = model.backupProblem {
                Text(problem.words)
                    .font(Tokens.Fonts.sub)
                    .foregroundStyle(Tokens.Colors.danger)
                    .padding(.horizontal, Tokens.Layout.cardPad)
            }
        }
    }

    private var lastBackup: String? {
        model.lastBackup.map { Words.lastAutoBackup(Words.monthDay(Store.dayKey($0))) }
    }
}
