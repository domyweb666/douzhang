# HANDOFF（2026-11-01 13:40，正式版做到第 3 片；多米要換新對話接著做）

> 給下一個新會話的交接便條。先向多米摘要「上次做完什麼、卡在哪」，等他點頭再動工。
> 真相源：`.vibe/切片帳本.md`（進度）、`.vibe/state.json`（快取）、`.vibe/規矩檔.md`（規矩，session-start hook 會自動注入）。

## 一句話現況
豆帳正式版（Expo／RN，`douzhang/`）走 VibeRails：22 片分 8 組塊，組塊 A「核心迴圈接」6 片做完 3 片（A1 資料層、A2 骨架、A3 邊界），每片都過乾淨審查員自審＋範圍重測＋多米親手立即驗。分支 `uiux-graybox`，53 個 commit，工作樹乾淨，main 未動、未 push。

## 多米最新指令（2026-11-01，優先於流程預設）
「直接往下做，把該做的功能都做完，做到剩我實測為止，那我再測試再給回饋。」
→ 解讀：A4 到 H2 一路做完，**不再每片停下來等他親手驗、不再逐組塊等他放行**；最後給他一份整個 app 的親手驗收清單。這是跳閘，已記進 `切片帳本.md`「⏭️ 跳過紀錄」。機器層（測試、lint、hook、審查員）照跑；審查員改成每組塊一次。G3 匯入、G4 清空是 🔴 不可逆：**程式可以寫，但他測試時一定先用測試資料，再碰真資料**，清單要寫明。

## 新會話第一件事（照順序）
1. 讀這份、`.vibe/切片帳本.md`、`.vibe/規矩檔.md`（hook 會自動注入）。向多米摘要一句：「上次做完 A1–A3 並都親手驗過，你說一路做到 H2 再一起測；我從 A4 通知開始。」等他點頭。
2. 工作樹狀態：`douzhang/package.json` 已裝 `expo-notifications ~58.1.7`（commit c6 之後那一筆），**程式還沒用到它**。安裝時 npm 因 expo 的 optional peer `react-native-web` 要 react-dom 而 ERESOLVE，用 `npm install --legacy-peer-deps` 裝過去的；之後裝任何套件都要加 `--legacy-peer-deps`，並記在錯誤日誌（還沒記，新會話補）。
3. 從 A4 開始，每片照「機器層流程」走，**不停下來等多米**（他的指示），審查員每組塊一次。全部做完給他整 app 的親手驗收清單（`.vibe/操作清單-待驗.md` 最上面新開一節「整 app 批次驗收」，依組塊 A→H 排，G3／G4 註明先用測試資料）。

## A4–A6 已想好的做法（上個會話查過 API，直接用）
- **A4 通知**：新檔 `core/notify.js` 包 `expo-notifications`：`setNotificationHandler` 回 `{ shouldShowBanner: false, shouldShowList: false, shouldPlaySound: true, shouldSetBadge: false }`（前景時 app 自己會切鈴響頁，不跳橫幅只出聲）；`askPermissionOnce()`：`getPermissionsAsync()` 已 granted 回 true、denied 且 `!canAskAgain` 回 false、其他才 `requestPermissionsAsync()`；`sync(state)`：先 `cancelAllScheduledNotificationsAsync()` 再依 `current` 排：focus → 到點（title `words.rang`、body `words.bellSub`），rest 且 `settings.restMode === 'auto'` → 休息完（title 新詞「休息完了」、body `words.backFromRest`）；trigger 用 `{ type: 'date', date: new Date(endAt) }`，`endAt <= now` 不排；`sound: settings.sound ? 'default' : null`。通知文案固定、不含那句（安全 P3）。`App.js`：`commit` 裡 `save` 之後呼叫 `sync(next)`；`onStart` 先 `await askPermissionOnce()` 再 `commit(start(...))`（只有 undetermined 才會跳框＝第一次）；加 `notifDenied` state，開機與 AppState active 時用 `getPermissionsAsync` 刷新；計時中畫面上方一行 `words.notificationOffLine`（新詞「到點通知沒開。鈴只在豆帳打開時響。」）＋文字鈕 `words.openNotifications`（新詞「打開通知」）→ `Linking.openSettings()`。待機那行 06 寫「只顯示一次」，上個會話決定先只在計時中顯示，帳本要記為偏離。Expo Go 上對話框寫 Expo Go 的名字，正式 build 才寫豆帳；`app.json` 的 `expo-notifications` plugin 到 H2 再加。新詞先進 `.uiux/05-設計代號/詞彙表-暫定.md` 系統文案節，再進 `design/words.js`。
- **A5 鈴響細節**：`machine.flow(state, now, minutes)`：只在 phaseOf 為 bell 且 `!c.flowed` 時，`endAt = now + minutes 分`、`flowed = true`、`flowMin = (c.flowMin||0) + minutes`；`keep` 的 bean 改 `flow: c.flowMin || 0`。Bell 畫面：空白時「收下這顆」按了不動（守門），改顯示 44pt 文字鈕 `words.keepWithoutNote`（這顆不留話）→ `keep(state, now, '')`；右上文字鈕「再做 15 分・30 分」（新詞）只在 `!flowed` 時出現 → 半頁（新檔 `ui/Sheet.js`：Modal 透明、veil 點了關、底部卡 `T.shape.radiusSheet`、標題 `words.flowTitle`）裡兩顆 second 樣式 BigButton `words.flow15`／`words.flow30`；輸入框下列 `current.notes`／`current.pings`（`{k, v}`，k 用 `words.noteThought`／`words.notePing`），清單空就不顯示；到點已超過休息長度時副標改 `words.rangAgo(minutes)`（新詞「響了 N 分鐘前。收下後直接回待機。」）。新檔 `ui/TextButton.js`（44pt、`accentText` 或 `textSecondary`）。
- **A6 休息細節**：`settings.restMode`：`'auto'`＝到點提醒（現況）；`'self'`＝我自己決定：休息畫面大時間改成**正數**（`now - current.restStart`）、不排休息通知、`settle` 與 `phaseOf` 不自動結束（只有按回來才結束）。`backFromRest(state, now)` 在 auto 且 `now > endAt` 時把超過的整分鐘加進 `day(dayKey(now)).restOver`（PWA index.html:455 同規則）；這會改 backFromRest 簽名（加 now），帳本要寫。設定頁的切換是 G1 的事，A6 只吃設定值。
- 組塊 A 做完：乾淨審查員一次審 A4–A6（餵三片 diff、標準、黃金 11–16、規矩檔），修完存 `[機器存檔點]`，帳本 A 六片進「機器已驗、待人類批次驗」。

