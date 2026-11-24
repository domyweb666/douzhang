# 回報 L 審查（AI23 第一輪審查的修正，2026-11-24）

範圍：`git diff`＋`DouzhangTests/FullNoteTests.swift`。只讀，沒改程式、沒 git 寫入。這台編不了，以下都是讀出來的；`check_swift`、`check_refs`、`check_words` 有跑，問題 0、沒定義 0、不用的字 0。

## 結論
- 編不過的、擋板鎖死手機、沒買能用、買了被鎖：沒找到。
- 必修 1 筆（錢：恢復失敗又變回「購買」）。建議 5 筆。記帳 3 筆。

---

## 必修

### M1 可能已經扣款 → 按「恢復購買」→ 沒成功，主按鈕變回「購買」，上面還寫「請再試一次」
- 檔：`Core/FullOffer.swift:77-83`（`after`）、`:57-64`（`main`）；測試 `DouzhangTests/FullNoteTests.swift:83-98` 把這個行為寫成「對的」
- 情境：付款完成但讀不到紀錄（unconfirmed）或驗不過（unverified）→ 畫面說「可能已經扣款…按恢復購買」→ 他照做，斷線或 Apple 沒回（`Purchases.swift:107-116`，同步失敗，或同步成功但問不到，都是 `.failed`）→ `after` 因為「出了點問題，請再試一次」有字，就當成新結果 → `isUnsettled` 變 false → 主按鈕是橘色的「購買」，句子是「出了點問題，請再試一次」。
  - 連在一起讀就是叫他再買一次。而且這是最容易走到的路：會讀不到紀錄，多半就是網路不好，下一步恢復也會失敗。關掉再進來更乾淨，`kept` 回 nil，只剩「購買」。
  - 跟 `FullOffer.swift:56`「不讓他再付一次」、R2 這次要修的事相反。非消耗性 Apple 會擋重複扣款，所以不是真的收兩次，但 R2 等於只修了一半。
- 各種恢復結果該怎樣、現在怎樣：

| 前一次沒定論，按恢復後 | 現在 | 該怎樣 |
|---|---|---|
| 找到（owned） | 好＋已恢復 | 對 |
| 取消、重複點 | 留著原來那句、恢復購買 | 對 |
| 驗不過 | 恢復購買 | 對 |
| **沒成功（failed）** | **購買＋「出了點問題，請再試一次」** | **留著原來那一次**，沒有新答案 |
| 沒有找到（nothing） | 購買＋沒有找到購買紀錄 | 可以：這一格只有「同步成功，而且 Apple 明確說一筆都沒有」才會到（`FullRule.restored`），又是不用重開就能再買的唯一出口，也是等核准被拒的出口 |

- 怎麼改（不加欄位、不加字）：`after` 裡 `.failed` 也不換結果，但給新的 id，讓它再震一下、再念一次（不然按了像沒反應）：
  ```swift
  static func after(_ last: FullNote?, _ result: Result) -> FullNote {
      let next = FullNote(result: result)
      guard let last, last.isUnsettled else { return next }
      if next.line == nil {
          return last
      }
      // 沒問到不是新答案：錢還是沒定論，原來那句再講一次
      return result == .restored(.failed) ? FullNote(result: last.result) : next
  }
  ```
  重講的那句第一句就是錢的狀態，也合 6-18；直接照 `restoreFailed` 講反而沒回答錢。等核准＋恢復失敗也跟著留「還沒扣款，這筆購買在等核准」。新的 id 句子不是 nil，`FullCue.closes` 不會因此收頁。
- 會不會卡死：不會。連得上之後按恢復會得到 owned／nothing／驗不過；前兩種都有路，驗不過或一直連不上的，重開 app 就忘（只在記憶體）。
- 測試：`test有新結果就換新的` 拿掉 `.restored(.failed)`；另加一條：四種 unsettled 接 `.restored(.failed)` 後 `result` 等於原本、`id` 不同、`FullOffer.now(...).main` 不是 `.buy`。`FullOfferTests.test恢復三種` 不受影響（沒有前一次）。
- 確定程度：高（行為）；要不要擋在這裡由主對話決定，我認為要，三行。

---

## 建議

### S1 結果跟「下一顆自己開始」同一拍到，那句還沒看到頁就收了，而且被清掉
- 檔：`Core/FullOffer.swift:93-98`
- 情境：`last.isFocusing == false`、`now.isFocusing == true`、note 同時從 nil 變成有句子的結果、`isBusy` 已經 false → 第二個 guard 直接 `return true` → `uncover` 把有定論的清成 nil。沒定論的會留（對），`.failed`／`.offline`「有被扣款的話，按恢復購買」與「買好了」會不見。
- 機會：要同一次畫面更新，平常幾乎碰不到；付款中 app 被停住、回來那一刻計時與結果一起到比較可能。
- 怎麼改：`guard last.isFocusing else { return note == last.note || note?.line == nil }`，測試加一格。
- 確定程度：行為高，碰得到的機會低。

