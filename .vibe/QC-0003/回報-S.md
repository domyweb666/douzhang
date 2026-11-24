# 包 S 回報（2026-11-24）：設定頁補列＋VeggieKit。沒有編譯器，用讀的；沒有 commit

檢查：check_swift 問題數 0；check_refs 沒定義 0（`VeggieText` 沒有誤報；`Tokens.SettingsPage.SettingsPage` 等「沒人用」是腳本把型別名自己算進去）。`git ls-remote` 看到遠端 tag 1.0.1。

## 改了什麼
- `project.yml`：`packages: VeggieKit`（exactVersion 1.0.1、一行註解講自家不連網），只有 Douzhang target 依賴。pre-commit、check_swift、兩條 CI 都沒有擋 `url:` 的規則，沒動。
- 新檔：`App/VeggieSetup.swift`（VeggieConfig／VeggieStyle）、`UI/Haptics.swift`（`.haptic` modifier）、`Core/BeanTally.swift`、`Design/WordsSettings.swift`、`Screens/Settings{General,Data,Support,About}.swift`、`Assets/AppLogo.imageset`（AppIcon 縮成 192，跟人蔘同規格）、`DouzhangTests/ImportPreviewTests.swift`。
- 順序：標籤、節奏、專注、手感（開發版多「開發」）→ 一般（外觀、到點通知、觸覺回饋、聲音）→ 資料 → 支援（意見回饋、分享）→ 關於（家族）→ 頁尾。`SettingsRow`／`SettingsToggle` 變成 VeggieRow／VeggieToggleRow 的薄殼，每列有圖示；標籤列用它的番茄。
- 外觀：`DouzhangApp` 第一個畫面 onAppear 套一次，選完 onChange 立刻套。聚焦模式是固定色，不受影響。
- 觸覺：RootView、Controls、MinuteRuler、TabBar 改 `.haptic`，JarSounds 兩顆產生器震前看開關；都在震的那一刻才讀。清除時照「清除前」的開關決定震不震，再清兩個 key、外觀回跟隨系統。
- 匯入：確認框標題「用這份換掉現在的番茄、標籤和設定？」，內文「這份有 N 天、M 顆；會換掉現在的 X 顆。」，按「換掉現在的資料」才寫。哪一邊沒有番茄就換說法（憲法不准「0 顆」）；本機檔讀不懂時寫「現在存的那份讀不懂，會整份換掉」。天數只算有番茄的日子。
- 字：匯出資料／匯入資料／清除所有資料用 VeggieText；`Words` 刪 general、dataSection、exportBackup、importBackup、wipeAll、chevron，「清空」改「清除」。PrivacyInfo 只補註解（CA92.1 已涵蓋）。

## 自己決定
1. 一句話介紹「種番茄，記下每天做了什麼」（產品定稿「種番茄＋時間帳本」濃縮的，原文沒有現成短句）。
2. 下一頁用 sheet 內包 NavigationStack（同人蔘），左右滑與分頁列沒動；開源授權整列不放（背景音 CC0、VeggieKit 自家；`pop`、`hit*` 五個音效的來源 repo 裡查不到紀錄，上架前要確認）。
3. `confirmImport` 改收「框自己帶著的那一份」：alert 收掉會先呼叫 cancelImport，原本靠 pendingImport 可能變 nil。
4. 「已複製版本資訊」疊在頁尾下緣 2.6 秒（`Params.noticeMs`，同人蔘）；寄不了信的那句放支援卡下面（出狀況才出現）。
5. 沒動 `.uiux` 詞彙表、黃金行為 52／56／58／61／62、安全標準 S5／S6／P5 的舊字（包外的檔），要主對話補。

## 沒把握（要雲端或真機）
- XcodeGen 抓遠端套件、測試 target 沒直接依賴 VeggieKit 卻 `@testable import Douzhang`：照理編得過，雲端第一次。SwiftFormat 細節同前幾包。
- 外觀選單（Menu）在左右滑頁裡、意見回饋寫信畫面、頁尾間距 48、智能調節那串字在 SE 會不會換行：看真機。滾輪與系統開關自己的觸覺關不掉（系統的）。
