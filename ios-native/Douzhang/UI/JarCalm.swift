import Foundation

/// 睡著時拿來決定要不要醒的傾斜讀數：先平滑再跟重力比。手拿著的小抖動忽左忽右，平滑後互相抵掉，
/// 醒不了；真的斜了，讀數一直往同一邊，幾個讀數內就過門檻。
/// 只有睡著時用；醒著時重力照舊直接朝原始讀數靠，滾起來的手感不變。
struct JarCalm {
    /// 平滑過的重力目標；nil＝還沒開始看，下一個讀數從當時的重力起算
    private var smooth: (x: Double, y: Double)?

    mutating func forget() {
        smooth = nil
    }

    /// 睡著時每讀一次叫一次，x、y 是換成重力單位的讀數。回平滑後離睡著時的重力偏了多少。
    mutating func shift(x: Double, y: Double, gravityX: Double, gravityY: Double) -> Double {
        let from = smooth ?? (x: gravityX, y: gravityY)
        let pull = Tokens.Motion.restSmooth
        let next = (x: from.x + (x - from.x) * pull, y: from.y + (y - from.y) * pull)
        smooth = next
        return abs(next.x - gravityX) + abs(next.y - gravityY)
    }
}
