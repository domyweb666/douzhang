import SwiftUI
import UIKit

/// 最外層：畫布色鋪滿，上面是狀態那幾行，下面依現在哪一態換畫面。
/// 鈴響是另一整頁；聚焦模式是橫放的整頁時鐘；其他時候是左右滑的三頁加懸浮分頁列。
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(Purchases.self) private var shop

    var body: some View {
        ZStack {
            Tokens.Colors.background.ignoresSafeArea()
            if model.zenOn, let run = model.state.focusRun {
                FocusScreen(run: run, type: Machine.typeOf(model.state, run.typeId))
            } else if model.loaded {
                VStack(spacing: .zero) {
                    StatusLines()
                    if model.phase == .bell {
                        BellScreen().padding(.horizontal, Tokens.Space.screen)
                    } else {
                        PagerView()
                    }
                }
            }
        }
        // 震動只留給有意義的那幾刻：響了、收下、拿掉東西、出錯。切換選項的輕觸在各自的元件上
        .haptic(.success, trigger: model.pulses.kept)
        .haptic(.success, trigger: model.pulses.rang)
        .haptic(.impact(weight: .light), trigger: model.pulses.removed)
        .haptic(.error, trigger: model.saveFailed) { $0 }
        .haptic(.error, trigger: model.backupProblem) { $0 != nil }
        // 買了才准同步、擋 app、聚焦；退款只停這三樣，番茄與開關都不動
        .onChange(of: shop.status, initial: true) { _, status in
            model.setFull(status)
        }
        .modifier(CloudAsk())
    }
}

/// 最上面那幾行狀態：本機檔讀不懂、存不進去、計時中通知沒開。都沒有就什麼都不佔。
struct StatusLines: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            if model.unreadable {
                dangerLine(Words.importUnreadable)
            }
            if model.saveFailed {
                dangerLine(Words.saveFailed)
            }
            if model.notif == .denied, model.phase == .focus {
                notificationOff
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Space.screen)
    }

    private func dangerLine(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Fonts.caption)
            .foregroundStyle(Tokens.Colors.danger)
            .padding(.top, Tokens.Space.s)
    }

    /// 通知被拒：一行狀態（不是錯誤）＋去系統設定的路。只在計時中顯示，不再跳任何框。
    private var notificationOff: some View {
        HStack {
            Text(Words.notificationOffLine)
                .font(Tokens.Fonts.sub)
                .foregroundStyle(Tokens.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextButton(label: Words.openNotifications) { SystemSettings.openNotifications() }
        }
    }
}

/// 帶使用者去系統設定裡番茄帳的那一頁。
enum SystemSettings {
    static func openNotifications() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// 左右滑三頁（番茄架在左、主畫面在中、設定在右），下面是懸浮分頁列，點了也會換頁。
/// 計時中鎖在主畫面：分頁列不畫、不能滑。
struct PagerView: View {
    @Environment(AppModel.self) private var model
    @State private var pager = PagerMotion()

    var body: some View {
        @Bindable var model = model
        let focusing = model.phase == .focus
        ScrollView(.horizontal) {
            HStack(spacing: .zero) {
                page(RackScreen(), .rack)
                page(HomeScreen(), .home)
                page(SettingsScreen(), .settings)
            }
            .scrollTargetLayout()
            .background(PromptTouches())
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $model.page)
        .modifier(PagerWatch(pager: pager))
        .environment(pager)
        // 一開始停在中間那頁（主畫面）
        .defaultScrollAnchor(.center)
        .scrollIndicators(.hidden)
        .scrollDisabled(focusing)
        .task {
            // 開發版截圖走查指定了別頁：第一次排版一律停在中間，排好之後再換過去（跟點分頁列同一條路）
            let target = LaunchOptions.page
            if target != .home {
                try? await Task.sleep(for: .milliseconds(Params.tickMs))
                model.page = target
            }
        }
        .overlay(alignment: .bottom) {
            if !focusing {
                TabBar(page: $model.page) { pager.tabBar = $0 }
            }
        }
    }

    private func page(_ content: some View, _ page: Page) -> some View {
        content
            .padding(.horizontal, Tokens.Space.screen)
            .containerRelativeFrame(.horizontal)
            .id(page)
    }
}
