# 工作包 J 施工規格：收費與 iCloud 同步（2026-11-24）

多米原話：「收費和iCloud都照你的建議做」。規格來源 `I-iCloud購買提案.md`，推薦做法就是定案；這份只補介面與細節。衝突時以提案為準。

## 所有人都要守
- 照 `計畫.md`「所有人都要守」與「補充」。先讀 `.vibe/規矩檔.md`、`ios-native/.swiftlint.yml`、`.swiftformat`、最像的鄰近檔，模仿寫法。行寬 100、檔 300 行內、型別 200 行內、函式 40 行內。不准 `!`、print。註解只寫為什麼，繁體中文。
- 這台 Windows 沒有 Swift：寫完逐行當編譯器讀（型別、可見性、`async`、`@MainActor` 隔離、Sendable、缺 import、窮舉 switch）。看 `project.yml` 用哪個 Swift 版本。
- 改檔用 Edit／Write，不用 heredoc python。暫存檔放自己的 scratchpad。
- 不准：任何 git 寫入、push、tag、碰 Apple 後台、`project.yml` 加 iCloud 權限（容器建好才加）。
- **上一個對話正在改**，碰都不要碰：`Screens/{HomeRings,FocusScreen}`、`UI/{BellReceipt,TomatoView}`、`Core/Grow`、`Design/{Params,Words*（既有的）,Tokens*}`、`.vibe/{切片帳本,操作清單-待驗,黃金行為}.md`、詞彙表、參數表、`Resources/*.wav`。新字放新檔 `Design/WordsCloud.swift`、`Design/WordsFull.swift`（`extension Words`），新數字放新檔 `Design/ParamsCloud.swift`（`extension Params`）。
- 完工跑（在 `E:\豆帳`）：`PYTHONIOENCODING=utf-8 python .vibe/hooks/check_swift.py ios-native`、`check_refs.py`。新檔還沒人接時 check_refs 的「沒人用」可以留，列出來；「沒定義」要是 0。
- 回報寫 `.vibe/QC-0003/回報-J<包名>.md`，25 行內：做了什麼、自己決定什麼、哪裡沒把握編得過。

## 共用介面（各包照這個寫，不准改名）
```swift
// App/TimeLimit.swift（包 C 寫）：兩個 Task 搶答，不用 task group（準則 6-10）
enum TimeLimit {
    struct Expired: Error {}
    static func run<T: Sendable>(_ seconds: Double,
        _ work: @escaping @Sendable () async throws -> T) async throws -> T
}

// 格式 v3（包 E 才動既有檔；包 A 先照這個欄位寫）
struct TagType { var id, name; var len: Double; var color: TomatoColor; var mod: Millis = 0 }
// JSON 欄位 "mod"。RemovedTag 照舊（type + removedAt）
Store.formatVersion == 3
```

## v3 升級規則（包 E 做；包 A 的測試可以假設已經做好）
- 讀檔時標籤沒有 `mod`：跟 `Store.presetTypes` 同 id 的那個完全一樣 → 0（沒動過的預設）；id 是 `t<毫秒>`（自己加的）→ 那個毫秒；其他（改過的預設，不知道何時）→ 1。純函式放 `StateUpgrade`。
- `SettingsLogic` 的 addType、renameType、setTypeLen、setTypeColor 都要寫 `mod = now`：多收一個 `now: Millis`。值沒變就不動 mod（改成一樣的名字不算改）。
- 舊版讀 v3 檔只是不認得 `mod`；v3 讀 v1／v2 檔照上面補。讀進來再寫出去一樣。`BackupFormatTests`、`FormatV2Tests` 等會寫死 2 的要改，另加 `FormatV3Tests`。
- `ios-native/scripts/make_state.py`、`make_users.py` 若寫死版本，看要不要跟。

