// 番茄帳：計時中把選好的 app 蓋上系統擋板（螢幕使用時間 API）。
// 只做四件事：要授權、開系統的選 app 畫面、蓋上、解開。什麼時候蓋、什麼時候解由 JS（core/shield.js）決定。
// 選了哪些 app 只存在這支手機的 UserDefaults：系統給的是不透明代號，讀不出 app 名稱，也不進備份檔。
// 沒有擴充、沒有 App Group、沒有排程：到點不會自己解開，要回到番茄帳才解（第一版的取捨，見切片帳本 AF1）。

import ExpoModulesCore
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

private let selectionKey = "appShield.selection"

private func loadSelection() -> FamilyActivitySelection {
  guard let data = UserDefaults.standard.data(forKey: selectionKey),
    let saved = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
  else {
    return FamilyActivitySelection()
  }
  return saved
}

private func saveSelection(_ selection: FamilyActivitySelection) {
  guard let data = try? PropertyListEncoder().encode(selection) else {
    return
  }
  UserDefaults.standard.set(data, forKey: selectionKey)
}

private func countOf(_ selection: FamilyActivitySelection) -> Int {
  return selection.applicationTokens.count + selection.categoryTokens.count
    + selection.webDomainTokens.count
}

public final class AppShieldModule: Module {
  private let store = ManagedSettingsStore()

  public func definition() -> ModuleDefinition {
    Name("AppShield")

    // 要「個人用」的螢幕使用時間授權。已經允許過不會再跳框；不允許或失敗都回 false。
    AsyncFunction("authorize") { () async -> Bool in
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        return true
      } catch {
        return false
      }
    }

    // 目前選了幾項（app、類別、網站加起來）。
    Function("count") { () -> Int in
      return countOf(loadSelection())
    }

    // 開系統的選擇畫面。按完成才存；取消不動原本選的。回傳關掉之後選了幾項。
    AsyncFunction("pick") { (cancelLabel: String, doneLabel: String, promise: Promise) in
      // 下面 runOnQueue(.main) 保證在主執行緒；assumeIsolated 是講給編譯器聽的（畫面元件只准在主執行緒建）
      MainActor.assumeIsolated {
        guard let presenter = self.appContext?.utilities?.currentViewController() else {
          promise.resolve(countOf(loadSelection()))
          return
        }
        var host: UIViewController?
        let screen = PickerScreen(
          selection: loadSelection(),
          cancelLabel: cancelLabel,
          doneLabel: doneLabel,
          onClose: { picked in
            if let picked = picked {
              saveSelection(picked)
            }
            host?.dismiss(animated: true) {
              promise.resolve(countOf(loadSelection()))
            }
          }
        )
        let controller = UIHostingController(rootView: screen)
        // 不准往下滑關掉：只能按取消或完成，promise 才一定有結果
        controller.isModalInPresentation = true
        host = controller
        presenter.present(controller, animated: true)
      }
    }
    .runOnQueue(.main)

    // 把選好的蓋上擋板。沒授權或沒選東西時系統什麼都不做。
    Function("block") {
      let selection = loadSelection()
      self.store.shield.applications =
        selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
      self.store.shield.applicationCategories =
        selection.categoryTokens.isEmpty
        ? nil : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
      self.store.shield.webDomains =
        selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    // 全部解開。
    Function("unblock") {
      self.store.clearAllSettings()
    }

    // 清空所有資料時用：解開，選過的也忘掉（安全標準 P5）。
    Function("forget") {
      self.store.clearAllSettings()
      UserDefaults.standard.removeObject(forKey: selectionKey)
    }
  }
}

private struct PickerScreen: View {
  @State var selection: FamilyActivitySelection
  let cancelLabel: String
  let doneLabel: String
  let onClose: (FamilyActivitySelection?) -> Void

  var body: some View {
    NavigationStack {
      FamilyActivityPicker(selection: $selection)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(cancelLabel) { onClose(nil) }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(doneLabel) { onClose(selection) }
          }
        }
    }
  }
}