## B–H 要點（切片帳本有細節；這裡只寫上個會話想到、帳本沒寫的）
- **B**：半頁用 A5 的 `ui/Sheet.js`。B2 作廢寫 `days[dayKey(c.startedAt)].voids` 一筆 `{t, typeId, minute: floor((now-startedAt)/分), reason, text, taskId}`，取消通知（sync 會做），回待機。原因清單照 PWA（index.html 搜 `vOk` 附近）。
- **C**：類型半頁與設定「任務類型」區共用一個清單；估幾顆寫 `day.tasks` `{id, name, est, typeId}`，`state.taskId` 指目前那件事（PWA 同名）。
- **E**：收據算法翻 `index.html` 的 `renderDay`／`renderWeek`（估少／估多／剛好、作廢分佈、作廢 ≥3 那一行文案在 index.html:513）；新檔 `core/receipt.js` 純函式＋測試，拿 PWA fixture 比數字。
- **F**：收工寫 `closed`、`planted = {text, day, shown:false}`；葉子 `leaf = true`。入口只在 `now >= settings.closeTime` 且今天未 closed 時出現。
- **G**：匯入流程照 `.vibe/安全標準.md` S3／S4／I1–I5：選檔 → 大小上限 5 MB → JSON.parse 包 try → `normalize` → **先把現有狀態寫一份自動備份到 `FileSystem.documentDirectory`** → `Alert.alert` 確認 → 覆蓋。套件 `expo-sharing`、`expo-document-picker`、`expo-file-system`（裝時 `--legacy-peer-deps`）。清空用 `Alert.alert` 兩段式，連自動備份一起刪。
- **D**：從 `app/Jar.js` 搬 `PARAMS_DEFAULT`、`makeWorld/addBody/step` 進 `core/jarPhysics.js`（純邏輯）＋ `ui/Jar.js`（畫）；參數搬進 `design/params.js`；套件 `expo-sensors`、`expo-haptics`、`expo-audio`；音效檔從 `app/assets/sfx/` 複製；豆子圖從 `img/pea.webp`、`pea2.webp`；減少動態（`AccessibilityInfo.isReduceMotionEnabled`）時靜止版。
- **H**：三種模式走查只能多米做，H1 的機器部分是 token-check 零命中（已在 hook）；H2 `app.json`：`name 豆帳`、`icon`、`splash` 同底色空殼、`plugins` 加 `expo-notifications`、確認沒 `scheme`、iOS `infoPlist` 不宣告用不到的權限。