### S2 R2 的接線沒有測試
- 檔：`SettingsPurchase.swift:52-80`、`FullOfferBlock.swift:129-135`
- 情境：新測試只測純函式。把 `uncover`／`openFull` 改回 `= nil`、把 `restore` 改回直接寫、拿掉 `forget`，測試全綠。
- 怎麼改：把「開頁、關頁、按恢復、狀態變了」四個動作收成 `Purchases` 的方法（`lastNote` 就能 `private(set)`），用一個 `Purchases()` 測。要動到送審檔，這次不做也行，記帳。
- 確定程度：高。

### S3 等核准被拒：有路，但畫面上看不出來
- 檔：`FullOffer.swift:59`（主按鈕是「好」，`showsRestore` false）、`WordsFull.swift:23`
- 情境：Apple 不會通知被拒。付費頁只有「好」，沒有恢復購買；能再買的路是設定頁「恢復購買」→ 沒有找到 → 再進付費頁，或重開 app（記憶體清掉，直接是「購買」）。不會永遠買不了，但他不會知道要按恢復。
- 另一面：還在等核准的人順手按恢復，也會得到「沒有找到購買紀錄」＋「購買」，再買會多送一次核准請求；還沒扣款，兩次都核准 Apple 也只收一次。
- 怎麼改：不改也行（重開就好）。要改是在等核准那句後面加半句「被拒絕的話，按『恢復購買』再買」，字要多米看；不建議另外加按鈕。
- 確定程度：行為高；Apple 被拒不通知是文件與一般說法，沙盒沒驗過。

### S4 付費頁被響鈴拆掉之後，有定論的那句會一直留在設定頁
- 檔：`SettingsPurchase.swift:14-21`；來源是 `Purchases.swift:24` 活得比頁久
- 情境：付完看到「買好了」還沒按好，響鈴拆頁，`onDismiss` 不一定會叫 → 設定頁那一行「買好了，完整版可以用了。」留到重開 app：列已經是「已購買」不能點，`openFull` 清不到，只剩按恢復。L 自己第 5 點有寫，但沒說這種情況清不掉。無害，只是話舊了。
- 怎麼改：`forget` 在剛出現（`initial`）那次遇到 `saysOwned` 也清；或跟 R13 一起記進代決。
- 確定程度：中（SwiftUI 在宿主畫面被拿掉時叫不叫 `onDismiss`，這台沒法驗）。

### S5 付款完成但讀不到紀錄（unconfirmed）＋恢復說沒有
- 檔：`FullOffer.swift:60`、`FullRule.swift:103`
- 情境：手上明明有一筆 Apple 驗過的交易，Apple 又說沒有，於是「購買」出來，句子是「沒有找到購買紀錄」。極少見（交易剛進、紀錄還沒跟上）。
- 怎麼改：可以不改（Apple 擋重複扣款，這格又是出口）。要最保守就只有這一種遇到 `.nothing` 也照 M1 留著，出口剩回前景重問與重開 app。二選一，我建議不改。
- 確定程度：中。

## 記帳
- **N1 這幾種還是看得到「購買」，是原本就定的，不是這次弄壞的**：①買的時候斷線／一般失敗，句子有「有被扣款的話，按恢復購買」，主按鈕「購買」（畫布第 6 題那張表）；關頁後那句清掉。②重開 app：驗不過、讀不到紀錄的記憶都沒了（F2 不存）。Apple 若還留著一筆驗不過的，`start()` 問得到 `.unverified`，但畫面不會說，直接「購買」。③驗不過／問不到的結果不是從這一頁來的（`Transaction.updates` 送來的），沒有句子。
- **N2 SE＋AX5＋有錯誤句，上面清單高度 0**：價格與購買鈕都在，符合這次的目的。不建議留最小高度（會再跟錯誤句搶）；那句關頁就不在了，清單就回來（沒定論那幾種本來就沒有要不要買的問題）。
- **N3 文件**：L 列的詞彙表兩列（第 314、316 列「讀不到價格，點一下重試」跟現在的字不同）、安全標準 F3／F5 都還沒改，確認屬實。

---

## 逐項查過

**編譯**（project.yml 沒設 `SWIFT_VERSION`、沒設嚴格並行，Swift 5 模式，預設並行檢查）
- `@Bindable var shop = shop`：跟 `SettingsData`、`PagerView` 同一種寫法，`$shop.lastNote` 要的 setter 是 internal，成立。`let` 夾在 `body` 裡、閉包抓區域的 `$shop` 都可以。
- `.onChange(of: FullCue(...))` 兩參數、`FullCue` 自動 Equatable（含 `FullNote.id`）、`accessibilityAction(.escape, onClose)` 簽名、`told` 一個 `let` 加 `return`、`words` 用兩次，都成立。
- `priceFailed` 改 private：別的檔沒人用（測試也改掉了）；`fullSample` 沒有殘留。`Purchases.priceFailed` 是另一個。
- 測試：`HostSettings` 是 `@MainActor private struct`，在 `@MainActor` 的 async 測試裡 `defer` 呼叫成立；`FullNoteTests` 沒標 `@MainActor`，碰的都是沒隔離的型別，跟 `FullOfferTests` 一樣。`import UIKit` 有加。`flatMap(\.windows)` Swift 5 模式最多警告。沒有重複宣告。
- L 說「沒把握」的兩處，我看都編得過。**確定程度：高**，不是 100%。

