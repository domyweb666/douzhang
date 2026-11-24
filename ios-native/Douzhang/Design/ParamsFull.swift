import Foundation

/// 完整版的數字：跟 App Store 要東西（準則 6-9）、付費頁的範例。
extension Params {
    /// 讀價格、讀購買紀錄每次最多等幾秒
    static let storeWaitSeconds = 10.0
    /// 讀價格最多試幾次
    static let storeTries = 2

    /// 付費頁那張聚焦預覽的範例：一顆 25 分鐘的，剩 8 分 16 秒
    enum FullSample {
        static let totalMs = 25 * msPerMinute
        static let leftMs = 8 * msPerMinute + 16 * msPerSecond
    }
}