## 站位
- state.json `station`：做完 A3 人驗後排了第 3 片的 `health-check`（體檢），多米插話要先 handoff、再一路做完。體檢的結論先寫在這裡：四個症狀目前全綠（三片都小、改動都在清單內、審查員三輪沒抓到矛盾、37 條測試全綠）；第五項願景對焦：PRD 核心「接」沒漂，沒長出「絕對不做」的東西，一處要注意的是 Tokens 加了三個數字（opacity、chip）是多米追認的例外。
- 下一片：A4 本地通知（expo-notifications；Expo Go 上權限對話框會寫 Expo Go 的名字，正式 build 才寫豆帳）。

## 每片的機器層流程（不省）
spec-standards（`.vibe/標準清單.md` 覆寫）→ plan-readback 覆誦寫進帳本「本片計畫摘要／本片動到的檔」→ 實作 → `npm test`、`npx eslint .`、`npx prettier --check .`、`node .vibe/hooks/token-check.js`（pre-commit 會自動跑）→ 乾淨 subagent 自審五查核（只餵 diff、標準、黃金行為、規矩檔；不餵理由）→ 修 → simplify → 範圍重測 → `[機器存檔點]` commit → 帳本「機器已驗、待人類批次驗」＋計數＋1。每 3 片跑一次完整回放＋health-check。

## 已定案、不要重問
- 核心動詞「接」；給多米自己用；成功的感覺「原來我做得到」；最怕變成罪惡感 app。
- 方向 A／A；導覽左上豆棚右上設定；留白要多按「這顆不留話」；第一次寫完直接「開始這顆」。
- 資料格式同 PWA（`v、settings、current、clue、days、planted、lastLine`），AsyncStorage key `douzhang.v1`；備份 JSON 與 PWA 相容。
- 通知只問一次、只在第一次按開始；被拒只顯示一行。
- 開發期長按「開始」1 秒＝測試顆 1 分；正式 build 沒有。
- 休息＝長度÷5 最少 3；顆單位＝長度÷25 最少 1；鈴響後拖超過休息長度直接待機。
- Tokens 三個數字（opacity.disabled／pressed、font.chip）多米追認。

## 檔案地圖（douzhang/）
- `design/`：Tokens.js（`.uiux/05-設計代號/Tokens.js` 複本，改代號先改 .uiux 再複製）、words.js（詞彙表翻的，加字先加詞彙表）、params.js（參數表 D 節）。
- `core/`：store.js（blank／normalize／load／save／day／dayKey／units／restMinutes）、machine.js（PHASE、DEV_TYPE、typeOf、phaseOf、settle、start、keep、backFromRest、setDraft）。
- `screens/`：Home.js（Nav／Card／FirstInput／ClueCard／TypeChip／Countdown／CardBody／PrimaryButton 全模組層級）、Bell.js（draft 從 props）。
- `ui/`：BigButton.js（delayLongPress＝params）、Clock.js、useNow.js（tick＋AppState active 重算）。
- `App.js`：讀檔（接 unreadable，壞檔不寫回）、commit→save（saveFailed 旗標）、`live = settle(state, now)`、phase 切 Home／Bell。
- `__tests__/`：store.test.js 17 條、machine.test.js 21 條（1 條 fixture 跳過）；`jest.setup.js` 共用 AsyncStorage mock；`fixtures/pwa-export.json` 多米放了會多一條（已 gitignore）。
- 工具：eslint.config.js（expo flat＋jest globals＋screens 禁 import 只套 screens／core／ui／__tests__）、.prettierrc、package.json overrides `unrs-resolver 1.12.2`（registry 404，之後試拿掉）。
- 已知警告：Tokens.js makeTokens 超 80 行（複本，不在這裡改）。

## 踩過的坑（完整在 `.vibe/錯誤日誌.md`，規矩檔已回灌）
範本 AGENTS.md 叫用 Expo Router（已改）；白名單外的 web 套件（已拆）；token-check 自咬 eslint 設定（已排除設定檔）；unreadable 旗標被丟（已接）；參數定了沒接（已接）；覆誦與實作不同要當下改帳本；測試名要跟斷言一字不差。

## 待收尾（已記帳本）
- `saveFailed` 旗標會被下一次成功寫入蓋掉，S6「要被看到」在偶發失敗時不成立，留給 A6／G1。
- PWA 舊檔 `current.phase` 可能是 `'bell'`／`'flow'`，`phaseOf` 會落到 idle 但 current 非 null，G3 匯入要處理。

## 多米那邊還欠的（設計線，不擋正式版）
UIUX 閘門 1、2、3：3–5 人情境觀察、新人方向測試與秒表、真機手感；usertest 第一輪三個人（`.uiux/07-測試/測試計畫-暫定.md`），結果回來對正式版改。

## 怎麼跑
開發：`cd E:\豆帳\douzhang; npx expo start --tunnel`（多米沒 Wi-Fi，手機走 4G 掃 QR）。測試：`npm test`。灰盒子（線框，不帶走）：`app/`。
