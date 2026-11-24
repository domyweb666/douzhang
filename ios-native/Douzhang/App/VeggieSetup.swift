import SwiftUI
import VeggieKit

/// 蔬菜家族共用元件（VeggieKit）在番茄帳的那一份設定。
/// 番茄帳在家族裡的代號、信箱、網址都在這裡；設定頁各區從這裡拿。
extension VeggieConfig {
    static let douzhang = VeggieConfig(
        name: Words.appName,
        slug: "fanqiezhang",
        tagline: "種番茄，記下每天做了什麼",
        // 還沒有 Apple ID：填了「在 App Store 給我們評分」才出現，分享的字也會換成下載連結
        appStoreID: nil,
        supportEmail: "charlie@domyweb.org",
        // 網頁還沒有：填了「隱私權政策」那列才出現，要跟 App Store Connect 填的同一頁
        privacyURL: nil
    )
}

extension VeggieStyle {
    /// 共用元件照番茄帳的代號畫
    static let douzhang = VeggieStyle(
        textPrimary: Tokens.Colors.textPrimary,
        textSecondary: Tokens.Colors.textSecondary,
        textTertiary: Tokens.Colors.textTertiary,
        accent: Tokens.Colors.accent,
        destructive: Tokens.Colors.danger,
        canvas: Tokens.Colors.background,
        surface: Tokens.Colors.card,
        body: Tokens.Fonts.body,
        headline: Tokens.Fonts.bodyStrong,
        subheadline: Tokens.Fonts.sub,
        footnote: Tokens.Fonts.caption,
        rowHeight: Tokens.Shape.row
    )
}
