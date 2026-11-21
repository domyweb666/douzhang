import SwiftUI
import UIKit

/// 番茄帳 設計代號。畫面程式只准用這裡的代號，不准寫色碼、字級、間距、動畫數字。
/// 中性色、字級、間距、圓角來自 Domy Design System（DomyTokens.swift）；
/// 這個檔只留番茄帳自己才有的：茄紫產品色、番茄與葉子的角色色、大時間、各畫面的尺寸、動態。
/// 翻自 Expo 版 design/Tokens.js 與 design/theme.js，數值一個都沒動。
enum Tokens {
    enum Colors {
        static let background = DomyTokens.Canvas.warm
        static let card = DomyTokens.Neutral.surface
        static let textPrimary = DomyTokens.Neutral.textPrimary
        static let textSecondary = DomyTokens.Neutral.textSecondary
        static let textTertiary = DomyTokens.Neutral.textTertiary
        static let separator = DomyTokens.Neutral.separator
        static let fieldBorder = DomyTokens.Neutral.fieldBorder
        /// 第二顆按鈕、膠囊
        static let fillButton = DomyTokens.Neutral.surfaceMuted
        /// 主要按鈕底：每個畫面只出現一次。icon 背景的茄紫
        static let accent = Color(domyLight: 0x3B2547, domyDark: 0xD9C2E8)
        static let onAccent = Color(domyLight: 0xFFFFFF, domyDark: 0x2A1A33)
        /// 可點的強調文字、選中的字
        static let accentText = Color(domyLight: 0x4A2F5A, domyDark: 0xE3D0F0)
        /// 選中的分頁、選項膠囊、選中的那天
        static let soft = Color(domyLight: 0xECE3F1, domyDark: 0x3A2B45)
        static let danger = DomyTokens.Neutral.destructive
        static let disabledText = DomyTokens.Neutral.textDisabled
        /// 半頁後面的遮罩、懸浮分頁列的影子
        static let shadow = DomyTokens.Neutral.shadow
    }

    /// 聚焦模式：橫放的整頁時鐘，淺色深色都是同一組黑底。
    enum Zen {
        static let background = Color(domyLight: 0x000000, domyDark: 0x000000)
        static let card = Color(domyLight: 0x1C1C1E, domyDark: 0x1C1C1E)
        static let digit = Color(domyLight: 0xF2F2F4, domyDark: 0xF2F2F4)
        static let dim = Color(domyLight: 0x8E8E93, domyDark: 0x8E8E93)
        static let pill = Color(domyLight: 0x2C2C2E, domyDark: 0x2C2C2E)
    }

    /// 聚焦模式的版面：都是「佔畫面寬度的幾成」。四張牌加冒號大約佔 78% 寬；
    /// 時鐘縮成 clockScale 倍讓出位子給番茄，番茄的位子固定是全熟大小，長大時時鐘不會被推動。
    enum ZenLayout {
        static let cardWidth: CGFloat = 0.16
        static let cardHeight: CGFloat = 0.24
        static let digitSize: CGFloat = 0.19
        static let cardRadius: CGFloat = 0.024
        static let gap: CGFloat = 0.014
        static let colonDot: CGFloat = 0.018
        static let colonGap: CGFloat = 0.03
        /// 時鐘跟下面那句的距離
        static let lineGap: CGFloat = 0.026
        static let clockScale: CGFloat = 0.78
        static let tomato: CGFloat = 0.17
        static let tomatoGap: CGFloat = 0.03
        /// 點一下畫面，底下三顆鈕出現這麼久（秒）
        static let controlsSeconds = 3
    }

    /// 文字：Domy 的字級（iOS 系統文字樣式），跟著系統字級縮放。
    enum Fonts {
        static let largeTitle = DomyTokens.TypeScale.largeTitle.font
        static let title = DomyTokens.TypeScale.title1.font
        static let section = DomyTokens.TypeScale.title2.font
        static let title3 = DomyTokens.TypeScale.title3.font
        static let body = DomyTokens.TypeScale.body.font
        static let bodyStrong = DomyTokens.TypeScale.headline.font
        static let sub = DomyTokens.TypeScale.subheadline.font
        static let chip = Font.system(.subheadline).weight(.semibold)
        static let caption = DomyTokens.TypeScale.footnote.font
        static let tab = DomyTokens.TypeScale.caption.font
        static let button = DomyTokens.TypeScale.headline.font

