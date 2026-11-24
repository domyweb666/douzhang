# 回報 JC（包 C：購買，2026-11-24）：只加新檔＋project.yml 一處；本機編不了，逐行讀過；沒有 git 寫入
檢查：check_swift 問題數 0；check_refs 沒定義 0，「沒人用」只多 `Words.priceReading`（等付費頁接）。
**新檔**：`Core/FullRule`（FullFeature、FullStatus、FullRule、AskOrder、BuyResult、BuyProblem、RestoreResult）、`App/Purchases`、`App/TimeLimit`、`Design/WordsFull`、`Design/ParamsFull`、`DouzhangTests/{FullRuleTests,PurchaseTests,TimeLimitTests}.swift`、`DouzhangTests/Full.storekit`。
**project.yml**：要改，只動 DouzhangTests 的 sources 與 dependencies（照茄記：排除 `*.storekit`、當資源帶進測試包、`StoreKitTest.framework`）。app 那邊沒動，沒有加權限。
**包 E 怎麼接**：`DouzhangApp` 加 `@State private var shop = Purchases()`、`.environment(shop)`；進入點叫一次 `shop.start()`；回到前景 `Task { await shop.refresh() }`；同步准不准看 `shop.allows(.cloud)`，跟著 `.onChange(of: shop.status)` 傳給 CloudLink。退款＝status 變 notOwned，只停同步。
**付費頁怎麼接**：打開叫 `loadPrice()`；`price == nil` 時按鈕做的是 `loadPrice()`（`isPricing` 寫 `Words.priceReading`、`priceFailed` 寫 `Words.priceFailed`）；`isBusy` 時購買與恢復都不能點；結果用 `Words.buyLine`／`restoreLine`，`isProblem` 才用紅字。
**自己決定**
- 問 Apple 編次序：先問的晚到，不蓋掉後問的（不然買完可能被舊答案鎖回去）。逾時不算答案。
- 茄記是買的時候再要一次商品；這裡買的就是讀到價格那個，按了不用再等；沒讀到價格 `buy()` 直接回 noPrice。付款前多看一次 `AppStore.canMakePayments`。
- 茄記把「App Store 買不到」跟「這支手機不能買」講成同一句，這裡分開。付款途中斷線不敢保證沒扣款，寫「沒有完成購買」加「有被扣款的話，按恢復購買」。
- 恢復多一句「Apple 傳回的購買紀錄驗不過」（6-18 要列；VeggieText 三句沒有）。sync 成功但紀錄逾時算 restoreFailed，不說沒買過。
- 沒結束的交易跟「問買了沒」各跑各的，前者卡住不擋後者。數字另開 `ParamsFull`，免得跟包 B 的 `ParamsCloud` 搶同一檔。
- 6-21：番茄帳沒有自動跳評分，沒加東西。付費頁承諾句、按鈕字沒寫，等多米挑。
**沒把握**：SwiftFormat 排版；`nonisolated static` 從 @Sendable 閉包叫、`StoreKit.Transaction` 在 @Observable 類別裡（茄記是 ObservableObject）；XcodeGen 收 `.storekit` 照茄記，沒在番茄帳產過；購買、退款、重開三件事整合測試預設跳過，要沙盒帳號真機走一次。
**審查後改的**（`回報-JC審查.md`；M1、M2、S1–S5 全照修，沒有不同意的）
- M1 先重問、`finish()` 另開一個 Task 不等它。M2、S4 四句換字（等核准、unconfirmed、blocked、unavailable）。
- S1（代決，主對話定）：剛買完重問只是問不到，就用手上驗過、產品對、沒撤銷的那筆當 owned（`FullRule.settled`），只在記憶體；問得到照 Apple。剛買完 Apple 回「沒有」仍是 unconfirmed，沒加隔一秒再問。
- S2 已知 owned 卻一筆都沒有：再看 `Transaction.latest(for:)`，有撤銷才鎖，沒有或逾時當問不到。代價：這次打開中登出換帳號，要重開才鎖。
- S3 打開那次問不到再問一次（`storeTries`）。S5 sync 失敗照樣重問，owned 就算恢復，不然只回 failed（`FullRule.restored`）。
- 小項 1、4：`TimeLimit` 註解補「會卡執行緒的先丟 DispatchQueue」；問的次序拆成 `AskOrder`。測試加 11 則。
- 給包 E：status 變 notOwned 時再叫一次 `loadPrice()`；6-7 的 2 秒上限畫面自己做，unknown 照沒買畫。
**要改的標準沒動**（留給收尾）：安全標準 RESILIENCE 轉適用、NETWORK、規矩檔「無金流」、詞彙表補 WordsFull 的字。
