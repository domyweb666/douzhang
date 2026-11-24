# 包 B 回報（傳輸、接頭與測試，2026-11-24）：程式與測試都寫完；本機編不了，逐行讀過，**測試一則都沒跑過**；沒有 git 寫入，沒加 iCloud 權限

## 給 E2（這兩處不改會編不過或字不對）
- **編不過**：`CloudProblem` 多 `.eraseOther`。`SettingsCloudLine` 的 switch 加一個 case：跟 `.eraseFailed` 一樣能點、紅字，畫 `.eraseOther` 那句；`shown` 的 `problem == .eraseFailed` 要連 `.eraseOther`。
- 關掉同步的框改用 `Words.cloudEraseOffNote`（多「手機裡的番茄不會動」）；清除所有資料那個框照舊用 `cloudEraseNote`。
- `CloudQuestion` 多 `.restored`（換機還原），`Words.cloudAsk` 已有那句，`CloudAsk` 不用改。
- `hasCopy`＝開著、或有沒刪成的、或帳本 seen 過；不看買了沒，`WipeAsk`、`wipeAll` 照舊用它。`NoCloudDrive` 不用改（新的兩個要求有預設）。
- `start(_:)` 會把沒刪成的那句帶回來；`erase(for:)`、`eraseTarget` 已不對外。
- 測試：`stage.phone(_:)` 照舊；雲端空了不會馬上問，斷言 `.emptied` 用 `CloudStage.until` 或 `phone.lookAgain()`；「關掉再打開」用 `phone.open()`（不是親手打開）；`FakeHost.taken` 拿掉了。

## 檢查
check_swift 0；check_refs 沒定義 0（沒人用只剩 `Words.priceReading` 與既有 Tokens 誤報）。每檔 235 行內、型別 200 行內。

## 程式（審查 R1–R5、S1–S8、E1、小事都寫了）
- R1 `CloudToken`＋`identity(like:)`。R2 帳本先寫旁邊再換上、讀不到丟錯。R3 `isHollow` 換編號。R4 `CloudAccess`：accessor 第一行比帳號。R5 `isGone`＋`prepare`，`write` 不開資料夾。S1 `doubt`。S2 `CloudConsent.only`。S3 `erasePending`。S4 刪前 `glance`。S6、S7、S8、os import。
- S5 只做①：問不到 vendor 識別碼這輪不同步、帳本沒記的不認；②不做（每寫一檔多一次協調讀）。定案兩題：換機還原先問 `.restored`；`hasCopy` 退款也算。追加：`saved()` 用 `missedPull` 補拉。
- 這輪寫測試沒有發現要改的程式錯，`App/Cloud*` 一行沒動。

## 測試（78 則，原本 44）
- 新檔 `CloudFolderDrive`（拆出來，多 `prepare`、`isRestless`、`onList`、`onWrite`）、`CloudAccountTests`（R1、R2、S2、換機還原）、`CloudGoneTests`（S1、R3、R5）、`CloudAccessTests`（CloudToken、R4、叫停、資料夾不在、S7）。加進舊檔：S3 與退款在 `CloudEraseTests`，R2 與 `isGone` 在 `CloudFilesTests`，補拉在 `CloudTimingTests`。
- S9 兩則改號誌；R4 用另一個協調器佔住、開始等了才放；S1 用 `lookAgain()` 把第一次看到空的時刻往前撥；「寫到一半換帳號」改 `onWrite`。都不靠睡多久。舊的 `writePause`、`moment()` 沒動。
- 沒測：S4（真 iCloud）、S6、`.account`／`.gathered` 通知、刪到一半重開。

## 留意與沒把握
- 帳本讀不到時選「也刪掉」：不知道當初是哪個帳號，`eraseTarget` 是空字串，刪的是現在登入的那個（發生機率很低，沒改）。
- 同步開著時匯入會跟別台的再合回來；重裝多一個舊資料夾；iCloud 滿了沒有提示。
- 沒把握：SwiftFormat 排版；模擬器裡兩個 `NSFileCoordinator` 同一個程序會不會照預期互等（文件說會）；權限設 0o000／0o555 的三則要不是 root 才準。真 iCloud、下載狀態、兩支手機、背景傳要容器建好才驗得到。
