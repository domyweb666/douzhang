# HANDOFF（2026-11-17 晚更新）：擋 app（AF1）機器層做完，Swift 沒編過、手機沒跑過；下一步是多米說打包才出 TestFlight build

## 2026-11-17 深夜：多米決定換核心，比較頁等他選（最新，先看這段）
- 多米用過 build 3 後說「接」沒說服他，拿 FocusPomo 當參考提了十一點。決定：核心換成「種番茄＋時間帳本」。產品定稿最上面已改。
- 比較頁 https://claude.ai/artifact/2DBVVuZ7JVUN34eNKFeLxw （原始檔 `.uiux/03-線框/2026-11-17-改版比較頁.html`），五題，我建議 1A 2C 3B 4A 5B。**多米還沒選，程式一行都沒動。**
- 多米選完：先覆誦資料怎麼搬與切片，再動工。細節在切片帳本「AG 換核心」那節。
- 他回報改不了類型名字：是 AB1（cb8705f 已修），build 3 沒有；注音鍵盤沒測過，下一個 build 請他確認。
- 擋 app（AF1）維持下面那段的狀態：機器層做完、沒打包。多米說「先不打包」。

## 2026-11-17 晚的更新（以這段為準，下面 18:46 那份裡「擋 app 還沒動工」「先確認四件事」都已經過時）
- 多米選「甲，自己寫模組」：沒裝 `react-native-device-activity`，自己寫了 `douzhang/modules/app-shield/`（Swift 約 130 行）。沒有 App Group、沒有擴充、沒有新套件。
- 做完的：原生模組、`core/shield.js`、設定頁「專注」一區兩列、`App.js` 一個 effect 管蓋上與解開、`app.json` 加簽章權限、測試 186 過 1 跳過、eslint 0 錯、prettier 過、expo export 過。細節、代決清單九條在 `.vibe/切片帳本.md`「AF1」那節。
- **沒驗到的**：Swift 這台不能編；簽章沒試過；授權框、選擇畫面、擋板一次都沒跑過。只有 TestFlight build 在手機上能驗（黃金 110–120，驗收清單 AF1–AF12 在 `.vibe/操作清單-待驗.md` 最上面）。
- **還不知道**：多米有沒有在 App ID 那頁勾 Family Controls (Distribution) 並按 Save。打包前要問。
- 下一步：多米說「打包」才推 tag `tf-4`（先推分支再推 tag；今天的 commit 從 2182f9c 起都沒推）。第一次很可能紅在 Swift 編譯或簽章：看 Actions 紀錄修到綠，簽章過了去 `.vibe/FamilyControls-申請稿.md` 補一筆。封存用的是開發憑證，如果報缺 Family Controls (Development)，請多米在 App ID 那頁把 Development 那個也勾起來。
- 今天四樣（icon、體型、休息設定、聚焦模式）還是沒在手機上看過，同一個 build 可以一起驗。

---
以下是 18:46 的原文：

> 給下一個新會話的交接便條。先向多米摘要「上次做完什麼、卡在哪」，等他點頭再動工。
> 真相源：`.vibe/切片帳本.md`「進行中」最上面三節（2026-11-17 的四樣、螢幕使用時間 API）、`.vibe/規矩檔.md`、`.vibe/操作清單-待驗.md` 最上面那節、`.vibe/FamilyControls-申請稿.md`。
> 上一份 HANDOFF 是 11-01 的，中間 U～AB 各輪沒更新過便條，那段歷史看帳本。

## 一句話現況
番茄帳（原豆帳，`douzhang/`，Expo SDK 58／RN 0.88）分支 `uiux-graybox`，工作樹乾淨，**今天的 commit 都沒推**（從 2182f9c 起）。TestFlight 上是 1.0.0 (3)，今天做的都不在裡面。jest 176 過 1 跳過、eslint 0 錯、prettier 過、`npx expo export --platform ios` 打包過。

