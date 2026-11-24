# 包 I 審查（S 設定頁＋VeggieKit、T 說明字＋鈴響數字）2026-11-24：逐行讀，本機編不了；沒有 git 寫入

檢查：check_swift 問題數 0；check_refs 沒定義 0；check_words 0；超過 100 字的行 0；plist／Contents.json／project.yml 用程式解析過，app-logo.png 192×192。

## 修了一處
- `App/AppModel+Backup.swift` `wipeAll`：觸覺關著的人按清除，開關當場被刪回「開」，接著換回主畫面（TabBar `.selection`）與 `backupsLeft`（RootView `.error`）照樣會震，跟註解「照清除前的開關」不符。改成晚一拍（`Params.tickMs`）才刪觸覺那個 key，三種震動一起照舊開關；外觀照舊當場清。

## 查過沒事
- VeggieKit 1.0.1：遠端 tag＝本機 HEAD（3702d2a），public 簽名逐一對過；`Feedback`（@MainActor）只在 View 裡用；app 內沒有同名的 `Appearance`／`Feedback`；`VeggieRow` 外都有 FadeStyle／.plain（ShareLink、Link、Menu 都有）。
- CI：瓜相同一套 XcodeGen＋遠端 VeggieKit（那邊寫 `from`，這裡 `exactVersion`）、測試 target 沒連套件、`CODE_SIGN_IDENTITY=-`、`-allowProvisioningUpdates`，`gh run list` 看到 iOS CI 與 TestFlight（tf-1、tf-2）都成功。格式與規矩檢查在編譯前跑，掃不到 DerivedData 裡的套件原始碼。沒有 Package.resolved 也沒事（版本釘死，xcodebuild 自己抓）。
- 外觀：`onAppear` 套在視窗上，人蔘修煉同一寫法；沒有 preferredColorScheme 會蓋掉；清除後 @AppStorage 也會自己再套一次。
- 震動：`.haptic` 的 trigger 與條件跟原本同義，震的那一刻才讀開關；沒有漏掉的 sensoryFeedback／產生器。
- 匯入：alert 用 presenting 帶資料，先清 pendingImport 或先跑按鈕都會寫；取消不寫；讀不懂時 current 是 nil。測試期望值手算都對（[3,0,2]＝2 天 5 顆；13 顆起才寫總數）。
- sheet：三張掛在三個不同的子畫面，跟半頁那張不同 View；沒碰 PagerView 與 scrollPosition。頁尾底 24＋bottomClear 92（64＋12＋16），複製完那句疊在頁尾自己的 24 裡，壓不到分頁列。
- `SheetCard.sub`／`SheetRow.sub`／`Words.chevron` 等刪掉的字與參數沒有殘留呼叫。隱私清單 CA92.1 夠用（套件靜態連進 app，信由使用者自己寄）。

## 沒動、記著
- `SheetRow.selected`＋`Words.check` 沒人用，之前就有的。註解還有幾處寫「清空」，畫面字沒有。
- 要真機看：外觀 Menu 在左右滑頁裡、智能調節那串字在 SE 會換行、「13 顆」大字級、寫信畫面。SwiftFormat 細節等雲端。
