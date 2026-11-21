import FamilyControls
import Foundation
import ManagedSettings

/// 計時中把選好的 app 蓋上系統擋板（螢幕使用時間 API）。
/// 只做四件事：要授權、記住選了哪些、蓋上、解開。什麼時候蓋由 Gates.shouldShield 決定。
/// 選了哪些 app 只存在這支手機的 UserDefaults：系統給的是不透明代號，讀不出 app 名稱，也不進備份檔。
/// 沒有擴充、沒有排程：到點那一刻 app 在背景的話不會自己解開，要回到番茄帳才解（第一版的取捨）。
/// 擋不擋得成都不能卡住計時，所以失敗一律不往外丟。
@MainActor
final class AppShield {
    private enum Applied {
        case unknown, blocked, clear
    }

    private static let selectionKey = "appShield.selection"
    private lazy var store = ManagedSettingsStore()
    private var applied = Applied.unknown

    func loadSelection() -> FamilyActivitySelection {
        guard let data = UserDefaults.standard.data(forKey: AppShield.selectionKey) else {
            return FamilyActivitySelection()
        }
        let saved = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        return saved ?? FamilyActivitySelection()
    }

    func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? PropertyListEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: AppShield.selectionKey)
    }

    /// 目前選了幾項（app、類別、網站加起來）。
    func count() -> Int {
        let selection = loadSelection()
        let apps = selection.applicationTokens.count
        return apps + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    /// 要「個人用」的螢幕使用時間授權。已經允許過不會再跳框；不允許或失敗都回 false。
    func authorize() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return true
        } catch {
            return false
        }
    }

    /// 蓋上或解開。答案跟上次一樣就不叫系統；開機第一次一定叫（上次被殺掉時可能還蓋著）。
    func apply(_ isOn: Bool) {
        let next = isOn ? Applied.blocked : Applied.clear
        if next == applied {
            return
        }
        reapply(isOn)
    }

    /// 照現在選的重蓋一次（計時中改了要擋的）。沒授權、沒選東西時系統自己不會擋。
    func reapply(_ isOn: Bool) {
        applied = isOn ? .blocked : .clear
        guard isOn else {
            store.clearAllSettings()
            return
        }
        let selection = loadSelection()
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let sites = selection.webDomainTokens
        store.shield.applications = apps.isEmpty ? nil : apps
        let policy = ShieldSettings.ActivityCategoryPolicy<Application>.specific(categories)
        store.shield.applicationCategories = categories.isEmpty ? nil : policy
        store.shield.webDomains = sites.isEmpty ? nil : sites
    }

    /// 清空所有資料時用：解開，選過的也忘掉。
    func forget() {
        store.clearAllSettings()
        applied = .clear
        UserDefaults.standard.removeObject(forKey: AppShield.selectionKey)
    }
}
