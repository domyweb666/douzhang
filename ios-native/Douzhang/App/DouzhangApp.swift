import SwiftUI

/// 骨架：先證明沒有 Mac 也編得過、測試跑得起來。畫面在後面的片一頁一頁搬過來。
@main
struct DouzhangApp: App {
    var body: some Scene {
        WindowGroup {
            Text(Words.appName)
        }
    }
}
