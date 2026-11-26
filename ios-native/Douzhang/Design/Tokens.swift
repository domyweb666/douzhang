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
        static let digit = Color(domyLight: 0xF2F2F4, domyDark: 0xF2F2F4)
        static let dim = Color(domyLight: 0x8E8E93, domyDark: 0x8E8E93)
        static let pill = Color(domyLight: 0x2C2C2E, domyDark: 0x2C2C2E)
        /// 「結束」那顆比其他鈕暗一階
        static let pillDim = Color(domyLight: 0x1C1C1E, domyDark: 0x1C1C1E)
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

        /// 聚焦模式的大數字：大小跟著畫面寬，不跟系統字級放大，不然會撐出畫面
        static func zenDigit(_ size: CGFloat) -> Font {
            Font.system(size: size, weight: .heavy).monospacedDigit()
        }

        /// 上面那種數字一個有多寬（字級的幾成）：等寬，量一次就好
        static let zenDigitWidth: CGFloat = {
            let size: CGFloat = 100
            let font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .heavy)
            return NSAttributedString(string: "0", attributes: [.font: font]).size().width / size
        }()
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
        /// 靜止版點番茄，最亮的時候往白色靠多少
        static let tapGlow = 0.45
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
        static let weekDayWidth: CGFloat = 40
        static let dayDot: CGFloat = 6
        static let blockIcon: CGFloat = 16
        static let colorSwatch: CGFloat = 36
        static let selectRing: CGFloat = 2
        /// 刻度尺那頁的番茄；鈴響收據「今天」那排的小番茄（剛收的這顆也一樣大）
        static let celebrateTomato: CGFloat = 132
        static let celebrateDot: CGFloat = 26
        /// 進度環：最大直徑、多粗、全熟那顆佔環直徑幾成、環最多佔中間那塊高度幾成
        static let ringSize: CGFloat = 264
        static let ringStroke: CGFloat = 10
        static let ringTomato: CGFloat = 0.62
        static let ringRoom: CGFloat = 0.72
    }

    /// 番茄架：時間軸、月檢視、分析的尺寸。
    enum Rack {
        /// 一小時多高。3 天、週拉高才放得下字（跟著字級放大），沒番茄的鐘頭收成一條
        static let timelineHour: CGFloat = 64
        static let timelineHourTall: CGFloat = 108
        static let timelineHourFlat: CGFloat = 28
        static let timelineGutter: CGFloat = 52
        /// 一顆再短也至少這麼高，放得下一行字。3 天、週的跟 timelineHourTall 一起放大
        static let timelineBlockMin: CGFloat = 28
        static let timelineBlockMinThree: CGFloat = 26
        static let timelineBlockMinWeek: CGFloat = 24
        /// 3 天、週：下面有空就長到這麼高，放得下兩行字
        static let timelineRoomThree: CGFloat = 46
        static let timelineRoomWeek: CGFloat = 42
        /// 週檢視一行字多高（跟著字級放大）；3 天、週方塊的圓角
        static let timelineLineWeek: CGFloat = 17
        static let timelineRadius = DomyTokens.Radius.sm
        static let timelineRadiusWeek = Space.xs
        /// 天檢視：至少這麼高才多寫一行那句
        static let timelineNoteMin: CGFloat = 44
        static let timelineLaneGap: CGFloat = 2
        static let monthDot: CGFloat = 10
        static let monthWeek: CGFloat = 60
        static let monthWeekFlat: CGFloat = 30
        static let statsShare: CGFloat = 6
        static let statsName: CGFloat = 64
        /// 月檢視的葉子斜放的角度
        static let leafTilt = -30.0
        /// 作廢的虛線框
        static let voidStroke = StrokeStyle(lineWidth: DomyTokens.Size.hairline, dash: [4, 3])
    }

    /// 前四個是動作代號表（照《SwiftUI 蘋果風格手感指南》第四節）：畫面的動畫只准從這裡拿，
    /// 不准自己挑曲線、寫秒數（.swiftlint.yml 的 no_hardcoded_curve 會擋）。
    /// 每一格都寫明秒數：系統彈簧不寫就是 0.5 秒，按壓會慢到點得快時看不出縮了。
    enum Motion {
        /// 按壓可點的東西
        static let press = Animation.snappy(duration: DomyTokens.Motion.pressDuration)
        /// 資料變了：切換選項、加刪、展開收合、換檢視、數字換值
        static let change = Animation.snappy(duration: DomyTokens.Motion.transition)
        /// 換頁、浮層淡入淡出
        static let transition = Animation.smooth(duration: DomyTokens.Motion.transition)
        /// 完成的那一瞬間：熟了的那顆彈一下，從 celebrateFrom 這麼小彈出來
        static let celebrate = Animation.bouncy(duration: 0.5)
        static let celebrateFrom: CGFloat = 0.6
        /// 靜止版點番茄：那顆亮起來、淡回去各多久（秒）
        static let glowRise = DomyTokens.Motion.pressDuration
        static let glowFall = DomyTokens.Motion.transition
        static let pressScale = DomyTokens.Motion.pressScale
        /// 收下這顆 → 番茄掉進來：等多久才掉（秒）
        static let dropDelay = 0.18
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
        /// 換頁之後多久算停穩（秒）：感測器等停穩才開關；iOS 17 沒有捲動開始、結束的通知，也等這麼久
        static let pageSettle = 0.5
        /// 進度環從正上方開始走；每一拍（畫面時鐘刷新的間隔）之間用動畫補上
        static let ringStart = -90.0
        static let tick = Double(Params.tickMs) / Params.msPerSecond
        /// 時鐘該等速：進度環不用彈簧，一拍一拍直線補上
        static let ringSweep = Animation.linear(duration: tick)
    }

    enum Sound {
        /// 碰撞速度超過這個才出聲；兩聲最少隔這麼久；音量＝速度 ÷ hitVolDiv，最大 hitVolMax
        static let hitThreshold = 380.0
        static let hitGap = 0.09
        static let hitVolDiv = 5000.0
        static let hitVolMax = 0.1
        /// 「嗒」排隊排到比這一撞晚這麼久（秒）就不播：對不上畫面，比沒有更怪
        static let hitLate = 0.1
        /// 碰撞的輕震：剛過門檻震 hitTapMin，撞到 hitTapFull 這麼快震滿。音量撞到 500 就滿了，
        /// 跟著音量走每一下會幾乎一樣大；整疊掉回底、從上面掉到底大約是 1000 上下
        static let hitTapMin = 0.35
        static let hitTapFull = 1100.0
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

extension Tokens {
    /// 間距的用途名（多米 iOS 開發準則 3-46）。表上沒有的挑最接近的用途，拿不準選大一級。
    enum Layout {
        /// 安全區上緣到大標題頂端
        static let pageTop = Space.l * 2
        static let screenMargin = Space.screen
        /// 不同性質的兩塊：大標題到第一塊、一組卡到下一組的區塊標題
        static let section = Space.section
        /// 同一組的兄弟；item 是標籤和它自己的內容；tight 是黏在一起的一對
        static let group = Space.m
        static let item = Space.s
        static let tight = Space.xs
        static let cardPad = Space.card
        static let rowPadV = Space.m
        /// 最後一張卡到頁尾的總距離
        static let footerTop = DomyTokens.Space.s12
        /// 捲動內容底部讓出懸浮分頁列；安全區下緣另算
        static let bottomClear = Shape.tabClearance
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
