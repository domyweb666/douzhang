import AppIntents

/// 不用自己建捷徑：裝好番茄帳，捷徑 App、Siri、動作按鈕的選單裡就有這一個。
struct DouzhangShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTomatoIntent(),
            phrases: [
                "用\(.applicationName)開始一顆",
                "\(.applicationName)開始一顆",
                "用\(.applicationName)開始一顆番茄",
            ],
            shortTitle: "開始一顆番茄",
            systemImageName: "timer"
        )
    }
}
