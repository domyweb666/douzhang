import SwiftUI
import UniformTypeIdentifiers

/// 設定頁現在開著哪張半頁。
enum SettingsSheet: Identifiable, Hashable {
    case tag(String), restShort, restLong

    var id: Self {
        self
    }
}

/// 設定（左右滑三頁的右邊那頁）。依序：標籤、節奏、提醒、專注、手感、備份。
/// 改完立刻生效（下一拍就讀新設定）。每區是一張白卡，列之間有分隔線，說明字放在卡片下。
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: SettingsSheet?
    @State private var importing = false
    @State private var askingWipe = false

    var body: some View {
        @Bindable var model = model
        VStack(spacing: .zero) {
            PageTitle(text: Words.settings)
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.section) {
                    types
                    SettingsRhythm { sheet = $0 }
                    reminders
                    SettingsShield()
                    feel
                    developer
                    backup
                    SettingsSection {
                        SettingsRow(label: Words.wipeAll, danger: true) { askingWipe = true }
                    }
                }
                .padding(.top, Tokens.Space.l)
                .padding(.bottom, Tokens.Shape.tabClearance)
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
        .alert(Words.wipeTitle, isPresented: $askingWipe) {
            Button(Words.cancel, role: .cancel) {}
            Button(Words.wipeAll, role: .destructive) { model.wipeAll() }
        } message: {
            Text(Words.wipeBody)
        }
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
        return SettingsSection(title: Words.taskType, footer: Words.typeSub) {
            ForEach(settings.types) { type in
                typeRow(type)
                SettingsDivider()
            }
            TextButton(label: Words.addType, flush: true) { _ = model.addType() }
                .frame(maxWidth: .infinity, minHeight: Tokens.Shape.row, alignment: .leading)
        }
    }

    /// 一個標籤：前面一顆它的番茄色、名字，右邊長度＋箭頭。
    private func typeRow(_ type: TagType) -> some View {
        Button {
            sheet = .tag(type.id)
        } label: {
            HStack(spacing: Tokens.Space.m) {
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

    // MARK: 提醒、手感、開發

    /// 到點通知：允許「開著」；被拒「沒開」＋點了去系統設定；
    /// 還沒問過什麼都不寫（第一次按開始才問，那時系統設定裡也還沒有這一列）。
    private var reminders: some View {
        SettingsSection(title: Words.reminders) {
            switch model.notif {
            case .undetermined:
                SettingsRow(label: Words.notifRow)
            case .granted:
                SettingsRow(label: Words.notifRow, value: Words.notifOn)
            case .denied:
                SettingsRow(label: Words.notifRow, value: Words.notifOff) {
                    SystemSettings.openNotifications()
                }
            }
            SettingsDivider()
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
            SettingsSection(title: Words.devSection, footer: Words.testModeSub) {
                SettingsToggle(label: Words.testModeRow, isOn: model.state.settings.demo) { isOn in
                    model.update { $0.demo = isOn }
                }
            }
        #endif
    }

    // MARK: 備份

    /// 匯出、匯入兩列；出錯原因（有才出）紅字在卡片下；說明與上次自動備份時間放在說明字。
    private var backup: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            SettingsSection(title: Words.backup, footer: backupFooter) {
                SettingsRow(label: Words.exportBackup) { model.exportBackup() }
                SettingsDivider()
                SettingsRow(label: Words.importBackup) { importing = true }
            }
            if let problem = model.backupProblem {
                Text(problem.words)
                    .font(Tokens.Fonts.sub)
                    .foregroundStyle(Tokens.Colors.danger)
                    .padding(.horizontal, Tokens.Space.card)
            }
        }
    }

    private var backupFooter: String {
        guard let last = model.lastBackup else { return Words.backupNote }
        let when = "\(Words.monthDay(Store.dayKey(last))) \(TimeText.hhmm(last))"
        return "\(Words.backupNote)\n\(Words.lastAutoBackup(when))"
    }
}
