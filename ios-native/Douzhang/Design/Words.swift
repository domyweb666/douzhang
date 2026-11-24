import Foundation

/// 番茄帳 介面用詞。翻自 Expo 版 design/words.js；畫面上每一個字只准從這裡拿。
/// 要新詞先加進詞彙表再加這裡。按鈕名一律動詞帶對象。帶數字的句子在 WordsFormat.swift。
enum Words {
    static let appName = "番茄帳"

    // MARK: 核心

    static let start = "開始"
    static let keepThis = "收下這顆"
    static let keepAndRest = "收下，休息一下"
    static let rest = "休息"
    static let backFromRest = "回來了，開始下一顆"
    static let ripeTitle = "熟了，又收下一顆"
    static let today = "今天"
    static let noteTitle = "寫一句給自己"
    static let notePlaceholder = "這顆做了什麼、下次從哪接"

    // MARK: 中途

    static let quickNote = "記一筆"
    static let noteThought = "冒出念頭"
    static let notePing = "有人找"
    static let noteTitleThought = "冒出什麼念頭？"
    static let noteTitlePing = "誰找你、什麼事？"
    static let jotDown = "記下"
    static let tapNoteHint = "點一下畫面記一筆"
    static let endThis = "結束這顆"
    /// 計時中右上、聚焦模式、記一筆半頁右邊那顆：位子窄，讀屏念的是 endThis
    static let endShort = "結束"
    static let endTitle = "結束這顆？"
    static let endSubEarly = "開始不到五分鐘，停下來不會留下紀錄。"
    static let endSub = "作廢只記一筆，不扣任何東西。"
    static let doneEarly = "提早做完了"
    static let doneEarlySub = "剩下的時間小修，鈴響再停"
    static let doneEarlyLine = "剩下的時間，唸一遍、檢查、小修。鈴響再停。"
    static let stopNow = "停下來"
    static let voidThis = "作廢這顆"
    static let voidSub = "原因寫事實就好。"
    /// 第二個跟計時中記一筆的「有人找」同名：同一件事只有一個名字。以前叫「訊息」，見 WordsInsight
    static let voidReasons = ["念頭", "有人找", "卡住", "其他"]
    static let voidTextPlaceholder = "例：去看留言（分鐘數會自動記）"
    static let keepGoing = "繼續做"

    // MARK: 正在做什麼

    static let doing = "在做什麼"
    static let doingPlaceholder = "例：寫第三節"
    static let clearDoing = "清掉這句"

    // MARK: 聚焦模式

    static let zenEnter = "聚焦模式"
    /// 計時中下面那顆圓鈕：位子窄，讀屏念的是 zenEnter
    static let zenShort = "聚焦"
    static let zenLeave = "回主畫面"

    // MARK: 標籤

    static let taskType = "標籤"
    static let thisToDo = "這顆要做"
    static let presetTags = ["專注", "工作", "閱讀", "學習", "運動"]
    static let newTag = "＋ 新標籤"
    static let addType = "加一個標籤"
    static let deleteThisType = "刪除這個標籤"
    static let typeNameA11y = "標籤名字"
    static let lengthA11y = "長度"
    static let minuteUnit = "分"
    static let dialDone = "完成"
    static let dialHint = "點兩下改長度"
    static let newTypeName = "新標籤"
    static let unnamedType = "未命名"
    static let devTypeName = "測試"

    // MARK: 通知：文案固定，不含使用者寫的那句

    static let rang = "響了。"
    static let bellSub = "這顆熟了，回來收下。"
    static let restDone = "休息完了"
    static let autoNextStarted = "下一顆自己開始了。"
    static let notificationOffLine = "到點通知沒開。鈴只在番茄帳打開時響。"
    static let openNotifications = "打開通知"

    // MARK: 平實語氣的系統訊息：第一句先回答有沒有損失

