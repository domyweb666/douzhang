import SwiftUI

/// 單獨一頁的尺寸（Tokens.swift 快滿 300 行，另外放）：長度的刻度尺、筆記本。
extension Tokens {
    /// 刻度尺：一分鐘一格，線從下往上長，數字在線上面。
    enum Dial {
        static let slot: CGFloat = 12
        static let label: CGFloat = 20
        static let tickShort: CGFloat = 16
        static let tickLong: CGFloat = 28
        static let tickOn: CGFloat = 40
        static let tickWidth: CGFloat = 2
        static let tickWidthOn: CGFloat = 4
        static let height = label + Layout.item + tickOn
        static let pointerWidth: CGFloat = 16
        static let pointerHeight: CGFloat = 10
        static let doneWidth = DomyTokens.Size.heroButton
    }

    /// 筆記本：一行多高（跟著系統字級放大）。
    enum Notebook {
        static let line: CGFloat = 36
    }
}
