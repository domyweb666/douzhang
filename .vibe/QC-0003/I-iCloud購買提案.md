# iCloud 與購買提案（包 R，2026-11-24；只讀程式，沒連任何後台）

## 一、結論
1. iCloud：推薦用**雲碟檔案**，每台手機只寫自己的資料夾，讀的時候全部合起來。約 4.5 個工作天，外加多米真機半天。預設關。
2. 購買：**沒有定過**。`.vibe`、`.uiux`、`.analytics` 沒有一筆收費決定，沒有 `.aso`；規矩檔:19 寫「無金流」。推薦一次買斷，要收就跟 1.0 一起上。
3. 現在還沒有公開使用者，這時定鎖什麼最便宜。茄記先免費後收費，多做了一輪舊使用者的處理（準則 6-30）。
4. 兩件互相卡：iCloud 要不要算完整版功能，要先答，再動設定頁那一列。

## 二、iCloud
**別的 app 現況**：茄記 Swift 版＝雲碟檔案（`Core/Cloud.swift`、`CloudLink.swift`、`Sync.swift`，約 880 行；207 已送審，真機 iCloud 沒有回報）。豆鍵＝鍵值儲存。蒜日子沒做，直接讀系統行事曆。人蔘修煉沒做，健康資料不准進 iCloud。
**先講需求大小**：番茄帳只有 iPhone。開了整機備份的人，換手機資料本來就會回來。同步真正幫到的是刪掉重裝、沒開備份、兩支手機。
| 做法 | 取捨 |
|---|---|
| **A 雲碟檔案（推薦）** | 後台步驟茄記走過；沒有容量問題；不會即時，回到前景才拉 |
| B 鍵值儲存 | 最省工（約 2.5 天），上限 1 MB。試算每天 8 顆，一年 649 KB、壓縮後約 156 KB（zlib 估的），約 6 年滿，寫字多的人更快 |
| C CloudKit（CKSyncEngine） | 最即時；要在網頁建資料表再部署正式環境，沒有 Mac、家族沒人用過，約 7–8 天 |

**檔案怎麼放**：`<這台的編號>/2026-11.json`（那個月的番茄與作廢）加 `<這台的編號>/tags.json`。只有自己會寫自己的檔，沒有兩台搶寫；剛裝好、雲端清單還沒下載完，也蓋不到別人的。資料夾不公開在「檔案」app。
**合併規則**（純函式，先寫測試）：
- 番茄與作廢照 `id` 聯集，日期鍵一起存（沒時區的舊紀錄只剩它）。現在收下後不能改也不能刪，所以不用刪除記號；格式先留 `gone` 一欄。
- 同 `id` 內容不同（兩台匯入同一份、計時中的那顆也在裡面）：收下贏作廢；時間取晚的；兩句不同就都留，分兩行；念頭與有人找聯集。
- 標籤：每個標籤加改動時間 `mod`，晚的贏；沒動過的預設標籤（mod 0）永遠輸；刪除比最後改動晚才算數。
- 不同步：進行中那顆、休息、下一顆要做的事、聲音傾斜等偏好、要擋的 app、測試顆。合併不碰 `current`、不重播番茄掉落（`jarSeen` 清空）。
- 版本比自己新的檔跳過不動；本機讀不懂或存失敗時不傳；第一次打開前先跑自動備份、只合併。
- 換 Apple ID 或資料夾被刪：停下來問「放進去／先不要」。關掉時問要不要一起刪雲端那份。清除所有資料：清這台、關同步，雲端刪不刪當場問。

**照茄記抄、但要改**：`url(forUbiquityContainerIdentifier:)` 只在背景呼叫（茄記設定頁那條會走主執行緒）；下載狀態看 `ubiquitousItemDownloadingStatus` 加 `NSMetadataQuery`，不看 `.icloud` 檔名；讀寫加 `NSFileCoordinator`；每步有時限。
**動到的檔**：新 `Core/SyncMerge`、`App/CloudDrive`、`App/CloudLink`＋測試（本機資料夾扮兩台）；改 `project.yml`、`AppState`、`StateEncoding/Decoding`、`SettingsLogic`（改標籤記時間，格式升 v3）、`AppModel`、`AppModel+Backup`、`SettingsScreen`、`Words*`、`PrivacyInfo`（註解）。
**工期**：v3 與合併 1.5 天、傳輸 1 天、接 app 與設定列 1 天、雲端編譯除錯與文件 1 天。前兩段不碰真 iCloud，多米點頭前就能寫。
**多米在 Apple 後台**（勾好才寫權限、才打包）：developer.apple.com → Identifiers → 切 iCloud Containers → 新增 `iCloud.org.domyweb.douzhang` → 回 App IDs 點 `org.domyweb.douzhang` → 勾 iCloud（選 Include CloudKit support）→ Configure 勾那個容器 → Save、確認描述檔警告 → 回「勾好了」。描述檔由現在的自動簽章重拿；茄記同一套跑過，但它的容器是先建好的。
**不能還原**：容器建了刪不掉；第一次寫進真 iCloud；合併後分不回兩份（靠自動備份）；存成 v3 再回舊版會掉標籤改動時間。建議先用測試 Apple ID、借第二支 iPhone。
**要改的標準**：`安全標準.md`（離線的前提、NETWORK 轉適用、P4 重寫、P5 清空加雲端、S8 同步不印內容、新增「沒開就不出手機」）；`產品定稿.md`:46、:57 與 11-17 段「資料只在本機」；`規矩檔.md`:19「無網路」；`.analytics/04` 第 21 條；`project.yml` 離線註解；送審文案。隱私標籤照豆鍵、茄記維持「不收集」，送審前再對一次 Apple 條文。