## 包 A：同步的純邏輯（新檔 `Core/SyncMerge.swift`、`Core/SyncFiles.swift`、需要就再拆＋測試）
**檔案**：`<deviceId>/2026-11.json`＝`{"v":3,"days":{"2026-11-24":{"beans":[…],"voids":[…]}},"gone":{}}`；`<deviceId>/tags.json`＝`{"v":3,"types":[…],"removed":[…]}`。欄位寫法跟狀態檔同一套（`StateEncoding`／`StateDecoding` 現在是 private 的，列出要放寬哪幾個給包 E；你的檔先照放寬後的名字叫：`StateEncoding.writeDay`、`writeTagType`、`writeRemoved`）。JSON 鍵排序（`.sortedKeys`），同樣內容每次寫出來一樣，才比得出有沒有變。
- 每台寫的是**這台現在的整份**（含從別台合進來的），只寫自己的資料夾。`gone` 先留空、讀到不理。
- 路徑驗證純函式：deviceId 要是 UUID 字串、檔名只准 `YYYY-MM.json`（月 01–12）或 `tags.json`，其他一律忽略（CWE-22）。`v` 大於自己的整檔跳過；讀不懂、超過 `importMaxBytes` 的跳過；日期鍵格式不對的那天跳過。不信任任何欄位型別（走 `StateDecoding.readDay`、`readTagTypes`）。
- 不寫進雲端：`current`、`doing`、`typeId`、各種偏好、測試顆（看程式怎麼認 demo 顆；認不出來就寫明並提做法）。

**合併** `SyncMerge.merged(_ local: AppState, _ remotes: [SyncFiles.Remote]) -> AppState`（純函式、不碰 `current`／偏好）：
- 番茄與作廢照 `id` 聯集，沒有 id 的不收。日期鍵：有 start＋認得的 zone 就算出來（`StateUpgrade.regrouped` 同一條規則），沒有就用檔裡的鍵；同 id 兩邊鍵不同取較早的。
- 同 id 內容不同：收下贏作廢（作廢那筆的念頭、有人找併進去）；時刻類取晚的；`doing`、`clue`、`text` 兩句不同都留、分兩行（一邊包含另一邊就留多的那份）；notes、pings 聯集（保順序、不重複）；`done` 任一 true；`zone`、`start`、`len`、`typeId`、`reason` 等其他欄位挑一個**跟順序無關**的規則（例：keptAt 較晚的那份，再同就比 JSON 字串），寫在註解。
- 標籤：照 id；`mod` 晚的贏、同 mod 內容不同用跟順序無關的規則；mod 0 永遠輸給 mod > 0；刪除 `removedAt` 晚於該標籤 `mod` 才算刪（刪掉後又改過的就復活，從 removed 拿掉）；兩邊都沒有的番茄 typeId 不管。合完至少留一個標籤（全被刪就留本機 typeId 那個）；`typeId` 不在了退回第一個。順序：本機原順序，新來的接在後面照 id 排。番茄色不重新分配。同名不同 id 的標籤兩個都留。
- 另一台全新安裝帶來的預設標籤（mod 0）：本機同 id 有動過的用本機；本機已刪（removedAt > 0）就維持刪。
- **性質**：交換、結合、冪等（days 與標籤內容；標籤順序除外）。先在 scratchpad 用 Python 隨機跑一次這套規則驗證三個性質，再翻成 Swift；Swift 測試也寫固定種子的情境。
- 每天裡番茄的順序：本機原本怎麼排（看 `Machine.keep`）就照時間排，合完跟只在一台收的順序一致。
- `SyncFiles.outgoing(_ state: AppState, device: String) -> [String: String]`（相對路徑 → 內容），空的月份不寫。
- 舊番茄 id 是讀檔時補的（`StateUpgrade.numbered`），兩台匯入同一份會一樣；寫一個測試證明。

