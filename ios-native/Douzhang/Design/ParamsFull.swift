import Foundation

/// 跟 App Store 要東西的數字（準則 6-9）。
extension Params {
    /// 讀價格、讀購買紀錄每次最多等幾秒
    static let storeWaitSeconds = 10.0
    /// 讀價格最多試幾次
    static let storeTries = 2
}
