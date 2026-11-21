import SwiftUI

@main
struct DouzhangApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.run() }
        }
        .onChange(of: scenePhase) { _, next in
            if next == .active { model.becameActive() }
        }
    }
}
