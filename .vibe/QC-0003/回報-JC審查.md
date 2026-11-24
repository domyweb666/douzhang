# 回報 JC 審查（包 C：購買，2026-11-24）：只讀程式，沒改、沒 git 寫入

先讀程式與規格，最後才看 `回報-JC.md`。這台編不了，以下是逐行讀加上對過真的 CI 紀錄。

## 結論
- 編譯：沒找到編不過的。
- 必修 2 筆（M1、M2），值得改 5 筆（S1–S5），小項與交接 6 筆。
- 沒找到：continuation 重覆回覆、退款不鎖（交易通知與重問兩條都會鎖）、沒買卻能用、永遠過的測試。

## 必修

### M1 `finish()` 沒有時限，又擋在解鎖前面
- 位置：`App/Purchases.swift:155`（bought）、`:163`（settle）
- 為什麼：`await deal.finish()` 排在 `refresh()` 前面，沒有時限。它不回來的話：①付了錢的人不會解鎖，`isBusy` 一直是 true，購買與恢復兩顆都不能點，畫面停在轉圈（豆鍵 2.1(b) 同一種死法）；②`updates` 那個迴圈停在那筆，這次打開之後的退款、家長核准都收不到，只剩回前景那次重問。6-9 寫「所有 StoreKit 呼叫加時限」。
- 怎麼改：先 `await refresh()`，再 `Task { await deal.finish() }` 不等它。沒收成功的下次打開 `unfinished` 會再收。`currentEntitlements` 本來就含還沒 finish 的非消耗性交易，先問不影響。
- 確定程度：程式行為確定；Apple 真的卡住 finish 的機率低。

### M2 「核准之後會自己解鎖」用了禁用詞
- 位置：`Design/WordsFull.swift:20`
- 為什麼：「解鎖」在 anti-ai-voice A 區（看到就刪）；06 章末「用字」也點名這個詞是多米的寫作禁用詞。
- 怎麼改：`"還沒扣款，這筆購買在等核准。核准之後完整版就能用。"`。測試只比句首，不用動。程式註解裡的「解鎖」不算。
- 確定程度：確定。

## 值得改（建議）

### S1 付款成功、交易驗過，只因為重問逾時就不給用
- 位置：`App/Purchases.swift:151-157`
- 為什麼：手上已經有一筆 Apple 驗過、沒撤銷、產品對的交易，`refresh()` 回 `.unreachable` 時還是回 `.unconfirmed`、維持鎖住，要他自己按恢復購買。`currentEntitlements` 剛買完晚一拍才有，也會走到這裡，而且那時回的是 `.notOwned`。
- 怎麼改：`check` 是 `.unreachable` 時，`deal.productID == FullRule.productID && deal.revocationDate == nil` 就設 `.owned`，同時 `asked += 1; landed = asked`，免得較早問的那次晚到又蓋回去。判斷走 `FullRule.check([brief(deal, isVerified: true)])`，規則仍只有一份。回 `.notOwned` 的那種可以隔一秒再問一次。
- 跟 6-1 的關係：6-1 字面寫「只認 currentEntitlements」，這筆同樣是驗過簽章的交易，但等於放寬字面，要主對話點頭。
- 確定程度：程式確定；發生率中低。

### S2 「問不到維持已知」只擋得到逾時，Apple 回空的會把買過的人鎖掉
- 位置：`App/Purchases.swift:168-178`、`Core/FullRule.swift:45-51`
- 為什麼：`currentEntitlements` 不丟錯；離線、帳號暫時登出可能直接走完、一筆都沒有。`check([])` 回 `.notOwned`，這次打開已經 owned 的人會被鎖、同步停掉。茄記送審前審查第 5 點記的是同一件事。資料不會動。
- 怎麼改：已知 owned、這次卻是空的時候，再問一次 `Transaction.latest(for:)`（一樣包時限）：驗過且沒撤銷→維持 owned；有撤銷→notOwned；沒有或逾時→unreachable。退款會留撤銷日期，所以照樣鎖得回去。
- 確定程度：程式路徑確定；Apple 多常回空，準則「還沒驗的」也列著。

### S3 冷啟動那次逾時之後，整個這次打開都是 unknown
- 位置：`App/Purchases.swift:169`
- 為什麼：第一次問 10 秒沒回來就放著，晚到的答案被丟掉；不切出去再回來就一直當沒買（iCloud 列也不會出現）。
- 怎麼改：`start()` 那次照 `storeTries` 再問一次就好：`.unreachable` 才問第二次，不做無限重試。
- 確定程度：中高。

