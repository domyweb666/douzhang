import SwiftUI
import UIKit

/// 鎖定畫面與動態島的設計代號。擴充編不進 app 的 Tokens.swift（它連著整份資料型別），
/// 中性色、字級、間距直接用 Domy Design System（DomyTokens.swift 也編進擴充），跟 app 用的是同一組；
/// 番茄色由 app 從 Tokens.Tomato 抄進卡片（LiveCard.tint、leaf），這裡只把色碼變回顏色。
enum LiveTokens {
    // MARK: 顏色

    /// 卡片底：紙色，跟 app 的畫布（Tokens.Colors.background）同一個
    static let paper = DomyTokens.Canvas.warm
    /// 字：跟 Tokens.Colors.textPrimary 同一個
    static let text = DomyTokens.Neutral.textPrimary
    /// 開始鈕：膠囊，跟 Tokens.Colors.fillButton 同一個。番茄色只准畫番茄，不當按鈕色
    static let pill = DomyTokens.Neutral.surfaceMuted

    static func color(_ hex: UInt32) -> Color {
        Color(uiColor: UIColor(domyHex: hex))
    }

    // MARK: 字

    /// 標籤名那一行、靈動島縮起來時右邊的字
    static let small = DomyTokens.TypeScale.footnote.font.weight(.semibold)
    /// 倒數、熟了、休息中的大字：數字等寬，倒數時不左右晃
    static let big = DomyTokens.TypeScale.largeTitle.font.monospacedDigit()
    /// 今天幾顆、一顆多長那一行
    static let row = DomyTokens.TypeScale.subheadline.font.monospacedDigit()
    static let button = DomyTokens.TypeScale.headline.font
    /// 鎖定畫面只給 160 點高，字級放到這裡為止（照米說）
    static let largestType = DynamicTypeSize.accessibility2
    /// 字級開很大時寧可縮小，不要被切掉
    static let smallestScale = 0.6

    // MARK: 間距與尺寸

    static let pad = DomyTokens.Space.s4
    static let gap = DomyTokens.Space.s2
    static let tight = DomyTokens.Space.s1
    static let pillWide = DomyTokens.Space.s5
    static let pillTall = DomyTokens.Space.s2
    /// 標籤名前面、今天幾顆前面的小番茄
    static let tomatoSmall: CGFloat = 14
    /// 靈動島縮起來時左邊、最小那顆圓裡的番茄
    static let tomatoCompact: CGFloat = 18
    /// 蒂：番茄直徑的幾成寬、幾成高，往上凸出直徑的幾成
    static let stemWide: CGFloat = 0.4
    static let stemTall: CGFloat = 0.2
    static let stemLift: CGFloat = 0.08
}