        /// 大時間是番茄帳自己的。數字等寬；跟著系統字級放大，但有上限，不然會撐出畫面。
        private static func clock(_ size: CGFloat, cap: CGFloat) -> Font {
            let scaled = min(UIFontMetrics.default.scaledValue(for: size), size * cap)
            return Font.system(size: scaled, weight: .bold).monospacedDigit()
        }

        /// 待機的大時間
        static var clockFocus: Font {
            clock(72, cap: 1.6)
        }

        /// 進度環下面的時間：環已經是主角，比待機的小一階
        static var clockRing: Font {
            clock(56, cap: 1.4)
        }

        /// 聚焦模式牌上的數字：大小跟著畫面寬，不跟系統字級放大，不然會撐出牌子
        static func zenDigit(_ size: CGFloat) -> Font {
            Font.system(size: size, weight: .heavy).monospacedDigit()
        }
    }

    /// 間距：Domy 的刻度 4／8／12／16／20／24／32。
    enum Space {
        static let xs = DomyTokens.Space.s1
        static let s = DomyTokens.Space.s2
        static let m = DomyTokens.Space.s3
        static let card = DomyTokens.Space.s4
        static let l = DomyTokens.Space.s5
        static let section = DomyTokens.Space.s6
        static let xl = DomyTokens.Space.s8
        static let screen = DomyTokens.Size.screenMargin
    }

    enum Opacity {
        static let pressed = DomyTokens.Motion.pressedOpacity
        /// 番茄左上那道亮面與兩頰
        static let tomatoShine = 0.6
        static let tomatoCheek = 0.3
    }

    enum Shape {
        static let radiusCard = DomyTokens.Radius.xl
        static let radiusButton = DomyTokens.Radius.md
        static let radiusSheet = DomyTokens.Radius.xxl
        static let tapMin = DomyTokens.Size.touch
        static let tapPrimary = DomyTokens.Size.button
        static let buttonCompact = DomyTokens.Size.buttonCompact
        static let row = DomyTokens.Size.row
        static let field = DomyTokens.Size.field
        static let hairline = DomyTokens.Size.hairline
        static let tabBar = DomyTokens.Size.tabBar
        static let tabBarWidth = DomyTokens.Size.tabBarWidth
        static let tabBarBottom = DomyTokens.Size.tabBarBottom
        static let tabIcon: CGFloat = 24
        /// 有懸浮分頁列的畫面，內容底部要留這麼多空間，最後一筆才不會被蓋住
        static let tabClearance = tabBarBottom + tabBar + DomyTokens.Space.s4
        static let tabShadow = DomyTokens.Elevation.level2
        static let tabIconLine: CGFloat = 2
        /// 番茄串上的小圓點
        static let podDot: CGFloat = 12
        /// 收據半頁可捲區最高
        static let sheetScrollMax: CGFloat = 420
        /// 主畫面開始鈕下面留給番茄堆的高度
        static let pileRoom: CGFloat = 140
        static let weekDayWidth: CGFloat = 40
        static let dayDot: CGFloat = 6
        static let blockIcon: CGFloat = 16
        static let colorSwatch: CGFloat = 36
        static let selectRing: CGFloat = 2
        static let zenSeam: CGFloat = 2
        /// 慶祝畫面那顆、「今天收了幾顆」那排的小番茄、那排最後剛收的這顆
        static let celebrateTomato: CGFloat = 132
        static let celebrateDot: CGFloat = 26
        static let celebrateDotNew: CGFloat = 34
        /// 進度環：最大直徑、多粗、全熟那顆佔環直徑幾成、環最多佔中間那塊高度幾成
        static let ringSize: CGFloat = 264
        static let ringStroke: CGFloat = 10
        static let ringTomato: CGFloat = 0.62
        static let ringRoom: CGFloat = 0.72
    }

    /// 番茄架：時間軸、月檢視、分析的尺寸。
    enum Rack {
        static let timelineHour: CGFloat = 64
        static let timelineGutter: CGFloat = 52
        /// 一顆再短也至少這麼高，字才放得下；週檢視沒有字，最矮畫這麼高
        static let timelineBlockMin: CGFloat = 28
        static let timelineBlockMinWeek: CGFloat = 8
        /// 方塊不到這麼高就不寫字；至少這麼高才多寫一行那句
        static let timelineTextMin: CGFloat = 18
        static let timelineNoteMin: CGFloat = 44
        static let timelineLaneGap: CGFloat = 2
        static let nowLine: CGFloat = 2
        static let monthDot: CGFloat = 10
        static let monthWeek: CGFloat = 60
        static let monthWeekFlat: CGFloat = 30
        static let statsBars: CGFloat = 112
        static let statsShare: CGFloat = 6
        static let statsName: CGFloat = 64
        /// 月檢視的葉子斜放的角度
        static let leafTilt = -30.0
        /// 作廢的虛線框
        static let voidStroke = StrokeStyle(lineWidth: DomyTokens.Size.hairline, dash: [4, 3])
    }

