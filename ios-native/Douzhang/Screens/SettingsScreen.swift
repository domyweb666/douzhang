import SwiftUI
import VeggieKit

/// 設定頁現在開著哪張半頁。
enum SettingsSheet: Identifiable, Hashable {
    case tag(String), restShort, restLong

    var id: Self {
        self
    }
}

/// 設定（左右滑三頁的右邊那頁）。順序照多米 iOS 開發準則 3-3：
/// app 專屬（標籤、節奏、專注、手感）→ 一般 → 資料（清除排最後）→ 支援 → 關於 → 頁尾。
/// 列的樣子與全家共用的字來自 VeggieKit，顏色與字級在最外層用 veggieStyle 給一次。
/// 改完立刻生效（下一拍就讀新設定）。卡片下不放常駐說明，只有出錯與結果才出現一行（3-4）。
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: SettingsSheet?

    var body: some View {
        VStack(spacing: .zero) {
            PageTitle(text: Words.settings)
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Layout.section) {
                    types
                    SettingsRhythm { sheet = $0 }
                    SettingsShield()
                    feel
                    developer
                    SettingsGeneral()
                    SettingsData()
                    SettingsSupport()
                    SettingsAbout()
                }
                .padding(.top, Tokens.Layout.section)
                .padding(.bottom, Tokens.Layout.bottomClear)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(item: $sheet) { which in sheetBody(which) }
        .veggieStyle(.douzhang)
    }

    // MARK: 標籤

    private var types: some View {
        let settings = model.state.settings
        return SettingsSection(title: Words.taskType) {
            ForEach(settings.types) { type in
                typeRow(type)
                SettingsDivider()
            }
            SettingsRow(icon: "plus", label: Words.addType, accessory: .none) {
                Feel.change { _ = model.addType() }
            }
        }
    }

    /// 一個標籤：前面一顆它的番茄、名字，右邊長度＋箭頭。VeggieRow 只收系統圖示，這一列自己排成同一個樣子。
    private func typeRow(_ type: TagType) -> some View {
        Button {
            sheet = .tag(type.id)
        } label: {
            HStack(spacing: Tokens.Layout.group) {
                TomatoView(color: type.color, size: Tokens.SettingsPage.icon)
                Text(type.name)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Words.typeLen(type.len)).foregroundStyle(Tokens.Colors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(Tokens.Fonts.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Colors.textTertiary)
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

    // MARK: 手感、開發

    private var feel: some View {
        SettingsSection(title: Words.feel) {
            SettingsToggle(
                icon: "gyroscope",
                label: Words.tiltRow,
                isOn: model.state.settings.tilt
            ) { isOn in
                model.update { $0.tilt = isOn }
            }
        }
    }

    /// 開發期才有的測試模式開關（正式 build 整區不畫）。
    @ViewBuilder private var developer: some View {
        #if DEBUG
            SettingsSection(title: Words.devSection) {
                SettingsToggle(
                    icon: "hammer",
                    label: Words.testModeRow,
                    isOn: model.state.settings.demo
                ) { isOn in
                    model.update { $0.demo = isOn }
                }
            }
        #endif
    }
}
