import SwiftUI

/// 單獨一頁的尺寸（Tokens.swift 快滿 300 行，另外放）：長度的刻度尺、主畫面、筆記本、聚焦模式、完整版、鈴響頁。
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

    /// 主畫面待機與計時中：開始鈕、圓鈕。
    enum Home {
        static let start = DomyTokens.Size.heroButton
        static let round = DomyTokens.Size.button
        /// 標籤圓鈕裡那顆番茄；計時中那排圓鈕一欄多寬
        static let roundTomato: CGFloat = 34
        static let roundColumn: CGFloat = 80
        /// 那句旁邊的筆、大時間旁邊的箭頭
        static let sideIcon: CGFloat = 20
        /// 開始鈕下緣到讓出分頁列那條線之間，留給番茄堆
        static let pileRoom: CGFloat = 84
        /// 大時間、開始鈕的字放不下時最多縮到幾成
        static let shrink: CGFloat = 0.5
    }

    /// 設定頁：標籤列那顆番茄，跟其他列的圖示一樣寬（VeggieKit 的 24）。
    enum SettingsPage {
        static let icon: CGFloat = 24
    }

    /// 筆記本：一行多高（跟著系統字級放大）。
    enum Notebook {
        static let line: CGFloat = 36
    }

    /// 聚焦模式：兩個大數字中間一顆番茄。字級與番茄是「佔整個畫面寬的幾成」，番茄有上限。
    enum ZenLayout {
        static let digit: CGFloat = 0.252
        static let tomato: CGFloat = 0.17
        static let tomatoMax: CGFloat = 148
        /// 數字那一列多高（字級的幾成）：系統的行高上下太空
        static let digitRow: CGFloat = 0.91
        /// 點一下畫面，底下的鈕出現這麼久（秒）
        static let controlsSeconds = 3
    }

    /// 完整版那一頁：聚焦預覽的高佔它寬的幾成；矮手機（SE）另一組，才放得下四樣。
    enum Full {
        static let preview: CGFloat = 0.5
        static let previewShort: CGFloat = 0.4
        /// 扣掉安全區，比這個矮就算矮手機
        static let shortPage: CGFloat = 700
        /// 主按鈕的字放不下時最多縮到幾成
        static let shrink: CGFloat = 0.5
    }

    /// 鈴響頁：那張收據與下面的鈕。
    enum Bell {
        static let receiptWidth: CGFloat = 312
        static let tomato: CGFloat = 124
        /// 收據下緣一個鋸齒的高，也是它一半的寬
        static let tooth: CGFloat = 12
        static let dash = StrokeStyle(lineWidth: DomyTokens.Size.hairline, dash: [4, 3])
        /// 寫給自己那句一行多高（跟著系統字級放大）
        static let line: CGFloat = 32
        static let buttonWidth: CGFloat = 264
        /// 字放不下時最多縮到幾成
        static let shrink: CGFloat = 0.5
    }
}