    static let saveFailed = "這台裝置沒辦法存，記得匯出備份"
    static let importUnreadable = "這個檔案讀不懂，原本的資料沒動"

    // MARK: 分頁

    static let rack = "番茄架"
    static let home = "主畫面"
    static let settings = "設定"

    // MARK: 設定：節奏、提醒、手感

    static let rhythm = "節奏"
    static let restRow = "休息"
    static let restModeAuto = "到點提醒我"
    static let restModeSmart = "智能調節"
    static let restModeSelf = "我自己決定"
    static let restShortRow = "短休息"
    static let restShortAuto = "跟著長度"
    static let restLongRow = "長休息"
    static let restLongOff = "關"
    static let autoNextRow = "休息完自動開始下一顆"
    static let general = "一般"
    static let notifRow = "到點通知"
    static let notifOn = "開著"
    static let notifOff = "沒開"
    static let soundRow = "聲音"
    static let feel = "手感"
    static let tiltRow = "傾斜手機，番茄跟著滾"
    static let devSection = "開發"
    static let testModeRow = "測試模式"

    // MARK: 計時中擋住其他 app

    static let shieldSection = "專注"
    static let shieldRow = "計時中擋住其他 app"
    static let shieldAppsRow = "要擋的 app"
    static let shieldAppsNone = "還沒選"
    static let shieldDenied = "螢幕使用時間沒有允許，所以開不了。"

    // MARK: 備份與清空

    static let dataSection = "資料"
    static let exportBackup = "匯出備份"
    static let importBackup = "從備份匯入"
    static let importTooBig = "這個檔案太大，不像番茄帳的備份，原本的資料沒動"
    static let autoBackupFailed = "沒辦法先把現在的資料備份起來，這次不匯入，原本的資料沒動"
    static let exportFailed = "這次沒匯出成功，原本的資料沒動"
    static let backupsLeft = "資料清掉了，但自動備份檔沒刪乾淨，再按一次清空試試"
    static let importConfirm = "用備份覆蓋現在的資料？"
    static let importConfirmOk = "覆蓋現在的資料"
    static let cancel = "取消"
    static let wipeAll = "清空所有資料"
    static let wipeTitle = "清空所有番茄、番茄串和設定後就找不回來了"
    static let wipeExportFirst = "先匯出備份"
    static let wipeAgainTitle = "真的要清空？清了就拿不回來"
    static let wipeAgainOk = "永久清空"
    static let wipedLine = "全部清掉了。清掉的拿不回來，有匯出過的備份可以在設定匯入。"
    static let wipedAction = "去設定匯入"

    // MARK: 白噪音

    static let ambienceTitle = "背景音"
    static let ambienceVolumeCap = "音量"
    static let ambienceSub = "計時中才播，響了就停。鎖屏、切到別的 app 也會繼續播。"

    // MARK: 番茄架

    static let rackModeCalendar = "行事曆"
    static let rackModeStats = "分析"
    static let viewDay = "天"
    static let viewThree = "3 天"
    static let viewWeek = "週"
    static let viewMonth = "月"
    static let prevPeriod = "‹"
    static let nextPeriod = "›"
    static let prevPeriodA11y = "上一段"
    static let nextPeriodA11y = "下一段"
    /// 月檢視與長條圖下面那排，週一開頭
    static let weekdayShort = ["一", "二", "三", "四", "五", "六", "日"]
    static let statsEmpty = "這段時間還沒有番茄。"
    static let thisWeek = "這週"
    static let rackEmpty = "第一顆響完，這裡就會掛上今天的番茄串。"
    static let rackEmptyAction = "回去開始一顆"
    static let chevron = "›"
    static let check = "✓"
    static let confirm = "好"
    static let voidA11y = "作廢"
    static let leafA11y = "一片葉子"
    static let leafDay = "這天掛的是一片葉子。"
    static let noNoteMark = "沒留話"
    static let doublePea = "雙番茄"
    static let todayBeans = "今天的番茄"

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
