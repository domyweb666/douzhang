import Foundation

/// 鎖定畫面與動態島那張卡的數字。
extension Params {
    /// 休息完待機超過幾小時，app 下次醒來就收掉那張卡（系統自己最長留 8 小時）
    static let liveIdleHours = 2.0
}
