import FamilyControls
import SwiftUI

/// 設定頁的「專注」那一區：計時中擋住其他 app。
/// 兩列都要先有螢幕使用時間的授權：不允許就不開、不開選擇畫面，卡片下才出現那一行。
struct SettingsShield: View {
    @Environment(AppModel.self) private var model
    @State private var denied = false
    @State private var picking = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        let count = model.shieldCount
        SettingsSection(
            title: Words.shieldSection,
            footer: denied ? Words.shieldDenied : nil
        ) {
            SettingsToggle(
                icon: "lock.shield",
                label: Words.shieldRow,
                isOn: model.state.settings.shield
            ) { isOn in
                Task { denied = await !model.setShield(isOn) }
            }
            SettingsDivider()
            SettingsRow(
                icon: "apps.iphone",
                label: Words.shieldAppsRow,
                value: count > 0 ? Words.shieldAppsCount(count) : Words.shieldAppsNone,
                action: pick
            )
        }
        .familyActivityPicker(isPresented: $picking, selection: $selection)
        .onChange(of: selection) { _, next in model.shieldPicked(next) }
    }

    /// 開系統的選擇畫面。沒授權時那個畫面是空的，所以先要授權。
    private func pick() {
        Task {
            let allowed = await model.shield.authorize()
            denied = !allowed
            guard allowed else { return }
            selection = model.shield.loadSelection()
            picking = true
        }
    }
}