    /// 前四個是動作代號表（照《SwiftUI 蘋果風格手感指南》第四節）：畫面的動畫只准從這裡拿，
    /// 不准自己挑曲線、寫秒數（.swiftlint.yml 的 no_hardcoded_curve 會擋）。
    enum Motion {
        /// 按壓可點的東西
        static let press: Animation = .snappy
        /// 資料變了：切換選項、加刪、展開收合、換檢視、數字換值
        static let change: Animation = .snappy
        /// 換頁、浮層淡入淡出
        static let transition: Animation = .smooth
        /// 完成的那一瞬間：熟了的那顆彈一下，從 celebrateFrom 這麼小彈出來
        static let celebrate: Animation = .bouncy
        static let celebrateFrom: CGFloat = 0.6
        static let pressScale = DomyTokens.Motion.pressScale
        /// 收下這顆 → 番茄掉進來：等多久才掉（秒）、往上的初速、左右散開多少
        static let dropDelay = 0.18
        static let dropVelY = -160.0
        static let dropVelXSpread = 40.0
        /// 傾斜：重力乘多少、每一幀往新方向靠多少、每幀分幾個子步、一幀最長算多久
        static let tiltScale = 115.0
        /// 加速度計給的單位是 g：乘上每個 g 多少 m/s² 再乘 tiltScale
        static let tiltPerG = 9.80665 * tiltScale
        /// 睡著時，重力要偏掉這麼多才醒來（大約傾斜一兩度）
        static let tiltWake = 25.0
        /// 每顆一幀移動不到這麼多（pt、弧度）、連續這麼多幀，就當作都躺好了
        static let quietDistance = 0.5
        static let quietAngle = 0.01
        static let quietFrames = 30
        static let tiltSmooth = 0.15
        static let substeps = 2
        static let frameMax = 0.033
        /// 進度環從正上方開始走；每一拍（畫面時鐘刷新的間隔）之間用動畫補上
        static let ringStart = -90.0
        static let tick = Double(Params.tickMs) / Params.msPerSecond
        /// 時鐘該等速：進度環不用彈簧，一拍一拍直線補上
        static let ringSweep = Animation.linear(duration: tick)
        /// 聚焦模式翻牌：牌先往後倒、換數字、再立回來，各這麼久
        static let zenFlipHalf = 0.15
        static let zenFlipFold = -88.0
        static let zenFlip = Animation.snappy(duration: zenFlipHalf)
    }

    enum Sound {
        /// 碰撞速度超過這個才出聲；兩聲最少隔這麼久；音量＝速度 ÷ hitVolDiv，最大 hitVolMax
        static let hitThreshold = 380.0
        static let hitGap = 0.09
        static let hitVolDiv = 5000.0
        static let hitVolMax = 0.1
    }

    /// 角色色：只准畫番茄、番茄串、葉子；不當文字色、不當按鈕色。淺深色同一組。
    enum Tomato {
        static let unripe = RGB(hex: 0x9CC25A)
        static let vine = RGB(hex: 0x4E8B3A)
        static let leaf = RGB(hex: 0x6FAE52)
        static let ink = RGB(hex: 0x2B2329)
        static let shine = RGB(hex: 0xFFFFFF)
        /// 番茄串的小圓點、作廢空心圈的框、月檢視的葉子
        static let pod = Color(domyLight: 0xE5553C, domyDark: 0xD94C34)
        static let podShade = Color(domyLight: 0xB83A26, domyDark: 0xF07A62)
        static let leafSoft = Color(domyLight: 0xBFE0A3, domyDark: 0x7FA86A)

        static func body(_ color: TomatoColor) -> RGB {
            switch color {
            case .red: RGB(hex: 0xE4472F)
            case .orange: RGB(hex: 0xF0892B)
            case .yellow: RGB(hex: 0xF2BC2F)
            case .purple: RGB(hex: 0x8C5BA9)
            case .pink: RGB(hex: 0xEE7E9D)
            }
        }

        /// 番茄架實心方塊上的字：紅、紫底用白字，橘、黃、粉底用墨色。
        static func onBody(_ color: TomatoColor) -> RGB {
            switch color {
            case .red, .purple: shine
            case .orange, .yellow, .pink: ink
            }
        }
    }
}

extension RGB {
    /// 0xRRGGBB → 三個 0–1 的分量。
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}
