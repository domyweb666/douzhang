# 包 T 回報（說明字拿掉＋鈴響 13 顆起寫總數，2026-11-24）：本機編不了，逐行讀過；沒有 git 動作

檢查：check_swift 問題數 0；check_refs 沒定義 0；check_words 0。全 app 掃過，`Words*` 以外沒有寫死的中文畫面字。

**改了**：`UI/FocusSheets`、`UI/SheetCard`、`UI/SoundSheet`、`UI/BellReceipt`、`Screens/HomeRings`、`Screens/HomeIdle`（只改一行註解）、`Design/Words`、`Design/WordsFormat`、`DouzhangTests/UsualRangeTests`（加一則）。
**刪乾淨**：`endSub`、`endSubEarly`、`doneEarlySub`、`doneEarlyLine`、`voidSub`、`ambienceSub`；`SheetCard.sub`、`SheetRow.sub` 兩個參數；`SoundSheet.caption` 函式。
**鈴響**：新純函式 `Words.todayTotal(_:)`（超過 `Params.celebrateTomatoes` 才有字，用本來沒人用的 `beansCount`）。第 13 顆起「今天」下面多一行「13 顆」，番茄那塊照舊；12 顆以內畫面不變。疊成兩行是為了不擠掉右邊番茄的寬，番茄本來就折兩行，那列不會變高。

## 盤點

### 拿掉（行號是 HEAD ea044e9）
| 檔:行 | 原文 | 為什麼 |
|---|---|---|
| UI/FocusSheets:110 | 開始不到五分鐘，停下來不會留下紀錄。／作廢只記一筆，不扣任何東西。 | 半頁副標 |
| UI/FocusSheets:112 | 剩下的時間小修，鈴響再停 | 列的副標 |
| UI/FocusSheets:135 | 原因寫事實就好。 | 半頁副標、教學句 |
| UI/FocusSheets:138 | 例：去看留言**（分鐘數會自動記）** | 只拿括號裡的說明，例子留 |
| UI/SoundSheet:30 | 計時中才播，響了就停。鎖屏、切到別的 app 也會繼續播。 | 常駐說明 |
| Screens/HomeRings:90 | 剩下的時間，唸一遍、檢查、小修。鈴響再停。 | 教學句。換成狀態「提早做完了」（現有的字）：整句拿掉的話，按了那一列畫面上什麼都沒變，看不出有沒有按到 |

### 留（行號是現在）
| 檔:行 | 原文 | 為什麼 |
|---|---|---|
| UI/BellReceipt:42 | 響了 N 分鐘前。收下後直接回待機。 | 只在很久才回來時出現，講的是結果。**後半句算說明，要不要拿請多米定**（按鈕那時已改成「收下這顆」） |
| UI/BellReceipt:149 | 你平常 4 到 6 顆 | 資料（規格點名留） |
| UI/BellReceipt:185 | 寫一句給自己 | 那顆鈕的名字，沒別的字 |
| UI/FocusSheets:36、138；UI/DoingSheet:17；UI/NotebookSheet:38 | 冒出什麼念頭？／誰找你、什麼事？／例：去看留言／例：寫第三節／這顆做了什麼、下次從哪接 | 輸入框淡字，打字就消失 |
| UI/SoundSheet:24 | 音量 | 控制項的名字，沒有它「小中大」看不懂 |
| Screens/HomeIdle:87 | 在做什麼 | 鈕的名字 |
| Screens/HomeIdle:130 | 這週第 N 顆因為念頭作廢。 | 資料（.analytics O-2 到 O-5） |
| UI/StatsPanel:29、36、82、87、90 | 這週時間花在哪／這週專注…收了 N 顆／這兩週記了什麼、作廢的原因／兩句計數 | `.analytics` D-1、D-3、D-5 到 D-7，標題與資料。分析頁沒有解釋句可拿 |
| UI/StatsPanel:31、84 | 這段時間還沒有番茄。／這兩週沒有記一筆，也沒有作廢。 | 空狀態 |
| Screens/RackScreen:79 | 第一顆響完，這裡就會掛上今天的番茄串。／全部清掉了。清掉的拿不回來，有匯出過的備份可以在設定匯入。 | 空狀態；剛清空的結果 |
| Screens/RackScreen:199；UI/MonthDoneList:20、81；UI/DayReceipt:46、92 | N 顆・多久／這個月做了什麼／這天掛的是一片葉子。／沒留話 | 資料、標題、空狀態、資料的標記 |
| UI/TagSheets:117；Screens/TimeDialScreen:54 | N 分／分 | 資料、單位 |
| Screens/RootView:40、43、63 | 讀不懂／存不了／到點通知沒開… | 出錯、權限狀態（檔是包 S 的，沒動） |
| HomeRings:96、HomeIdle:125、FocusScreen:28 | 點一下畫面記一筆／點兩下改長度／聚焦模式，剩… | 只給讀屏 |
| Core/Notify:19、31 | 這顆熟了，回來收下。／下一顆自己開始了。 | 通知內文，不在畫面上 |
| Words.restLines 18 句 | 收下了，這顆是完整的。… | 只存進資料，QC-0003 第 25 筆起畫面不顯示 |
| WordsInsight `lengthLine` | 25 分鐘，最近 N 顆… | 第 13 筆說函式與測試留，畫面沒用 |

### 設定頁（包 S 的範圍，沒動）
`SettingsRhythm:53`「專注 ÷ 5，每滿 100 分 +10」（右邊的值，多米那題定的）、`SettingsShield:16` 螢幕使用時間沒允許（權限）、`SettingsScreen:201` 自動備份時間（資料）、備份出錯與清空確認框：照準則都可以留。

## 自己決定
- 碰到的半頁間距換成 `Layout`：`m→group`、`s→item` 值一樣；結束半頁、背景音半頁原本的 `Space.l`（20）沒有對應的用途名，換成 `section`（24），多 4 點。
- `SheetCard` 內容與標題的 16 是設定頁的半頁也在用，沒動。
- `SheetRow.selected` 與 `Words.check` 本來就沒人傳，不是這次造成的，沒動。

## 沒做、要主對話決定（不在這包的檔）
- `.vibe/黃金行為.md` 26、28 與 `.vibe/標準清單.md:60`、`.vibe/操作清單-待驗.md:449-450` 還寫舊的副標與「剩下的時間，唸一遍…」，要改成「提早做完了」／沒有副標。
- `.uiux/05-設計代號/詞彙表-暫定.md` 60、61、62、65、190 行與 `.uiux/06-首次體驗-暫定.md` 98、111 行同上。
- `.analytics/07-圖表與文案.md` G-1 要補「第 13 顆起寫 N 顆」；`.analytics/03-紀錄時刻表.md:49` 寫作廢小字不用改；J-1（記一筆小字）之前就拿掉了，表上還在。
- `ios-native/scripts/make_users.py:310` 的標準答案寫「N 顆小番茄」：假使用者今天超過 12 顆才會不對，現在沒有這種人。

## 沒把握
- SwiftFormat 排版；字放到最大時「13 顆」比「今天」寬，番茄那塊剩約 120 點、一行四顆，要真機看。
- 包 S 若在新畫面用了 `SheetCard(title:sub:)` 會編不過（寫這份時 grep 沒有）。
