import Foundation

/// 循環滾輪：同一組值重複很多輪排成一長條，打開時停在中間那一輪，往上往下都滾得下去（90 下面接 1）。
/// 做法照蒜日子的 LoopWheelRules。純函式，畫面在 UI/LoopWheel.swift。
enum LoopWheelRules {
    /// 重複幾輪。往上、往下各有一半可以滾；UIPickerView 只建看得到的列，輪數多不會讓打開變慢
    static let laps = 10

    static func rowCount(_ count: Int) -> Int {
        count * laps
    }

    /// 中間那一輪裡、第 index 個值的那一列。
    static func middleRow(index: Int, count: Int) -> Int {
        (laps / 2) * count + index
    }

    /// 這一列上是第幾個值。
    static func index(ofRow row: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((row % count) + count) % count
    }

    /// 值從外面被改掉時，滾輪要轉到哪一列：離現在這一列最近的那個。快到長條的頭尾就回中間那一輪。
    static func nearestRow(toIndex target: Int, from row: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var delta = target - index(ofRow: row, count: count)
        if delta > count / 2 {
            delta -= count
        }
        if delta < -(count / 2) {
            delta += count
        }
        let next = row + delta
        guard next >= 0, next < rowCount(count) else {
            return middleRow(index: target, count: count)
        }
        return next
    }
}