**R1 版面**：外層先給付費塊，扣掉關閉鍵與清單的最小高（0）；付費塊裡先排價格、購買、兩顆，最後才是句子。SE AX5 沒句子：塊約 417、清單約 166；有句子：句子剩約 150 可捲、清單 0；mini 更鬆；iPhone 17 預設字級全部看得到、句子不進 ScrollView。價格在任何一種都完整。句子的 -1 確實需要（不加會跟價格平分）。字高是估的，真機看一次。

**R2 讀寫點**：`Purchases.lastNote` 寫的地方七處（開頁、關頁、忘、設定頁恢復、買前後、付費頁恢復前後、再讀一次），全在主執行緒。走過：買到一半關頁再開（主按鈕是購買中，按不到）、設定頁恢復中開頁、兩下連點（第二下拿 `.busy`，不會蓋掉沒定論的；買的第二下寫 `.busy` 會被第一下的結果蓋掉，順序不會反）、響鈴拆頁後 Task 才寫（Binding 指向物件，寫得到）、恢復找到時 `forget` 先後（兩種順序都剩「已恢復」）、頁開著核准再關（`kept(.owned)` 是 nil）、拆頁期間變 owned（`initial: true` 會清）。`buy()` 前的 `note = nil` 只有主按鈕是「購買」才走得到，那時一定沒有沒定論的。`Purchases` 由 App 建一次，`RootView` 不會重建。
- 進頁時沒定論那句不會重念重震（`onChange` 不跑第一次），看得到、讀屏掃得到，可接受。

**R5**：`doing = nil` 與寫 note 在同一段主執行緒裡沒有等待，看結果不看 `isBusy` 是對的。`onClose` 只是 `isOpen = false`，重複叫沒事。計時中打不開付費頁（分頁列不畫、不能滑），所以「在計時中打開、按取消就被收」不會發生。L 第 6 點（留著有句子的頁）同意。M1 改完這裡不用跟著動。

**R3／R7／R11 測試**：三條殼測試都會過、都會紅：`.clear where applied == .blocked` 時 R3 兩條紅；拿掉 `page = .home` 時 nil 不等於 home；改用 `zenFor != nil` 時 settings 被拉回 home 紅。`stopEarly` 走 `early: true` 不清 `zenFor`，斷言成立。60 分鐘前開始的那顆預設 25 分，`load()` 同一段就到 `.bell`＋`.clear`，不用等拍。R11：`wipeAll` 自己 `forgetShield` 與狀態對齊各解一次，只壞一邊不會紅（不是缺點）；`fullStatus` 被清會紅。
- 污染：三個鍵名對過 VeggieKit（`appearance`、`haptics`）與 `AppShield`；`defer` 順序是殼→場地→宿主，放得回去。前一個測試類別（`AppModelCloudTests`）晚到的觸覺清除可能讓等待提早結束、我們自己那次在還原後才清，雲端模擬器上本來就沒有值，無害。

**R4、R9、R12**：R4 疊圖拿掉，任何寬度不會壓到。R9 掛在容器上有沒有用要真機 VoiceOver，順序不受影響。R12：`.noPrice` 仍以「沒有扣款」開頭，`FullRuleTests:163` 不紅；進頁讀不到那句不提扣款。

**擋板**：這次只動 `setFull` 多記一個 `zenOn`。`loaded` 前 `phase` 是待機，`wasZen` 一定 false；鎖死手機的路跟上一輪一樣沒有，現在有測試。`FullRule.allows`、`Gates.shield` 沒動，沒買能用／買了被鎖沒有新路。

**CI**：沒有超過 100 字的行、沒有行尾空白、檔尾換行對；`FullLockTests` 259 行（上限 300）、類別內文約 165 行（上限 200）。`AppModel+Gates.swift` 工作目錄是 CRLF、索引是 LF（autocrlf），推上去是 LF，SwiftFormat 不會紅。`throws`／`async` 都有用到。註解在宣告前用 `///`、函式裡用 `//`，合 docComments。SwiftLint 自訂規則沒碰到。CI 截圖 22、23 的「範例」位置會變，沒有比對圖。

**超出範圍**：沒有。`HostSettings` 比 R11 最少要的大，但它是為了不弄髒宿主，合理；R6、R8、R10、R13 沒動。
