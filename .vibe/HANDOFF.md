# HANDOFF（2026-11-17 深夜，11-18 補）：1.0.0 build 5 已上傳 TestFlight（含換核心六片、擋 app、白噪音）；11-18 又做完主畫面改版 AH1–AH8（不在 build 5 裡）；手機上一次都還沒驗

> **2026-11-18 補**：多米說「UI 很含糊」→ 核心動作卡重寫 v0.2（動詞「種」）→ 主畫面比較頁 https://claude.ai/artifact/C6T29GZoJzbgo6y6C4pU4W → 多米 13 點 → AH1–AH8 機器層做完（最後存檔 b8bf9da，沒推）。計時中與休息改成「番茄就是時鐘」、火柴人拿掉、聚焦模式加番茄、計時中鎖分頁、月檢視葉子、休息完自動開始（設定預設關）。jest 236 過 1 跳過、eslint 0 錯、expo export iOS 過。**Expo Go 就能看**，驗收 AH1–AH15 在 `.vibe/操作清單-待驗.md` 最上面；代決十條在切片帳本「AH 主畫面改版」那節。下一個會話先問多米要不要用 Expo Go 走一遍 AH1–AH15。

> 給下一個新會話的交接便條。先向多米摘要「上次做完什麼、卡在哪」，等他點頭再動工。
> 真相源：`.vibe/產品定稿.md` 最上面「2026-11-17 改版」、`.vibe/切片帳本.md`「進行中」最上面兩節（AG 換核心、螢幕使用時間 API 裡的 AF1）、`.vibe/規矩檔.md`、`.vibe/操作清單-待驗.md` 最上面兩節。
> 上一份便條（疊了三段補充的那份）備份在 `.vibe/handoff/archive/HANDOFF-2026-11-17-2350-replaced.md`。

## 一句話現況
番茄帳（`douzhang/`，Expo SDK 58／RN 0.88）分支 `uiux-graybox`，工作樹乾淨，分支已推到 97ce171。**TestFlight 上是 1.0.0 (5)**（tag `tf-5`，2026-11-17 深夜），2026-11-17 做的全部都在裡面。下一個 tag 是 `tf-6`。jest 238 過 1 跳過、eslint 0 錯、prettier 過、`npx expo export --platform ios` 打包過。

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
- **AG6 白噪音機器層做完（多米回「要，繼續播」），聲音一次都沒真的播過。** `core/ambience.js`、`ui/SoundSheet.js`、`app.json` 的 `UIBackgroundModes: audio`、音檔在 `douzhang/assets/ambience/`。沒驗到的：好不好聽、122 秒循環的接縫、鎖屏後有沒有繼續、到點會不會自己停。前景的部分 Expo Go 可以聽，背景以 TestFlight build 為準。驗收 AG18–AG25。
- 白噪音會改變擋 app 的行為（預期，沒驗）：在背景播的時候 app 醒著，到點那一刻擋板會自己解開。黃金 115 要等實測後改寫。
- 送審稿要補一句背景音訊的用途說明，還沒寫。
- **AG1–AG6 的畫面在手機與模擬器上一次都沒開過。** 冒煙測試只證明畫得出來。這一輪沒有新的原生模組，**Expo Go 就能看**。驗收步驟 AG1–AG25 在 `.vibe/操作清單-待驗.md` 最上面。
- 2026-11-18 多米選核心動詞「種」（計時中那一段），核心動作卡重寫成 v0.2（`.uiux/01-核心動作卡-暫定.md`）；成功的感覺先空著，主畫面比較頁已選（待機照現況、計時中與休息用 C），核心卡九條全部定案；多米「照覆誦做」，AH1–AH8 機器層做完（見最上面 11-18 補）。
- 代決清單十五條在切片帳本「AG 換核心」那節，三條特別請多米看的在驗收清單那節最下面（預設標籤、實心方塊的字色、換一段用 ‹ › 不是滑）。
- 擋 app（AF1）：`tf-5` 證明 Swift 編得過、Family Controls 簽得過（申請稿已補一筆）。授權框、選擇畫面、擋板在手機上還沒跑過。驗收 AF1–AF12。
- `tf-4` 紅過一次：`expo-screen-orientation` 58.0.4 比專案的 expo 58.0.22 新，釘回 58.0.3 才過。專案的 Expo 套件整體落後十一個補丁版，之後要升就一次升齊並把釘拿掉。
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
1. 摘要一句：「build 5 在 TestFlight 上，等你裝起來驗。」多米要先在 App Store Connect 把 build 5 加進測試群組才裝得到（`.vibe/TestFlight-打包步驟.md` 第 5、6 步）。驗收清單三節：AG1–AG25、AF1–AF12、白天四樣 AC／AD／AE／IC。
2. 多米回報哪一步怪：從那一步修，修完跑測試、eslint、token-check，commit `[機器存檔點] 實測修正：…`，錯誤日誌記一條。同一個 bug 修兩次沒好就停下來量測，不要再推理。
3. 還欠的：清舊東西（清單在切片帳本）、送審稿補背景音訊用途、黃金行為舊條目逐條標作廢。核心卡 v0.2 待多米逐條決定，之後出主畫面比較頁。

## 踩到、下一個會話要知道的
- 改檔腳本**不要**用 bash heredoc 跑 python（今天中了三次）。用 Write 把腳本寫到 scratchpad 再 `python 檔名`；同一個檔的多處修改全部比對完才寫入。
- pre-commit 會擋：測試檔裡的色碼（從 Tokens 拿）、eslint 錯誤。跑 eslint 要看總數那一行。
- 憲法 1 不准測試 import screens；`__tests__/screens.test.js` 是寫明理由的例外。
- eslint 開了 React Compiler 那組規則：render 時不能讀 ref。函式超過 80 行、複雜度超過 12 會警告。
- `npx expo export --platform ios --output-dir <scratchpad>` 可在 Windows 確認 JS 打包得過，抓不到原生問題。
- Team ID 不要寫進 repo。

## 怎麼跑
開發：`cd E:\豆帳\douzhang; npx expo start --tunnel`（多米手機走 4G 掃 QR）。測試：`npm test`。lint：`npx eslint .`。寫死檢查：在 `E:\豆帳` 跑 `node .vibe/hooks/token-check.js douzhang/<檔>`。
