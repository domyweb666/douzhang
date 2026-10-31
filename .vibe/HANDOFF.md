# HANDOFF（2026-11-01 晚，正式版機器層做到 E2；多米要換新對話接著做）

> 給下一個新會話的交接便條。先向多米摘要「上次做完什麼、卡在哪」，等他點頭再動工。
> 真相源：`.vibe/切片帳本.md`（進度與每片覆誦）、`.vibe/state.json`（快取）、`.vibe/規矩檔.md`（規矩，session-start hook 自動注入）、`.vibe/黃金行為.md`（1–44 條）。

## 一句話現況
豆帳正式版（Expo／RN，`douzhang/`）22 片做完 14 片的機器層：組塊 A（6 片）、B、C、D、E 各 2 片。A1–A3 多米親手驗過，A4 起照多米指示一路做、不逐片停。剩 F（收工與葉子）、G（設定、匯出入、清空）、H（正式殼）共 8 片。分支 `uiux-graybox`，工作樹乾淨，main 未動、未 push。測試 99 過 1 跳過、eslint 0 錯、prettier 全過、token-check 全放行。**B 到 E 的畫面沒在真機開過**（電腦渲染不了 RN），只有純邏輯有測試。

## 多米的指令（2026-11-01，仍然有效）
「直接往下做，把該做的功能都做完，做到剩我實測為止。」→ F、G、H 一路做完，不停下來等他；審查員每組塊一次；最後給他整個 app 的親手驗收清單（`.vibe/操作清單-待驗.md` 最上面新開一節「整 app 批次驗收」，依組塊 A→H 排；G3 匯入、G4 清空 🔴 要先用測試資料）。

## 新會話第一件事（照順序）
1. 讀這份、`.vibe/切片帳本.md`「進行中」那節（每片的覆誦與偏離都在）、規矩檔。向多米摘要一句：「上次機器層做到 E2，剩 F、G、H 八片；我先補派 D＋E 的審查員，再做 F1。」等他點頭。
2. **審查員欠兩筆**：
   - B＋C 的乾淨審查員上個會話派了，結果沒等到就交接。重派一次（diff 範圍 `git diff 3006ded 189ed94 -- douzhang`，排除 jarPhysics／receipt／Jar／assets 那幾個先行檔；餵 `.vibe/標準清單.md` 的 B、C 兩節、黃金 23–33、規矩檔、06 狀態表、PRD S5 S6 S9 S10）。
   - D＋E 還沒派（diff `git diff 189ed94 HEAD -- douzhang`；餵標準清單 D、E 兩節、黃金 34–44、規矩檔、參數表、PRD S12 S13 S19）。
   - 審查員的 prompt 樣板在切片帳本「組塊 A 乾淨審查員」那節上面有寫怎麼餵；退回點修完 commit `[機器存檔點] 組塊 X 審查員修正`，記錯誤日誌。
3. 從 F1 開始，每片照機器層流程走。

## 這個會話踩到、下一個會話要知道的
- **`--legacy-peer-deps` 會把 peer 拔掉**：上上個會話裝 expo-notifications 時 jest-preset 與 typescript 被拔，測試與 eslint 都起不來。已把 `@react-native/jest-preset@0.88.1`、`typescript@6.0.3`、`@types/react@19.3.0` 明寫進 devDependencies。之後裝套件（G 要裝 expo-sharing、expo-document-picker、expo-file-system）照樣 `npm install --legacy-peer-deps <pkg>@<版本>`，裝完**一定**重跑 `npm test` 與 `npx eslint .`。
- **React 編譯器 lint 很嚴**（eslint-config-expo 58 帶 react-hooks 的 refs／immutability／purity 規則）：render 裡不准讀 ref、不准改 useState 的物件、物件字面量裡的 handler 呼叫 `Date.now()` 會被當 render。解法已用在 `ui/Jar.js`（世界放 ref、每幀抄快照進 state）與 `App.js`（`act((t) => fn(live, t))` 包在 useCallback 裡）。新畫面照這兩個寫法。
- **App.js 結構**：`useDouzhang()` 管狀態與 `actions`（start／keep／backFromRest／flow／draft／jot／doneEarly／void／pickType／addType／renameType／setTypeLen／removeType／estimate／pickTask），`App` 只排版；`screen` state 切 home／settings／rack。F、G 的動作往 `actions` 加。`core/settings.js` 已有 `setRestMode／setCloseTime／setSound／setTilt` 並有測試，G1 只要接畫面。
- **token-check 抓不到非樣式數字**（15、30、5、60 這種），審查員會抓；數字一律進 `design/params.js`，字由 words 的函式帶數字。
- 半頁與列元件已有：`ui/Sheet.js`（半頁殼）、`ui/BigButton.js`、`ui/TextButton.js`（`flush` 貼齊）、`ui/Segmented.js`、`ui/LineInput.js`、`ui/TypeSheets.js` 的 `SheetRow`。Settings 的 `Cap`／`Group` 在 `screens/Settings.js`。
- `borderBottomWidth: 1` 髮線用 `// token-ok` 放行，lessons 記過；第二處以後考慮 Tokens.shape 加 hairline。

