import Foundation

/// 番茄帳 非樣式數字。翻自 Expo 版 design/params.js；畫面與 Core 只准從這裡拿數字。
/// 只放已經有人用的：還沒搬過來的畫面要的數字，等那一片再加。
enum Params {
    static let msPerSecond = 1000.0
    static let secondsPerMinute = 60.0
    static let msPerMinute = secondsPerMinute * msPerSecond
    static let msPerHour = 60 * msPerMinute
    /// 一天從幾點開始算。0＝午夜（多米 2026-11-22 定：先維持午夜）。
    static let dayStartHour = 0.0

    /// 畫面時鐘多久刷新一次（毫秒）
    static let tickMs = 250
    /// 選填的那一句、記一筆一行、作廢原因那一行最多幾個字
    static let noteMaxChars = 120
    static let jotMaxChars = 60
    static let voidTextMaxChars = 40
    /// 鈴響後「再做一下」的兩個選項
    static let flowMinutes = [15, 30]
    /// 慶祝畫面「今天收了幾顆」那排最多畫幾顆（多的只畫最後這幾顆）
    static let celebrateTomatoes = 12
    /// 番茄堆：每秒不到這麼多幀、連續這麼多秒，就退成靜止版
    static let jarLowFps = 40
    static let jarLowFpsSeconds = 3
    /// 月檢視一格最多畫幾顆小圓點，再多寫「+N」
    static let monthDotsMax = 8
    /// 匯入檔大小上限 5 MB
    static let importMaxBytes = 5 * 1024 * 1024

    /// 標籤長度的刻度：5–90 分每 5 分一格
    static let typeLengths = Array(stride(from: 5.0, through: 90.0, by: 5.0))

    /// 新安裝的五個標籤的長度與番茄色；名字在 Words.presetTags，順序對齊
    static let presetLengths: [Double] = [25, 50, 30, 45, 10]
    static let presetColors: [TomatoColor] = [.red, .purple, .orange, .yellow, .pink]

    /// 計時中長大的番茄：一開始是全熟大小的幾成
    static let growMinScale = 0.4

    /// 「加一個標籤」新標籤的長度
    static let newTypeMinutes = 15.0
    /// 休息完自動開始：休息到點後先停在待機這麼久，讓剛收的那顆掉進番茄堆
    static let autoNextDelayMs = 2500.0
    /// 開發期測試顆與它的休息都是這麼久
    static let devTestSeconds = 5.0
    static let typeNameMaxChars = 20
    /// 開始不到這麼久就停，不留紀錄
    static let stopNoRecordMinutes = 5.0

    /// 短休息、長休息的刻度
    static let restShortOptions: [RestShort] = [
        .auto,
        .minutes(3),
        .minutes(5),
        .minutes(10),
        .minutes(15),
    ]
    /// 今天每收下幾顆來一次長休息；0＝關
    static let restLongEveryOptions = [0, 3, 4, 5]
    static let restLongMinuteOptions = [15, 20, 30]

    /// 白噪音音量三段各自的大小（0–1）
    static func ambienceVolume(_ level: AmbienceLevel) -> Double {
        switch level {
        case .low: 0.25
        case .mid: 0.5
        case .high: 0.85
        }
    }

    /// 聚焦模式：看重力落在哪一軸判斷直拿或橫放
    enum Zen {
        /// 重力有這麼多成落在同一軸才算直拿或橫放；斜拿、平放都不算
        static let ratio = 0.75
        /// 新姿勢要維持這麼久才換畫面
        static let dwellMs = 800.0
        /// 加速度計多久看一次
        static let sampleMs = 200.0
    }
}