## 包 B：傳輸與接頭（新檔 `App/CloudDrive.swift`、`App/ICloudDrive.swift`、`App/CloudLedger.swift`、`App/CloudLink.swift`＋測試；A 做完才開工）
- `CloudDrive` 協定（兩個實作：本機資料夾給測試、真 iCloud）：可不可用＋目前身分（`ubiquityIdentityToken` 的雜湊）、列檔（每檔有沒有下載好）、讀、寫、刪整個資料夾。真 iCloud：容器 `iCloud.org.domyweb.douzhang`，放在容器裡 **Documents 以外**的 `Records/`（不會出現在「檔案」app）；`url(forUbiquityContainerIdentifier:)` 只在背景呼叫；清單與下載狀態靠 `NSMetadataQuery`（`NSMetadataQueryUbiquitousDataScope`）＋`ubiquitousItemDownloadingStatus`，不看 `.icloud` 檔名；沒下載好的 `startDownloadingUbiquitousItem`、這輪跳過；讀寫刪包 `NSFileCoordinator`；每步走 `TimeLimit`（數字放 ParamsCloud）。
- `CloudLedger`：`{device, identity, seen, sent:{path: sha256}}`，存 Application Support 一個檔並 `isExcludedFromBackup`（換機還原不會兩台同一個編號）。讀不到就當新的。
- `CloudLink`（`@MainActor @Observable`）：開關（UserDefaults `cloudSync`，**預設關**）；准不准＝開關開＋買了完整版（由外面傳進來）＋沒暫停。
  - 拉：打開 app 讀完檔、回到前景、metadata 有更新（短延遲合併）。第一次拉完才准傳。本機讀不懂、存失敗：不拉也不傳。帳本是新的（第一次打開、換機還原）：先跑一次自動備份，備份不成就不同步、設定列說明。
  - 合進本機：`SyncMerge.merged(現在的 state, …)`，有變才 commit；合併不碰 current、不重播番茄掉落（`jarSeen = nil`）。在拉的期間本機又變也不會丟：合的是回到主執行緒那一刻的 state。
  - 傳：存檔成功後等 2 秒合併成一次；進背景馬上傳（`beginBackgroundTask`）；內容 sha 跟上次一樣就不寫；檔在雲端不見了（單檔）就重寫。
  - 換 Apple ID（identity 變）或 `seen` 過但雲端整個空了：暫停、`asking = true`，「放進去」重置帳本再合、「先不要」這次打開不再問。
  - iCloud 沒登入／雲碟沒開：持續 10 秒才在設定列寫出來，不跳框。靜靜同步，失敗不跳出來。
  - 關掉：問「留著 iCloud 那份／也刪掉」；刪＝刪整個 `Records/`（其他台會因為雲端空了停下來問）。清除所有資料：先關同步、清帳本，雲端刪不刪當場問。
  - AppModel 還沒接（包 E 接）：CloudLink 對外用幾個閉包或一個小的 host（不准 import 畫面）；測試用兩個 host＋同一個本機資料夾扮兩台來回。
- 測試至少：兩台互相看得到；離線各收一顆再合；只寫自己資料夾；沒下載好跳過、下次補；壞檔跳過；新版本檔不動；第一次拉完前不傳；本機讀不懂不傳；換身分停下來問；雲端清空停下來問；刪雲端；帳本新的先備份、備份失敗不同步；預設關。
- 字：`Design/WordsCloud.swift`。列名「iCloud 同步」。一律短，不放常駐說明，只有出狀況才有一句。寫給人看的字先讀 `~/.claude/skills/domi-longform-to-notion/references/anti-ai-voice.md`。

