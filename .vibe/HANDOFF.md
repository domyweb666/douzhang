# HANDOFF（2026-11-17 深夜）：換核心 AG1–AG5 機器層做完、手機沒看過；白噪音還沒做；擋 app 做完沒打包

> 給下一個新會話的交接便條。先向多米摘要「上次做完什麼、卡在哪」，等他點頭再動工。
> 真相源：`.vibe/產品定稿.md` 最上面「2026-11-17 改版」、`.vibe/切片帳本.md`「進行中」最上面兩節（AG 換核心、螢幕使用時間 API 裡的 AF1）、`.vibe/規矩檔.md`、`.vibe/操作清單-待驗.md` 最上面兩節。
> 上一份便條（疊了三段補充的那份）備份在 `.vibe/handoff/archive/HANDOFF-2026-11-17-2350-replaced.md`。

## 一句話現況
番茄帳（`douzhang/`，Expo SDK 58／RN 0.88）分支 `uiux-graybox`，工作樹乾淨，**從 2182f9c 起的 commit 都沒推**。TestFlight 上還是 1.0.0 (3)，2026-11-17 做的全部不在裡面。jest 228 過 1 跳過、eslint 0 錯、prettier 過、`npx expo export --platform ios` 打包過。

## 2026-11-17 這一天發生的事（依序）
1. 白天：新 icon、體型 A、短休息與長休息、聚焦模式（翻牌時鐘）。手機上沒看過。
2. 晚上：計時中擋住其他 app（AF1）。多米選「自己寫原生模組」，`douzhang/modules/app-shield/`（Swift）。機器層做完，**Swift 沒編過、沒打包**。多米說「先不打包」。
3. 深夜：多米用過 build 3 後說原本的核心「接」（寫一句給下一顆的自己）沒說服他，拿 FocusPomo 當參考提了十一點。**決定換核心：種番茄＋時間帳本**。出比較頁 https://claude.ai/artifact/2DBVVuZ7JVUN34eNKFeLxw ，多米選 `1A 2C 3A 4A 5B 6A`。
4. 同一晚做完 AG1–AG5（存檔點 f32f8d0、3b9b0b6）：
   - AG1 標籤（原本的類型）與主畫面精簡：新安裝預設五個標籤；主畫面只剩標籤膠囊、大時間、開始鈕；拿掉「這顆要做」卡、第一次的輸入框、收工、掛葉子、估幾顆。
   - AG2 計時中藤上一顆番茄從青到紅、越來越大。
   - AG3 鈴響頁改成慶祝畫面，寫一句變選填。
   - AG4 番茄架：天／3 天／週／月，實心色塊，重疊並排（規則沿用 `E:\蒜日子`）。
   - AG5 分析：番茄架上方切「行事曆｜分析」，日／週／月。

## 還沒做完／待決定
- **AG6 白噪音還沒動工。** 多米選了 6A（計時畫面一顆鈕、半頁選雨／柴火／關與音量）。素材在 `E:\捏捏史萊姆\nienie-slime\ios\NieNie\Resources\amb-rain-bed.m4a`、`amb-fire-bed.m4a`（各 122 秒、CC0，授權紀錄在同專案 `.uiux/04-手感/素材授權紀錄.md`）；`bgm-lofi.caf` 來源不明不要用。**動工前要多米回一件事：鎖屏或切到別的 app 時要不要繼續播**（要的話得開背景音訊模式 `UIBackgroundModes: audio`，送審要說明用途；我的建議是要，不然螢幕一鎖就沒聲音）。沒有滑桿套件，音量打算做三段（小／中／大）。
- **AG1–AG5 的畫面在手機與模擬器上一次都沒開過。** 冒煙測試只證明畫得出來。這一輪沒有新的原生模組，**Expo Go 就能看**。驗收步驟 AG1–AG17 在 `.vibe/操作清單-待驗.md` 最上面。
- 多米還沒回：跟 FocusPomo 拉開的核心要不要定成「計時中的那一段」（產品定稿裡標了還沒點頭）。
- 代決清單十五條在切片帳本「AG 換核心」那節，三條特別請多米看的在驗收清單那節最下面（預設標籤、實心方塊的字色、換一段用 ‹ › 不是滑）。
- 擋 app（AF1）：多米有沒有在 App ID 勾 Family Controls (Distribution) 並 Save，**還是不知道**。說「打包」才推 tag `tf-4`（先推分支再推 tag）。第一次很可能紅在 Swift 編譯或簽章。驗收 AF1–AF12。
- 多米回報「類型改不了名字」：是 AB1（cb8705f 已修），build 3 沒有。注音鍵盤沒測過，下一個 build 或 Expo Go 請他確認（驗收清單 AG3）。
- 沒清的舊東西：`words.js` 的舊詞、`core/` 裡收工與估幾顆的函式與測試、`ReceiptSheets.js` 的 `WeekSheet`、黃金行為 1–109 裡作廢的條目沒逐條標。清單在切片帳本。