### S4 三句話把原因講死了
- `WordsFull.swift:38` unconfirmed「還沒收到 Apple 的確認」：走到這裡時 Apple 已經確認過（交易驗過了），是紀錄還讀不到。改「付款完成了，還讀不到購買紀錄。等一下按「恢復購買」。」
- `:41` blocked「這支手機的「螢幕使用時間」關掉了」：`canMakePayments` 是 false、`purchaseNotAllowed` 也可能是公司或學校管理的手機。改「沒有扣款。這支手機不能用 App 內購買，到「螢幕使用時間」看看有沒有關掉。」
- `:42` unavailable「你這個地區的 App Store 買不到」：`productUnavailable` 也走這句，那是商品沒上架或還沒過審，跟地區無關（審查員最可能遇到）。改「沒有扣款。App Store 現在買不到番茄帳完整版。」`FullRule.swift:99` 註解一起改。
- 確定程度：前兩句確定，第三句高。三個改法都不動測試比的句首。

### S5 `AppStore.sync()` 丟錯就放棄，沒有再問一次
- 位置：`App/Purchases.swift:113-116`
- 為什麼：冷啟動逾時的已買者會來按恢復購買，這時 sync 失敗就直接「出了點問題」；但本機的 `currentEntitlements` 常常答得出來。
- 怎麼改：不是取消的錯，記下後照樣 `await refresh()`，status 是 owned 就回 `.owned`，不是才回 `.failed`（不准回 nothing）。
- 確定程度：中。

## 小項與交接
1. `App/TimeLimit.swift:4`（給包 B，目前還沒有人這樣用）：註解說 iCloud 也能包。搶答那兩個 Task 都在協作執行緒池；工作要是**卡住執行緒**（`NSFileCoordinator`、`url(forUbiquityContainerIdentifier:)`、同步讀檔），池子滿了計時那個也醒不來，時限就失效，模擬器核心少時更容易。包 B 要把會卡的呼叫丟 `DispatchQueue.global()` 再用 continuation 接回來，工作閉包裡只 await。註解補這一句。確定程度：中高。StoreKit 這裡是真的 async，不受影響。
2. 給包 E：`price == nil` 且 `isPricing`、`priceFailed` 都是 false 的狀態存在（買過的人 `loadPrice` 會直接跳過，開著頁時被退款就是這樣）。不要用「price 是 nil」就寫「正在讀價格」，會一直掛著；status 變 notOwned 時要再叫 `loadPrice()`。
3. 給包 E：6-7 的 2 秒上限這裡沒有，畫面要自己做；逾時後的 unknown 要照沒買畫。
4. `App/Purchases.swift:57-66`：問的次序（先問晚到不准蓋）沒有測試，是這個檔最容易改壞的一段。不必為測試加注入，建議拆一個純函式「這次答案要不要收」放 `FullRule`，測三種順序就夠。
5. `DouzhangTests/PurchaseTests.swift:55-85`：整合測試在 CI 一定跳過，所以「買、退款鎖回、重開」機器沒驗過；茄記那條「沒買過就問不到」（`testRestoreFindsNothingWhenNeverBought`）也沒搬。送審前沙盒帳號真機各走一次（6-28），另外請會寫 iOS 的人看一次（6-34）。
6. 標準檔沒跟上（JC 自己也列了）：`安全標準.md:18`「沒有金流」、規矩檔「無網路、無金流」、詞彙表。收費接上線前要重跑階段 A。

## 為什麼說編得過、CI 不會因為它紅
- Swift 版本：`project.yml` 沒寫，最近一次綠的 CI（run 45034093191，Xcode 26.6）實際是 `-swift-version 5`，沒開嚴格並行、沒有把警告當錯誤、沒有預設 MainActor 隔離。
- 隔離：`deals`、`brief`、`failure` 是 `nonisolated static`，只碰 Sendable 的值，從 `@Sendable` 閉包叫合法；`FullRule.Deal`／`Check` 是模組內的值型別，自動 Sendable；`Transaction` 有寫全名；`@Observable` 配 `@ObservationIgnored` 沒有問題。回 `Check` 的 `Task { await refresh() }` 有 `@discardableResult`。
- `project.yml` 那段跟茄記一字相同，茄記 run 45297457145（同 macos-26、XcodeGen 2.46）綠，紀錄看得到 `CpResource … Full.storekit` 與 StoreKitTest 連結。
- VeggieKit 1.0.1 的四個字串在，內容跟測試比的一樣。`check_swift` 0 問題、`check_refs` 沒定義 0、`Full.storekit` JSON 合法、最長一行 96 字、檔尾有換行、`autocrlf=true` 進 repo 是 LF。
- SwiftLint：`failure(_:)` 複雜度約 9–10，上限是超過 10 才算，再加一種錯誤就會紅。SwiftFormat 沒跑過，只能說沒看到違規。
- 時限測試有效：換成 task group 寫法會等滿 3 秒、過不了 `< 2 秒`；晚到那條有真的等到第二次回覆。
- 回報 JC 跟程式對得上，沒有寫了沒做的。
