# HANDOFF（2026-11-01，正式版做到第 3 片）

> 給下一個新會話的交接便條。先向多米摘要「上次做完什麼、卡在哪」，等他點頭再動工。
> 真相源：`.vibe/切片帳本.md`（進度）、`.vibe/state.json`（快取）、`.vibe/規矩檔.md`（規矩，session-start hook 會自動注入）。

## 一句話現況
豆帳正式版（Expo／RN，`douzhang/`）走 VibeRails：22 片分 8 組塊，組塊 A「核心迴圈接」6 片做完 3 片（A1 資料層、A2 骨架、A3 邊界），每片都過乾淨審查員自審＋範圍重測＋多米親手立即驗。分支 `uiux-graybox`，53 個 commit，工作樹乾淨，main 未動、未 push。

## 多米最新指令（2026-11-01，優先於流程預設）
「直接往下做，把該做的功能都做完，做到剩我實測為止，那我再測試再給回饋。」
→ 解讀：A4 到 H2 一路做完，**不再每片停下來等他親手驗、不再逐組塊等他放行**；最後給他一份整個 app 的親手驗收清單。這是跳閘，已記進 `切片帳本.md`「⏭️ 跳過紀錄」。機器層（測試、lint、hook、審查員）照跑；審查員改成每組塊一次。G3 匯入、G4 清空是 🔴 不可逆：**程式可以寫，但他測試時一定先用測試資料，再碰真資料**，清單要寫明。

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
