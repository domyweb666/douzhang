import SwiftUI
import VeggieKit

/// 設定頁的「一般」那一區：外觀、到點通知、觸覺回饋、聲音。
/// 外觀與觸覺回饋是這支手機的偏好，存在 UserDefaults，不進備份檔。
struct SettingsGeneral: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Appearance.storageKey) private var appearanceCode = Appearance.system.rawValue
    @AppStorage(VeggieHaptics.storageKey) private var hapticsOn = true

    private var appearance: Appearance {
        Appearance(rawValue: appearanceCode) ?? .system
    }

    var body: some View {
        SettingsSection(title: VeggieText.general) {
            appearanceRow
            SettingsDivider()
            notificationRow
            VeggieToggleRow(
                icon: "iphone.radiowaves.left.and.right",
                title: VeggieText.haptics,
                isOn: $hapticsOn
            )
            SettingsDivider()
            SettingsToggle(
                icon: "speaker.wave.2",
                label: Words.soundRow,
                isOn: model.state.settings.sound
            ) { isOn in
                model.update { $0.sound = isOn }
            }
        }
    }

    /// 外觀三選一，選完立刻換。聚焦模式的黑底是固定的顏色，不跟著變。
    private var appearanceRow: some View {
        Menu {
            Picker(VeggieText.appearance, selection: $appearanceCode) {
                ForEach(Appearance.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
        } label: {
            VeggieRow(
                icon: "circle.lefthalf.filled",
                title: VeggieText.appearance,
                value: appearance.title,
                accessory: .push
            )
        }
        .buttonStyle(.plain)
        .onChange(of: appearanceCode) { appearance.apply() }
    }

    /// 到點通知：允許「開著」；被拒「沒開」＋點了去系統設定；
    /// 還沒問過整列不出現（第一次按開始才問，那時系統設定裡也還沒有這一列）。
    @ViewBuilder private var notificationRow: some View {
        switch model.notif {
        case .undetermined:
            EmptyView()
        case .granted:
            SettingsRow(icon: "bell", label: Words.notifRow, value: Words.notifOn)
            SettingsDivider()
        case .denied:
            SettingsRow(
                icon: "bell",
                label: Words.notifRow,
                value: Words.notifOff,
                accessory: .external
            ) {
                SystemSettings.openNotifications()
            }
            SettingsDivider()
        }
    }
}
