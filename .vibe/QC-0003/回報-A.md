# 包 A 回報（2026-11-24）：全部項目寫完，沒有 commit；本機編不了，沒有編譯、沒有上機

檢查：check_swift 0 問題；check_refs 只剩 `Tokens.ZenLayout.self`。

- 13：`UI/TagSheets` 拿掉 lengthNote；`Insights.lengthOutcome`、`Words.lengthLine` 與測試留著。
- 14：新檔 `Core/LoopWheelRules`、`UI/LoopWheel`、`LoopWheelTests`；`Params.typeLengths` 1...90；`SettingsLogic.nearestLen` 讓舊檔 12.5 分停在最近一格。蒜日子重複 20 輪，這裡 10 輪（900 列），少一半要排的列。
- 15：`RestMode.smart`、`Store.smartRest`、`Machine.restPlan`、`Params.SmartRest`；Notify 改成「不是 .own」；footer 全拿掉，公式在「休息」列右邊「專注 ÷ 5，每滿 100 分 +10」（最少 3 最多 30 沒寫出來）。新檔 `SmartRestTests`。
- 16 後半＋22：`doing` 四處欄位、讀寫、`Core/MachineDoing`、`UI/DoingSheet`、`DoingTests`。多一顆「清掉這句」；下滑關掉、響了自動收也算存。膠囊太長截那句，「・5 分」不截。
- 19：`NoteSheet` 第三顆「結束」走 `openEnd()`；`noteSub` 拿掉。
- 21：`FocusRing` 固定大小；`Grow.scale` 與測試刪掉；`growMinScale` 改名 `restTomatoScale`（只剩休息那顆小青番茄用）。
- 24：新檔 `UI/NotebookSheet`。沒用 TextEditor，改包 UITextView 把行高釘死：TextEditor 只能調行距，中文字會越寫越離開線。上限照舊 120 字。
- 25：休息頁三段字拿掉；讀屏仍念「休息／長休息＋時間」。
- 22 筆（點大時間）：新檔 `UI/MinuteRuler`、`Screens/TimeDialScreen`；多加左上「取消」與標籤名（整頁沒有下滑關閉，沒取消就出不去）。
- 包 B 轉來：`HomeIdle` 的 page 監看搬到 `IdleLineReset` 小 View。
- 新代號在 `Design/TokensPages.swift`；`.vibe/hooks/check_refs.py` 改成讀所有 Tokens 開頭的檔（一行）。

沒把握：
1. 刻度尺 `scrollPosition(id:anchor: .center)`＋`safeAreaPadding`：第一次打開會不會停對格，要模擬器看（iOS 17 與 18 都看）。
2. 筆記本：自動拿游標、注音組字中換行、線跟字有沒有對齊，要真機看；開著時切深淺色線的顏色不會跟著換。
3. `Color(Tokens)` 轉 `UIColor` 的深色是否跟著換。
4. 待機多一顆小鈕，大時間往下移 44pt 左右；版面等 16／17／18／23 選圖。

要主對話知道：聚焦模式那行（`FocusScreen.doingLine`）與鈴響頁標籤那行還是寫標籤名，單子沒說所以沒接 `doing`。
既有落差沒動：非智能模式鈴響頁的「收下後直接回待機」用番茄長度估，長休息或固定短休息時跟實際不一致。
詞彙表-暫定.md 沒補新詞（SwiftUI 版之後就沒人更新它）。