## 關鍵決策（定下來的，別再爭論）
- 核心是種番茄＋時間帳本；「接」降成選填筆記；收工流程拿掉；類型與「事・估幾顆」合成標籤。
- 狀態檔格式不動、不搬資料：舊欄位（`clue`、`tasks`、`taskId`、`closed`、`leaf`、`planted`、`settings.closeTime`）留在檔案裡不讀。程式裡標籤的欄位名還是 `types`。
- 不做：正計時、跟上一段比的箭頭與紅字、照抄別人 app 的版面、連續天數。
- 擋 app 用自己寫的原生模組，不裝 `react-native-device-activity`；到點要回番茄帳才解開。
- 只 commit，不推、不打包。要出 TestFlight build 先問多米。

## 下個會話最重要的檔案
- `.vibe/規矩檔.md` ← 動工前必讀
- `.vibe/產品定稿.md` ← 最上面的改版段
- `.vibe/切片帳本.md` ← 「AG 換核心」那節（切片、做到哪、代決、沒清的）
- `douzhang/screens/Home.js`、`Bell.js`、`Rack.js`；`douzhang/ui/TagSheets.js`、`GrowingTomato.js`、`Timeline.js`、`MonthGrid.js`、`Stats.js`；`douzhang/core/grow.js`、`calendar.js`、`stats.js`
- 白噪音要接的地方：`douzhang/App.js` 的 `useDouzhang`（照擋 app 那個 effect 的寫法：答案變了才叫）、`screens/Home.js` 的 `FocusChips`、`core/store.js` 的設定欄位、`ui/Jar.js`（現有的 expo-audio 用法）

## 下一步從哪繼續
1. 摘要一句：「換核心前五片做完沒驗、白噪音沒做、擋 app 沒打包。」問：白噪音要不要在鎖屏繼續播；要先用 Expo Go 驗前五片，還是先把白噪音做完。
2. 多米回報哪一步怪：從那一步修，修完跑測試、eslint、token-check，commit `[機器存檔點] 實測修正：…`，錯誤日誌記一條。同一個 bug 修兩次沒好就停下來量測，不要再推理。
3. 做白噪音：音檔複製到 `douzhang/assets/ambience/`，設定加欄位，寫進切片帳本再動工。

## 踩到、下一個會話要知道的
- 改檔腳本**不要**用 bash heredoc 跑 python（今天中了三次）。用 Write 把腳本寫到 scratchpad 再 `python 檔名`；同一個檔的多處修改全部比對完才寫入。
- pre-commit 會擋：測試檔裡的色碼（從 Tokens 拿）、eslint 錯誤。跑 eslint 要看總數那一行。
- 憲法 1 不准測試 import screens；`__tests__/screens.test.js` 是寫明理由的例外。
- eslint 開了 React Compiler 那組規則：render 時不能讀 ref。函式超過 80 行、複雜度超過 12 會警告。
- `npx expo export --platform ios --output-dir <scratchpad>` 可在 Windows 確認 JS 打包得過，抓不到原生問題。
- Team ID 不要寫進 repo。

## 怎麼跑
開發：`cd E:\豆帳\douzhang; npx expo start --tunnel`（多米手機走 4G 掃 QR）。測試：`npm test`。lint：`npx eslint .`。寫死檢查：在 `E:\豆帳` 跑 `node .vibe/hooks/token-check.js douzhang/<檔>`。
