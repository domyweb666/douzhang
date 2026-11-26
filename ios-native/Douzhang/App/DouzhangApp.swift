import SwiftUI
import VeggieKit

@main
struct DouzhangApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()
    @State private var shop = Purchases()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(shop)
                .task { await model.run() }
                .task { shop.start() }
                // 外觀設在視窗上，所以等畫面出來才套
                .onAppear { Appearance.stored.apply() }
        }
        .onChange(of: scenePhase) { _, next in
            switch next {
            case .active:
                model.becameActive()
                Task { await shop.refresh() }
            case .background:
                // 存檔在背景寫：進背景就可能被系統收掉，還沒落地的當場寫完
                model.flushSaves()
                model.cloud.enteredBackground()
            default:
                break
            }
        }
    }
}
