import Foundation

/// 番茄帳 介面用詞。翻自 Expo 版 design/words.js；畫面上每一個字只准從這裡拿。
/// 只放已經有人用的：還沒搬過來的畫面要的字，等那一片再加。
enum Words {
    static let appName = "番茄帳"

    /// 到點通知的標題與內文：文案固定，不含使用者寫的那句
    static let rang = "響了。"
    static let bellSub = "這顆熟了，回來收下。"
    static let restDone = "休息完了"
    static let backFromRest = "回來了，開始下一顆"
    static let autoNextStarted = "下一顆自己開始了。"

    static let devTypeName = "測試"
    static let newTypeName = "新標籤"
    static let unnamedType = "未命名"

    /// 新安裝的五個標籤，長度與顏色在 Params，順序對齊
    static let presetTags = ["專注", "工作", "閱讀", "學習", "運動"]

    /// 收下後那幾句，輪替、不連續重複。可愛的話只准由這裡說。
    static let restLines = [
        "收下了，這顆是完整的。",
        "番茄串上多一顆。",
        "響完了，起來喝口水。",
        "好，停在這裡剛剛好。",
        "一顆，沒有半顆。",
        "先離開螢幕五分鐘。",
        "去窗邊看一下遠的地方。",
        "番茄串又長一點了。",
        "站起來伸個懶腰吧。",
        "手機先別拿，走兩步。",
        "剛那段辛苦了。",
        "這顆長得挺飽滿。",
        "一段沒被打斷的，收進來。",
        "好，喝水時間。",
        "番茄上串了。",
        "先閉眼坐一下也行。",
        "這顆算數。",
        "去倒杯水，鈴響再回來。",
    ]
}