## 包 C：購買（新檔 `Core/FullRule.swift`、`App/Purchases.swift`、`App/TimeLimit.swift`、`Design/WordsFull.swift`、`DouzhangTests/Full.storekit`＋測試）
- 抄 `E:\茄記\qieji-swift\ios-native\Qieji\{App/Purchases,Core/FullRule}.swift` 與測試，改成番茄帳的寫法。準則 `E:\多米ios開發準則\book\06-內購.md` 6-1 到 6-21 全部適用，先讀。
- 產品 ID `org.domyweb.douzhang.full`，非消耗性、NT$290、家人共享 false。**程式不寫金額**（`.storekit` 測試檔除外）。
- **本機不存「買過了」**（跟茄記不同）：只放記憶體，三態 `unknown / owned / notOwned`。問得到照 Apple、驗不過當沒買、問不到維持這次打開已經知道的（沒問到過就是 unknown）。只有 owned 才算解鎖。
- `FullFeature { cloud, shield, zen }` 與純函式 `FullRule.allows(_:status:)`；鎖回去（退款）只停功能、不動資料不動設定。
- 打開 app 就聽 `Transaction.updates`、處理 `unfinished`、回到前景重問；驗過的都 finish。`products` 10 秒、沒拿到再試一次；`currentEntitlements` 10 秒；`AppStore.sync()` 不設時限。`start()` 用 `@MainActor @Observable`，不要 singleton（由 App 建、丟進 environment）。
- 結果都有一句中文（6-18）：第一句回答錢的狀態；取消什麼都不說；恢復用 `VeggieText` 三句，找不到時後面加「用別的 Apple 帳號買的，先到 App Store 換成那個帳號再試。」。錯誤不貼英文、log 只印型別。
- 價格只用 `displayPrice`；還沒讀到時按鈕做的是再讀一次。
- 測試：規則每一條、allows、結果對字。StoreKit 整合測試照茄記要環境變數才跑（改名 `DOUZHANG_STOREKIT_TESTS`）。`.storekit` 怎麼進測試 target 照茄記的 project.yml 對一次，番茄帳要不要改 `project.yml` 寫在回報裡（`project.yml` 可以改這一處）。

## 包 D：付費頁畫布（不碰程式）
- 先叫 `domi-uiux-control` → `domi-uiux-review` 照閘門 4 走付費三條，紀錄寫 `.uiux/審查紀錄.md`、`.uiux/閘門紀錄.md`（都是接在最後加，不改舊的）。收費模式由多米親口定：「收費和iCloud都照你的建議做」＝一次買斷。閘門 4 的放行等多米挑完。
- 準則 6-13、6-14、6-16 到 6-20、3-3、3-4、3-18、3-29、3-46。**照番茄帳現有設計代號**（`Design/Tokens*.swift`）畫，淺色深色都要，SE 與大手機都要放得下，關閉鍵一打開就看得到、拒絕寫「先不用」，價格跟其他字一樣大、沒有倒數限時吉祥物。畫布裡價格寫「NT$290」並註明程式讀 Apple 的字串。
- 要挑的題：①付費頁版面 3 個真的不同的方向（標推薦與取捨）；②設定頁「購買」區長相（完整版、恢復購買；買了之後）；③沒買的人計時中「聚焦」鈕：不出現 vs 出現、點了開付費頁（推薦一個；準則 6-17「做到一半時不出現」）；橫放手機在沒買時沒反應；④iCloud 列長相（開、關、出狀況三種）；⑤承諾句一張表，逐句給多米回「可以／改成⋯」（含「付一次就能一直用」「之後新增的背景音與外觀也包含在內」——後者提醒代價）；⑥付費頁狀態：讀價格中、讀不到、購買中、等核准、失敗、買好了、恢復三種。
- 用 Artifact（quickstart intent design → 畫布），繁中；本機備份 `.uiux/03-線框/2026-11-24-J-付費頁.html`（雙擊就能看），無頭 Chrome 截圖看過（不用多米的 Chrome）。文字版 `.vibe/QC-0003/J-設計選項.md`。給人看的字套 anti-ai-voice。

## 包 E：接進既有檔（AI18 commit 之後，A、B、C 完成後）
v3 升級、AppModel 接 CloudLink 與 Purchases、設定頁 iCloud 列（**只有 owned 才列**）、清除所有資料問雲端。擋 app 與聚焦模式的鎖**這次不接**：付費頁還沒寫，先鎖了就沒有路可以買，AI16 的聚焦模式也驗不到；等多米挑完付費頁，跟付費頁、購買區同一片接（`FullRule.allows` 已寫好）。
