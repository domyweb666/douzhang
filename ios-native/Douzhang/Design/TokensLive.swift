import SwiftUI

/// 鎖定畫面與動態島那一張的尺寸（AI27 比較頁 1A、4A；Tokens.swift 快滿 300 行，另外放）。
extension Tokens {
    enum Live {
        /// 鎖定畫面的環；四邊留白、環跟字隔多遠（系統建議 14）
        static let ring: CGFloat = 72
        static let pad: CGFloat = 14
        /// 動態島：展開、收合的環
        static let islandRing: CGFloat = 62
        static let compactRing: CGFloat = 28
        /// 展開的時間離島上緣
        static let islandTop: CGFloat = 6
        /// 底是系統的玻璃，蓋上去的顏色透一點
        static let tint = 0.8
        /// 字放不下時最多縮到幾成
        static let shrink: CGFloat = 0.6
    }
}
