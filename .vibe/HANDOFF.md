# HANDOFF（2026-11-01 深夜，正式版 22 片機器層全部做完，等多米整 app 實測）

> 給下一個新會話的交接便條。先向多米摘要「上次做完什麼、卡在哪」，等他點頭再動工。
> 真相源：`.vibe/切片帳本.md`（進度、每片覆誦、四次審查員退回與修法）、`.vibe/state.json`、`.vibe/規矩檔.md`、`.vibe/黃金行為.md`（1–66 條）、`.vibe/操作清單-待驗.md`（最上面「整 app 批次驗收」）。

## 一句話現況
豆帳正式版（Expo SDK 58／RN，`douzhang/`）A 到 H 共 22 片，機器層全部做完。分支 `uiux-graybox`，工作樹乾淨，main 未動、未 push。測試 125 條（124 過、1 跳過）、eslint 0 錯、prettier 全過、token-check 全放行。B＋C、D＋E、F、G 四次乾淨審查員都退回、都修了。**A4 以後的畫面沒有一個在手機上開過**，電腦渲染不了 RN。

## 現在在等什麼
多米照 `.vibe/操作清單-待驗.md` 最上面那節走一遍（A→H，約 50 步；G6–G10 是 🔴 匯入與清空，要先用測試資料、PWA 備份檔先複製一份再拿複製的匯入）。他回報哪一步怪，新會話就從那一步修。清單最後有五個「要你決定的」：番茄這個字要不要統一、收工時間只有 17–22 六個整點夠不夠、週收據要不要加兩區、要不要現在裝 expo-splash-screen、收工草稿要不要存。

## 新會話第一件事
1. 讀這份與帳本「進行中」最上面幾節。向多米摘要一句：「機器層 22 片都做完了，等你照清單實測；你回報哪裡怪我就從那裡修。」
2. 多米回報後：每個「不過」當一個小修，修完跑 `npm test`、`npx eslint .`、token-check，commit `[機器存檔點] 實測修正：…`，錯誤日誌記一條。
3. 全部過了才進下一站：vibe-security-gate 階段 C（`.vibe/安全標準.md` 全面自查，S3、I1、P4 任一紅就是未通過）→ ship-check。

## 這個會話做了什麼（commit 由舊到新）
- 96f343a B+C 審查員六點：任務只掛今天、作廢早停判斷在打開半頁那刻固定、`ui/SheetRow`、`Tokens.shape.hairline`。
- 0478910 F1+F2 收工與葉子；4c375d4 F 審查員五點（招呼每次叫回來重算、只在待機）。
- 42033ba D+E 審查員十點：最重要的是鈴響時豆罐卸載，收下後豆子不會掉；App 用 `jarSeen` ref 記住豆罐上次看到幾顆。
- f6b25a7 G1 設定頁；30d1c90 G2–G4 匯出、匯入、清空（`core/backup.js`）；3841b6e H1+H2；最後一筆 G 審查員五點（`readRaw` 讀不到就不匯、通知三態、主畫面清空後那句）。

## 踩到、下一個會話要知道的
- `npx expo install` 這次直接成功（沒用 `--legacy-peer-deps`），裝完照樣重跑 test 與 eslint。
- expo-file-system 58 是新版 API：`new File(Paths.cache, name)`、`file.create()`（已存在會丟錯）、`await file.write(text)`、`file.text()`、`Paths.document.list()`。舊的 `FileSystem.documentDirectory` 在 `expo-file-system/legacy`，不要混用。
- App.js 結構：`useDouzhang()` 管狀態；動作在模組層 `makeActions(live, act, commit, { setNotif, setGreet })`；另有 `useGreeting`、`useNotificationStatus`、`useBackup`、`useArm` 四個 hook，都在 App.js 模組層。`replaceAll` 是匯入與清空專用（唯一准蓋掉讀不懂本機檔的路）。
- 用 python 腳本改檔時：bash heredoc 裡的 python 有時會被 bash 解析壞，改成先把腳本寫到 scratchpad 再 `python 檔名` 跑比較穩；替換前先 assert 次數，子字串重複會中斷（腳本前半已寫入，要接著跑後半）。
- 審查員一律派 general-purpose、背景跑，叫它用 `git show <commit>:<path>` 讀、不准動工作樹；要跑測試就自己開 `git worktree`。

## 沒做、記在帳本等多米的
- 啟動畫面：SDK 58 iOS 要 `expo-splash-screen`（不在任何一片的套件清單）；Expo Go 用不到，上架前再裝。icon 還是範本。
- Expo 打包時用 bundleIdentifier 自動加的 URL scheme，security-gate 階段 C 再看。
- 收工半頁草稿不存；週收據沒有「每件事估 N／做 M」「再做一下次數」（PWA 也沒有）；減少動態時豆子沒有淡入（`beanDropReduced.fadeMs` 沒用到）、被點的豆不會亮一下。
- `saveFailed` 會被下一次成功寫入蓋掉（審查員 A 的建議 3，還沒處理）。

## 已定案、不要重問
- 核心動詞「接」；方向 A／A；導覽左上豆棚右上設定；留白要多按「這顆不留話」；第一次寫完直接「開始這顆」。
- 資料格式同 PWA 七欄加 `taskId`；AsyncStorage key `douzhang.v1`；匯入時 PWA 的 flow／bell／self 休息由 `store.normalizeCurrent` 轉。
- 通知只問一次、只在第一次按開始；被拒只顯示一行；設定頁照三態。
- 休息＝長度÷5 最少 3；拖超過休息長度直接待機；「我自己決定」的休息 `endAt: null`。
- 物理數字從 Tokens.motion 讀；收工時間六個整點（`params.closeTimes`）。
- 沒有 toast；沒有插圖。
- 開發期長按「開始」1 秒＝測試顆 1 分；正式 build 沒有。

## 怎麼跑
開發：`cd E:\豆帳\douzhang; npx expo start --tunnel`（多米沒 Wi-Fi，手機走 4G 掃 QR）。測試：`npm test`。lint：`npx eslint .`。寫死檢查：在 `E:\豆帳` 跑 `node .vibe/hooks/token-check.js douzhang/<檔>`。
