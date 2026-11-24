# 包 C 回報（2026-11-24，程式寫完、沒 commit、沒編過）

檢查：`check_swift.py` 0 問題；`check_refs.py` 剩 `Tokens.ZenLayout.self`（誤報）與 `Params.growMinScale`（包 A 做到一半，不是我的）。

- **10、26 黑線拿掉**：`RackTimeline`（`nowLine`、`now`、`todayKey`）、`Tokens.Rack.nowLine`、`AppModel.minuteNow`／`minuteOf`、`RackCalendar.hourOfDay` 與它的測試、`.vibe/產品定稿.md` 那一句。
- **27 月檢視清單**：新檔 `Core/MonthDone.swift`（純函式）、`UI/MonthDoneList.swift`（`RackMonth`、`DoneCard`）、`DouzhangTests/MonthDoneTests.swift`（12 個測試）；字在 `WordsFormat`（`doneTitle`、`doneNames`、`weekdayCompact`、`doneA11y`），`Params.monthDoneNames`、`Tokens.Rack.doneBlock`。`RackScreen` 月檢視改用 `RackMonth`，點卡片開 `DaySheet`，點格子照舊。
- **doing 當主字**：`Receipt.workName`；`TimelineItem`／`ReceiptRow` 加 `doing`；`RackTimeline` 方塊、`DayReceipt` 那列（doing 當主字、那句退到下一行）；`Words.voidLine` 多一個有預設值的 `doing`，作廢寫成「寫稿・作廢，第 7 分鐘…」。
- **設定頁**：順序＝標籤、節奏、專注、手感、（開發）、一般（通知、聲音）、資料（匯出、匯入、清空）。常駐說明全拿掉，對應的字也刪了；`SettingsSection.footer` 留給出錯用（現在只有螢幕使用時間沒允許那一行）。清空問兩次：「先匯出備份／清空所有資料／取消」→「永久清空／取消」。
- **間距**：改到的畫面全換 `Tokens.Layout`；大標題到第一塊 24：設定、番茄架行事曆、分析（`StatsPanel` 最上面那行）。空狀態置中，只補底距。

自己決定的：
1. 清單名字分鐘多的在前（一樣多照先做的）；只有作廢的日子不列；翻到去年也只寫「11月做了什麼」（年份上面那排有）。
2. 「N 顆・多久」跟主字同一列，那句在下面用整列寬；無障礙大字時改上下兩行，日期塊的字放大有上限。
3. 3 天檢視與並排的窄方塊也用 doing（單子只寫天檢視），不然同一顆兩個檢視叫不同名字。
4. 番茄架的底距從整頁移進捲動內容：清單捲到分頁列底下，不會在分頁列上緣被切一刀（跟設定頁一樣）。
5. 還沒問過通知時「到點通知」整列不出現（3-4 值空的列不出現）。匯出列右邊寫「自動備份 11月22日」，不帶時刻（放不下）。

沒把握的：第一次 alert 的按鈕裡直接開第二個 alert、或開分享選單（SwiftUI 常用寫法，但沒跑過）；`.contentMargins(.bottom, _, for: .scrollContent)` 包在橫向分頁裡的底距；swiftformat 沒跑。版面看截圖 10-rack-month、12-settings。
順手要改但不是我的：`.vibe/操作清單-待驗.md` 第 4 列與 AG12 還在驗「現在」那條線；`.vibe/黃金行為.md` 61、62 的清空確認字與「上次自動備份」；`.uiux` 詞彙表沒加新詞。
等多米決定（3-3 有、番茄帳現在沒有，這次沒加）：外觀、觸覺回饋、iCloud 同步、匯入先講新增幾筆、完整版與恢復購買、意見回饋、評分、分享給朋友、新功能、家族其他 app、隱私權政策、使用條款、開源授權、頁尾（圖示、版本、Made by DOMYWEB）、每列圖示、接 VeggieKit。
