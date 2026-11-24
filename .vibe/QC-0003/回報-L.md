# 回報 L（AI23 審查修正 R1–R5、R7、R9、R11、R12，2026-11-24）：本機編不了、沒跑測試、沒有 git 寫入
檢查：check_swift 問題 0、check_refs 沒定義 0（「沒人用」15 條都是舊的誤報）、check_words 0。檔案 LF、無 BOM 照原樣。

**改了什麼**
- R1：`FullScreen.swift:25-29` FullOfferBlock 加 `.layoutPriority(1)`，加在 padding 外面，是跟 ScrollView 同一個 VStack 的那個子 View。`FullOfferBlock.swift:17-23` 價格移出 ViewThatFits，固定在訊息下、購買鈕上；`:37-46` 訊息自己一塊，放不下才捲，另加 `.layoutPriority(-1)`。多的這個是重推才看到的：不加的話，訊息會跟價格平分高度，SE AX5 價格只分到約 180（要 193），第一行會被截掉。
- R2：`FullOffer.swift` `isUnsettled`、`kept`、`after`。進頁、關頁、按恢復時沒定論的不清；取消、重複點不算新結果；變 owned 就忘（`SettingsPurchase` 的 `forget`）。主按鈕照 `FullNote.main` 沒動（等核准是「好」、另外三種是「恢復購買」）。
- R2 多動一處：那一次從 SettingsPurchase 的 `@State` 搬到 `Purchases.lastNote`（`Purchases.swift:24`）。鈴響時 PagerView 整個拆掉，`@State` 會跟著沒，做完一顆再進來又是「購買」。
- R3：`FullLockTests` 兩條，冷啟動＋unknown：停下來、已經響了，都要 `.clear`。把 `!= .clear` 改成 `== .blocked`，applied 停在 `.unknown`，兩條都紅。
- R4：「範例」併進下面那行「範例・寫第三節」，角落的疊圖拿掉，任何寬度都不會疊。高度也放得下：375 寬 xxxLarge 約 108／134，320 寬約 95／112。
- R5：`FullOffer.swift` `FullCue.closes`，`FullScreen.swift:41` 用一個 onChange 同時看 phase 與 note，同一拍都變也只收一次。不看 `isBusy` 變 false，改看結果到了（結果一定在 `doing` 清掉之後才寫），不會搶在結果前面收。
- R7：`AppModel+Gates.swift:24-34` 用換狀態前的 `zenOn`。測試：原本那條加「page 是 nil 也回 home」；新增「記號留著但沒在聚焦，設定頁不動」。
- R9：`FullScreen.swift:32` `.accessibilityAction(.escape, onClose)`，付款中也能關，跟關閉鍵同一條路。
- R11：改成計時中、擋板蓋著時 wipeAll，要 `.clear`、`fullStatus` 還是 owned、再開始一顆照樣蓋。`HostSettings` 先記外觀、觸覺、選過的 app，等晚一拍的清除做完再放回去。
- R12：`Words.priceUnread`「現在讀不到價格。」；按了購買的 `.noPrice` 維持「沒有扣款。」開頭。兩條測試。
- 新檔 `DouzhangTests/FullNoteTests.swift`（R2、R5 規則）。

**重推 R1（估的，要真機看）**
- SE 375×667、AX5、有錯誤句：可用 647，關閉 64、價格 193＋12、購買 52、下面兩顆 8＋128、上下邊 24 → 訊息剩約 166（可捲），上面清單剛好 0，不是負的。沒有錯誤句時清單有約 166 可捲。
- iPhone 17 預設字級：可用 778，底下那塊約 148（有兩行錯誤句約 196），清單 586／538，內容 475，全部看得到。
- 320×568 放大＋AX5＋錯誤句：價格與三顆鈕都在，訊息只剩約 43 高（不到一行），要捲。
- 這一頁本來就沒有法律連結，隱私權在設定頁「關於」；這次沒加。

**待確認**
1. SE AX5 有錯誤句時，上面的清單整塊看不到（高度 0），要等那句不在才看得到。要不要留一個最小高度？
2. 可能已經扣款 → 按恢復 → 斷線失敗：照「有新結果就換」，主按鈕變回「購買」（Apple 會擋重複扣款）。要更保守就讓 `.failed` 也不算新結果。
3. 等核准被家長拒絕時 Apple 不會通知：要按一次設定頁「恢復購買」（回沒有紀錄）或重開 app 才買得到。
4. 沒定論的那一次只在記憶體，殺掉重開就忘（F2 不存）。
5. `lastNote` 活得比頁面久：付費頁被鈴響拆掉時，講過的那句之後會再出現在設定頁那一行（K 說沒保住的邊角變成看得到；R13 的「不會自己收」也跟著長一點）。
6. R5：沒定論的句子還在時，付款中變計時又取消，頁留著（畫面上有句子）。
7. 「範例」從角落搬到下面，跟畫布 1C 不同。

**沒把握編得過**：`SettingsPurchase` body 裡 `@Bindable var shop = shop` 蓋掉同名的環境值（照 SettingsData 的寫法）；`HostSettings`（MainActor 的 private struct，在 async 測試裡 defer 呼叫）。`.escape` 掛在 VStack 上有沒有用要真機 VoiceOver 試。

**要主對話改的文件**：詞彙表的讀不到價格那兩列、安全標準 F3／F5（審查 G2）。
