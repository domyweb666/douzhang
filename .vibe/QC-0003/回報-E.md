# 包 E 審查回報（2026-11-24）：沒有編譯器，用讀的；沒有 commit

檢查：check_swift 問題數 0；check_refs 只剩 `Tokens.ZenLayout.self`（誤報）。
讀完：整份 `git diff -- ios-native`、20 個新檔、改到的畫面與核心檔前後文、CI、lint 與 format 設定、截圖腳本。

## 修了三處
- `Screens/SettingsScreen.swift:56-72`：清空的第二個框、「先匯出備份」的分享選單，原本在第一個 alert 的按鈕裡同一拍就開，SwiftUI 可能吞掉。改成下一拍（`Task { }`）再開；匯出抽成 `exportFirst()`，不在 Task 裡抓 body 的 `@Bindable` 區域變數。
- `UI/MinuteRuler.swift:87-92`：`onAppear` 就把位置交出去，第一次排版可能還沒好，會停在 1 分、甚至把 1 寫回去。改成等一拍（`Params.tickMs`）再交，跟 `RootView` 指定頁在雲端驗過的同一個做法；交之前透明，看不到跳格。
- `UI/MinuteRuler.swift:56`：註解跟著改。
測試期望值一個都沒改，手算後都對。

## 看過沒問題
- 逐一初始化式：FocusRun／Bean／VoidEntry／AppState／TimelineItem／ReceiptRow 的新欄位都在最後或順序對；`@State private`、`@Environment private` 有初值，不會讓 init 變 private；`SlowWatch()`、`FrameTally()` 走預設 init。
- `RestMode.smart`：沒有任何地方對 RestMode 做 switch；`== .auto`、`!= .own` 的地方都對；`RestRun.endAt` 有值，通知與自動開始照走；讀檔不認得的值退回 auto。
- 智能調節：單位是分，÷5 四捨五入、跨 100 加 10、夾 3–30、long＝有跨過；25 分四顆 5/5/5/15、50 分第二顆 20、延長 55 分 11，手算跟測試一致；跨日照「開始那天」。
- `doing`：開始抄進這顆、收下與作廢抄進紀錄、四處讀寫、舊檔當空；換編號與放回那天都是改欄位，不會漏。
- `Tokens.Layout`：`Tokens` 裡沒用到 SwiftUI 的 Layout 協定；`FlowRow: Layout` 在外面，解析到 SwiftUI。
- iOS 17：`onScrollPhaseChange` 有 `#available(iOS 18)`；其他都是 17 就有；沒有新的 SF Symbol。CI 是 macos-26（Xcode 26），認得 iOS 18 API。
- 番茄堆：`scene` nil 時不畫，`onKnown` 接好才畫；只建一次；滑動凍結、停穩 0.5 秒才開關感測器，取消有處理。
- 並行：Swift 5 模式；FrameMeter、PagerMotion、JarSceneTests 的 @MainActor 用法可編；JarView 裡 `scene?.tap()` 這類單行閉包回 `()?` 合法。
- lint／format：行寬、檔長、識別字、逗號、import、寫死數值，自訂規則逐條對過新檔。`make_state.py`、`make_users.py`、截圖流程都只用欄位與環境變數，不點字，不受影響。

## 沒把握，要雲端或真機
1. SwiftFormat 0.64 的排版細節（本機沒有工具），CI 紅了下載 swiftformat-patch 套上。
2. 刻度尺打開停對格（iOS 17、18、26 各看一次）、番茄堆上下撐進安全區、螢幕最底那條點番茄。
3. 筆記本：線跟字對齊、注音換行、自動拿游標；開著時切深淺色線色不換（沒修，影響小）。
4. 兩層 alert 與「先匯出備份」要真機按過；JarSceneTests、PagerMotionTests（各等 1.5 秒）是雲端第一次跑的 @MainActor 測試。
5. 使用者決定類（不是錯）：聚焦模式那行、鈴響頁標籤、分析頁作廢行沒接 `doing`。