## 這次完成了什麼（2026-11-17）
- 出比較頁（https://claude.ai/artifact/6QWSeuPSno9rypGYqZpH1q），多米選：體型 A、聚焦 A、設定 A、強制接管用螢幕使用時間 API。
- 新 icon：`douzhang/assets/icon.png` 換成多米給的番茄鬧鐘，原始檔 `assets/icon.svg`（2182f9c）。
- AC1 體型 A：番茄大小上下限 0.7–1.75 倍 → 0.5–1.9 倍（3874e36）。
- AD1 設定 A：節奏區多「短休息」「長休息」兩列；`store.restAfter` 依那天第幾顆算短或長（3874e36）。
- AE1 聚焦模式 A：計時中按鈕或橫放手機，整頁轉橫向翻牌時鐘（a4bfaea）。新檔 `screens/Focus.js`、`core/posture.js`；新套件 `expo-screen-orientation`、`expo-keep-awake`；`app.json` 的 orientation 改 default。
- 帳本、黃金行為 98–109、驗收清單、詞彙表、錯誤日誌兩條都補了（33e1511）。
- Family Controls 權限：多米按了 Apple 的「Get Entitlement」。表單已改版成整個帳號按一次，沒有 bundle ID 與用途說明。多米截圖 `org.domyweb.douzhang` 的 Capabilities，「Family Controls (Distribution)」已在清單裡、可以勾。

## 還沒做完／待決定
- **今天四樣（icon、體型、休息設定、聚焦模式）在手機與模擬器上一次都沒開過。** 驗收步驟在 `.vibe/操作清單-待驗.md` 最上面（AC1–AC2、AD1–AD6、AE1–AE12、IC1）。Expo Go 能看聚焦模式；icon 要新 build。橫放偵測只有真機能看。
- 三個要多米決定的（清單那節最下面）：長休息預設開還是關（現在開，每 4 顆・15 分）；新 icon 深藍綠配紅、app 內還是茄紫，要不要動配色；橫放自動進聚焦要不要加開關。
- 多米有沒有在 App ID 那頁勾「Family Controls (Distribution)」並按 Save：**不知道**，最後一次是我請他勾，他接著說要開新對話。開場先問。
- 權限是不是真的生效：只看到清單可勾，沒有用 build 驗過簽章。
- 「計時中擋住其他 app」：只查了做法，一行程式都沒寫。

## 關鍵決策（定下來的，別再爭論）
- 體型 A、聚焦 A（翻牌）、設定 A（長度留在類型，不做全域番茄長度）。
- 強制接管走螢幕使用時間 API，不做「離開 app 就作廢」，引導使用模式的教學半頁也不做了。
- 擋 app 第一版的方向（多米看過建議、沒反對，但也沒逐條點頭，動工前覆誦一次）：設定加一列開關與選 app 的入口，預設關；開始一顆時蓋擋板；到點回到番茄帳、或結束／作廢時解開；擋板用系統預設的樣子；先只用主 app、不加擴充。
- Family Controls 不用逐個 bundle ID 申請了（新版表單給整個帳號）。帳本裡「每個 bundle ID 填一次」是舊版做法。
- 只 commit，不推、不打包。要出 TestFlight build 先問多米。

## 下個會話最重要的檔案
- `.vibe/規矩檔.md` ← 動工前必讀（AI 憲法、踩過的坑）
- `.vibe/安全標準.md` ← **下一個會話必讀**。擋 app 會新增一個系統權限、一個社群原生套件，P1（只申請用得到的權限）、P4（第三方 SDK）要對一次
- `.vibe/切片帳本.md` ← 「進行中」底下「螢幕使用時間 API」那節：查到的做法、還沒查清楚的、建議四步
- `.vibe/FamilyControls-申請稿.md` ← 權限申請的紀錄與生效後要做的事
- `.vibe/TestFlight-打包步驟.md`、`.github/workflows/testflight.yml` ← 打包流程（已用過 tf-1～tf-3，下一個 tag 是 tf-4）
- `douzhang/App.js`（`useZen`、`makeActions`）、`douzhang/screens/Settings.js`、`douzhang/core/machine.js`（`start`、`keep`、`voidBean`）← 擋 app 要接的地方
- `douzhang/app.json` ← 外掛與權限設定