## F、G、H 要做什麼（細節在切片帳本，這裡只寫上面沒寫的）
- **F1 收工**：過 `settings.closeTime`（"HH:MM" 字串比對本地時間）且今天未 `closed` 時，主畫面待機（卡片下 hint 列）與豆棚頂端列出現「收工」入口；半頁預填 `clue.text`、按收工寫 `clue`（有改才換）、`day.closed = true`、`planted = {text, day, shown:false}`；明天打開待機小標從「下一步」變「昨天的你留了一句」一次（PWA renderHome 的 fresh 邏輯：`planted.day !== today && !shown` → 標 shown）。注意 `machine.keep` 現在**沒有**把 `closed` 重設成 false（PWA finish 會），F1 要加回去並寫測試。詞：06 收工半頁那列。
- **F2 葉子**：今天沒豆沒作廢時收工半頁多一列「掛一片葉子」→ `leaf = true, closed = true`；豆棚那天 `Leaf`（E1 已畫好，`leaf && !beans.length` 才顯示）。
- **G1 設定頁**：`screens/Settings.js` 補四區：節奏（休息 auto／self 用 Segmented、收工時間用 `@react-native-community/datetimepicker`？——**不在白名單**，先用一個小時刻度 Segmented 或自己兩個 Segmented 選時與分，別裝套件；寫進帳本）、提醒（到點通知：沒開顯示「沒開・打開」→ `Linking.openSettings()`，權限狀態從 App 的 `notifDenied` 傳進來；聲音開關）、手感（傾斜開關）、備份（G2／G3 的入口＋一行說明「豆帳的資料只在這支 iPhone 上。每週匯出一次備份。」＋上次自動備份時間）。開關用 RN `Switch`。
- **G2 匯出**：`expo-file-system` 寫 `cacheDirectory/豆帳備份-YYYY-MM-DD.json` → `expo-sharing.shareAsync`，分享完刪暫存（安全 S7）。
- **G3 匯入**：`expo-document-picker.getDocumentAsync({ type: 'application/json' })` → `getInfoAsync` 看大小 ≤ 5 MB（params）→ 讀字串 → `JSON.parse` 包 try → `normalize`（不過就顯示 `words.importUnreadable`，資料不動）→ **先把現有狀態寫到 `documentDirectory/auto-backup-<時間>.json`** → `Alert.alert('用備份覆蓋現在的資料？')` → commit。PWA 檔的 `current` 要轉：`phase: 'flow'` → `focus` 且 `flowed: true`；`phase: 'bell'` → `focus`（endAt 已過自然是鈴響）；`restMode: 'self'` 的 rest 把 `endAt` 設 null；`current.notes／pings` 缺就補 `[]`。這些放 `store.normalize` 或新函式 `migrateCurrent`，要測試。`unreadable` 旗標在匯入成功後要清掉（App 目前 `unreadable` 為 true 時 commit 不存檔，匯入是唯一准覆蓋的動作，G3 要加一條 `onImport` 直接 save 並 `setUnreadable(false)`）。
- **G4 清空**：`Alert.alert` 標題「清空所有豆子、豆莢和設定後就找不回來了」內文「要留的話先匯出備份。」→ `blank()` commit、刪 `documentDirectory` 下的 auto-backup、`sync` 會把通知清掉、回第一次畫面（06 的「全部清掉了…」那句待機小標，要加詞）。
- **H1**：三種模式走查是多米的事；機器部分＝token-check 零命中已在 hook，另跑一次 `grep -rn "連續\|還沒開始\|0 顆" douzhang --include=*.js` 確認沒罪惡感字眼。
- **H2**：`app.json`：`plugins: ["expo-notifications"]`、`splash` 淺深各一底色不放圖、確認沒 `scheme`、拿掉 `web` 區、`ios.infoPlist` 不宣告用不到的權限；icon 用現有 `assets/icon.png`（範本的，多米之後換）；grep `__DEV__` 只剩 `DEV_TYPE` 那條路。

## 站位
- state.json `station: spec-standards`，下一片 F1。計數：機器 14、人 3；第 12 片的完整回放沒做（整套測試每次都跑，但沒有乾淨審查員），交 D＋E 審查員補。
- 設計檔動過：詞彙表加了 A4–E2 的字（約 70 列）、參數表 D 節加 4 列、Tokens 兩份加 `opacity`（A2）與 `shape.podDot`（E1）、lessons 加一列。

## 已定案、不要重問
- 核心動詞「接」；方向 A／A；導覽左上豆棚右上設定；留白要多按「這顆不留話」；第一次寫完直接「開始這顆」。
- 資料格式同 PWA 七欄加 `taskId`；AsyncStorage key `douzhang.v1`。
- 通知只問一次、只在第一次按開始；被拒只顯示一行（目前只在計時中顯示）。
- 休息＝長度÷5 最少 3；拖超過休息長度直接待機；「我自己決定」的休息 `endAt: null`。
- 物理數字從 Tokens.motion 讀，不另搬 params。
- 開發期長按「開始」1 秒＝測試顆 1 分；正式 build 沒有。

## 怎麼跑
開發：`cd E:\豆帳\douzhang; npx expo start --tunnel`（多米沒 Wi-Fi，手機走 4G 掃 QR）。測試：`npm test`。lint：`npx eslint .`。寫死檢查：在 `E:\豆帳` 跑 `node .vibe/hooks/token-check.js douzhang/<檔>`。
