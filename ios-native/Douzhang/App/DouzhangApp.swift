import SwiftUI
import VeggieKit

@main
struct DouzhangApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.run() }
                // 外觀設在視窗上，所以等畫面出來才套
                .onAppear { Appearance.stored.apply() }
        }
        .onChange(of: scenePhase) { _, next in
            if next == .active {
                model.becameActive()
            }
        }
    }
}