## 下一步從哪繼續
1. 向多米摘要一句：「今天四樣做完沒驗；擋 app 還沒動工。」然後問兩件事：App ID 那頁勾了 Family Controls (Distribution) 並存檔了嗎；要先驗今天四樣，還是直接做擋 app。
2. 多米說做擋 app：先不要寫功能，先確認四件事再覆誦計畫。
   - `react-native-device-activity`（kingstinct，社群套件）在 Expo SDK 58／RN 0.88 上裝得起來、`npx expo prebuild --platform ios` 過不過。這台是 Windows，prebuild 可能要在 GitHub Actions 上才知道。
   - 外掛能不能只加主 app、不加三個擴充（`.ActivityMonitor`、`.ShieldAction`、`.ShieldConfiguration`）；不行的話三個擴充的 App ID 都要請多米登記並勾同一個能力。
   - 要不要 App Group。要的話請多米去 Identifiers 建一個（例如 `group.org.domyweb.douzhang`）並掛到 App ID。
   - DeviceActivity 排程是不是最短 15 分鐘（我的印象，沒查證）。第一版的設計刻意不靠排程，就是為了避開它。
3. 把這片寫進切片帳本（片名、套件名、要動的檔、覆誦），多米點頭後再裝套件。裝套件走 `npx expo install`，裝完重跑 `npm test` 與 `npx eslint .`。
4. 這個功能 Expo Go 跑不了、多米沒有 Mac，**只能出 TestFlight build 在手機上驗**。打包前先問；打包流程要加 Family Controls 的 entitlement，簽章過了才算權限真的生效，過了去 `.vibe/FamilyControls-申請稿.md` 補一筆。
5. 多米說先驗今天四樣：他回報哪一步怪就從那一步修，修完跑測試、eslint、token-check，commit `[機器存檔點] 實測修正：…`，錯誤日誌記一條。

## 踩到、下一個會話要知道的
- 改檔腳本不要用 bash heredoc 跑 python（字串裡的反斜線會被吃掉，這次又中一次）。用 Write 把腳本寫到 scratchpad 再 `python 檔名`，替換前 assert 次數。
- eslint 開了 React Compiler 那組規則：render 時不能讀 ref、不能改 props 傳進來的 ref。動畫值用 `useAnimatedValue()`；「只用一次的初始值」用一般 state 加回呼清掉。
- 函式超過 80 行 eslint 會警告。`Main`、`Home` 現在都貼著上限，再加東西要先拆。
- Team ID 不要寫進 repo（多米要求過不留個資）；要用時從記憶檔或請多米貼。
- 聚焦模式的橫向鎖的是「兩邊都可以」；開著直向鎖定的人可能看到倒的時鐘，轉 180 度就正。這是代決，多米實測後可能要改。
- `npx expo export --platform ios --output-dir <scratchpad>` 可以在 Windows 上確認 JS 打包得過，抓得到匯入錯誤，抓不到原生問題。

## 這次會話的雜訊（別重新討論）
- 舊版 Family Controls 表單的欄位、英文用途說明稿、「三個擴充要不要一起送」：表單改版後都用不到了。
- 體型 B（分四級）、聚焦 B／C、設定 B：多米沒選。
- 引導使用模式的教學半頁：被螢幕使用時間 API 取代。

## 怎麼跑
開發：`cd E:\豆帳\douzhang; npx expo start --tunnel`（多米手機走 4G 掃 QR）。測試：`npm test`。lint：`npx eslint .`。寫死檢查：在 `E:\豆帳` 跑 `node .vibe/hooks/token-check.js douzhang/<檔>`。