## 三、購買
家族現價（台灣）：茄記 390、蒜日子 350 一次買斷；豆鍵主題一款 60；人蔘修煉造型 120、全套 480。
| 選項 | 內容 | 代價 |
|---|---|---|
| 1 先全免費 | 1.0 不放購買 | 最快送審；之後鎖現有功能會惹人，只能鎖新功能 |
| **2 一次買斷（推薦）** | 免費：計時、番茄堆、標籤、番茄架、分析、雨與柴火。完整版：iCloud 同步、擋其他 app、聚焦模式、之後新增的背景音與外觀 | 約 3 天；第一次送審帶內購，Apple 會多看一段 |
| 3 賣外觀 | 番茄與罐子造型，一款約 60、全套約 180 | 功能全免費；要先畫圖，不賣功能就沒有 iCloud 的錢 |

不推薦訂閱：沒有伺服器成本，家族沒有一個訂閱。番茄數、標籤數不設上限，會變成催人。
價格試算（定價 ÷1.05 ×0.85）：**290 實拿約 235（推薦，功能比茄記少）**、350 約 283、390 約 316；要選後台價位表有的。前提是多米簽好付費 App 協議、入了小型企業方案。
做法抄茄記 `App/Purchases.swift`＋`Core/FullRule.swift`＋`.storekit` 測試檔（有時限），本機不存「買過了」（準則 B15）。產品 ID 建議 `org.domyweb.douzhang.full`，非消耗性。產品 ID 用過不能改也不能重用、家人共享開了關不掉。
動到：新 `Core/FullRule`、`App/Purchases`、`Screens/FullScreen`；改設定頁「購買」區、擋 app、聚焦模式、`Words*`；安全標準 RESILIENCE 轉適用、規矩檔「無金流」。動工前走 UIUX 閘門 4，收費模式由多米親口定。

## 四、Apple ID 與隱私權政策
- **Apple ID 已經有了**：app 11/16 在 App Store Connect 建好。多米到「番茄帳 → App 資訊 → Apple ID」抄那串數字，填 `App/VeggieSetup.swift` 的 `appStoreID`，評分列就會出現。上架後再補 VeggieKit 家族清單、打新 tag。
- **網頁 repo**：`E:\domyweb-main`（`domyweb666/domyweb`，Astro）。現在停在分支 `tool-sites-v2`，有一個沒 commit 的檔，動工前先 `git log`。線上寫法是 `domyweb.org/tools/<slug>/privacy/`。
- **頁長怎樣**：完整版五頁（蒜日子、茄記、豆鍵：`src/content/apps/<slug>.ts`＋五行頁面檔，說明在 `docs/app-sites/README.md`）；沒上架只有兩頁（人蔘修煉：`src/pages/tools/rencan/{privacy,support}.astro`，段落是先講重點、用到哪些資料、存哪、通知、購買、匯出匯入、沒有的東西、怎麼刪、兒童、更新、聯絡）。
- **推薦**：先照人蔘修煉做 privacy、support 兩頁（半天，發布要多米點頭），網址 `https://domyweb.org/tools/fanqiezhang/privacy/`，填進 `privacyURL` 與 App Store Connect。五頁等上架再做。政策要寫：擋 app 的選擇讀不出名稱、匯出檔沒加密、整機備份會帶走；iCloud 或內購有做就加那一段。

## 五、要多米回的
1. iCloud：A（推薦）、B、C，或先不做？跟著第 2 題走：選一次買斷就進 1.0（不然完整版只剩擋 app 與聚焦模式，太薄）；選全免費就放 1.1，1.0 先升 v3 格式。
2. 收費：1、2（推薦）、3？選 2：鎖的三樣對嗎、價格（推薦 290）、家人共享開不開（推薦不開）、產品 ID 可以嗎？
3. 給：Apple ID 數字；付費 App 協議與小型企業方案狀態；有沒有第二支 iPhone 與測試 Apple ID。
4. 點頭：後台建 iCloud 容器；官網上兩頁（slug `fanqiezhang` 定了不改）。
