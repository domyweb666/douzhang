import Foundation

/// 開發版的啟動選項：給雲端模擬器截圖走查用（scripts/screens.sh）。
/// 用環境變數指定讀哪個資料夾的存檔、一開始停在哪一頁、番茄架看哪一種。正式 build 一律讀不到。
enum LaunchOptions {
    private static func value(_ name: String) -> String {
        #if DEBUG
            return ProcessInfo.processInfo.environment[name] ?? ""
        #else
            return ""
        #endif
    }

    /// 存檔改放這個資料夾（裡面先擺好要截的那一態）。沒指定是 nil。
    static var dataFolder: URL? {
        let path = value("DOUZHANG_DATA_DIR")
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    /// 單元測試寄生在 app 裡跑。
    static var isTesting: Bool {
        !value("XCTestConfigurationFilePath").isEmpty
    }

    static var page: Page {
        switch value("DOUZHANG_PAGE") {
        case "rack": .rack
        case "settings", "full": .settings
        default: .home
        }
    }

    /// 打開就停在付費頁。只開畫面，不碰買了沒。
    static var opensFull: Bool {
        value("DOUZHANG_PAGE") == "full"
    }

    static var rackMode: RackMode {
        value("DOUZHANG_RACK") == "stats" ? .stats : .calendar
    }

    static var rackView: RackView {
        switch value("DOUZHANG_RACK") {
        case "three": .three
        case "week": .week
        case "month": .month
        default: .day
        }
    }
}
