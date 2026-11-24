# 回報 K（AI23 付費頁＋設定頁購買區＋擋 app 與聚焦的鎖，2026-11-24）：本機編不了、沒跑測試、沒有 git 寫入
檢查：check_swift 0、check_refs 沒定義 0（沒人用只剩舊的誤報，`priceReading` 已接）、check_words 0；`project.yml` 用 YAML 讀過。
**新檔**：`Core/FullOffer`（狀態→句子與主按鈕，純函式）、`Screens/{FullScreen,SettingsPurchase}`、`UI/{FullOfferBlock,FullPreview,ZenClock}`、測試 `FullOfferTests`、`FullLockTests`。`ZenClock` 是從 `FocusScreen` 原樣抽出來的時鐘排版，聚焦與預覽共用。
**改的檔**：AppModel、+Gates（`setFull`）、AppShield、Purchases（`isBusy` 改由 `doing` 算，分得出在買還是在恢復）、LaunchOptions、Gates、ParamsFull、TokensPages、WordsFull、FocusScreen、HomeScreen、RootView、SettingsScreen、SettingsShield、Buttons、project.yml、screens.sh。
**鎖**：擋板 `Gates.shield` 回蓋／拆／不動；unknown 且該擋＝不動，不該擋＝照樣拆（響了不會一直擋）。聚焦要 owned 才進、才開感測器；退款清 `zenFor` 回直向，買回來不會自己轉橫。擋板開關與選過的 app 不動。
**句子對照**（左 WordsFull 現用，右畫布沒用）
- 讀不到價格：「沒有扣款。現在讀不到價格。」｜「還沒買，沒有扣款。現在連不上 App Store。」讀不到也可能是商品還沒過審，不一定是連不上；按鈕照畫布「再讀一次」。原本的「讀不到價格，點一下重試」拿掉。
- 等核准：「…在等核准。核准之後完整版就能用。」｜「在等家長核准…會自己打開」。銀行驗證也會等。
- 沒買成：「沒有完成購買…有被扣款的話，按恢復購買」｜「沒有扣款…」。斷線時不敢說沒扣款。
- 不能購買、驗不過、買好了：都用 WordsFull（前兩句審查改過；「完整版可以用了」對「都打開了」）。恢復三句一樣。
**跟畫布不同**：①多兩種狀態：正在恢復（主按鈕「正在恢復」不能按）、頁開著才問到早就買了（「已購買」＋好）。②驗不過、付款完成但讀不到紀錄、恢復時驗不過，三種都只給「恢復購買」，不給再買。③等待中的字用次要字色（BigButton 加 `waiting`），「恢復購買」不能按時也用次要字色；不用淺的停用色，看不清楚。④「關閉」釘在最上面不跟著捲。⑤預覽的字級照真的聚焦比例：402 寬 91 一樣；375 寬是 84（畫布 74）。⑥預覽的小字最多放到 xxxLarge，當圖看。
**自己決定**：買到一半關掉付費頁，結果寫在設定頁卡片下那一行（頁裡講過的不重講）；頁開著時下一顆自己開始就收起來，正在付款不收；恢復中設定頁那列右邊寫「正在恢復」；說過「買好了／沒找到」後來狀態變了就不再講那句；unknown 照沒買畫，6-7 的 2 秒底色沒做（設定頁不是第一頁，照交辦）。
**承諾句**：5-1 到 5-5 放進 WordsFull，標「草稿，送審前要多米逐句確認」。5-9、5-10 沒寫。
**截圖走查**：加 22、23 兩張付費頁（`DOUZHANG_PAGE=full`，只有開發版讀得到、只開畫面）。模擬器多半拍到「正在讀價格」。03、14 計時中會變兩顆鈕；聚焦與「專注」區沒有截圖了（沒有當成買了的開關，故意的）。
**沒把握編得過**：`AccessibilityNotification`＋`AttributedString.accessibilitySpeechAnnouncementPriority`（照 WWDC23 寫法）；`ViewThatFits` 上下那層在最大字級把訊息改成可捲，排版要看真機；XcodeGen 的 `run.storeKitConfiguration` 沒在番茄帳產過；`FullLockTests` 會真的叫 ManagedSettings 與轉向（測試完轉回）。
**沒保住的邊角**：付款中遇到鈴響，整頁會換成鈴響頁，那次結果的句子看不到（買成了設定頁寫已購買；沒買成要自己再進去）。
**要人走**：沙盒買／取消／恢復／退款／飛航重開、計時中退款、SE、最大字級、VoiceOver；6-34 這次又動到 Purchases，要重看；本機 StoreKit 測試商店在 Xcode 才有用。
