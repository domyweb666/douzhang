# 包 JB 修正＋JE2 接線 審查（2026-11-24，只讀不改，沒有 git 寫入；先讀程式與測試，最後才看回報-JB、回報-JE2）

## 結論
- **必修 3 筆**：M1 編譯（可能編不過，兩行）、M2 不可逆的刪（已知那筆，範圍比回報寫的大）、M3 沒開同步的人也會遇到的番茄堆退步。
- 除了 M1，逐檔對過協定見證、隔離、Sendable、窮舉、import，**沒找到會編不過的**。SwiftLint 自己數過都在線內（`CloudLink` 本體 198 行，線是 200）。SwiftFormat 沒看到確定會紅的，換行只能讓 CI 跑。
- check_swift 0、check_refs 沒定義 0（重跑過）。雲端沒跑，測試是用讀的推。
- JB 審查 R1–R5、S1–S4、S6–S9、E1 **都真的修好了**；S5 只做①（JB 有寫，可以接受）。修正引進的新洞是 M2 的 `erasePending` 那半，加上 A1、A2。

## 必修

### M1 預設參數用了主執行緒的 `.standard`，Swift 5 模式可能直接報錯
- `App/AppModel.swift:82` `cloud: CloudLink = .standard`。`CloudLink.standard`（`AppModel+Cloud.swift:48`）寫在 `@MainActor` 類別的 extension，是主執行緒隔離的。
- 為什麼：預設參數可以跟函式同隔離，是 SE-0411 的 `IsolatedDefaultValues`；Swift 6 模式才一定開。Swift 5 模式（本專案用 XcodeGen 預設的 5.0，沒開 strict-concurrency）預設參數當成不隔離，會報 `main actor-isolated static property 'standard' can not be referenced from a nonisolated context`。旁邊的 `StateFile.standard`、`BackupFiles.standard` 是不隔離的 struct，不能當先例；本專案、米說、茄記、瓜相都沒有同樣寫法編過。
- 怎麼改：
  ```swift
  init(file: StateFile = .standard, backups: BackupFiles = .standard, cloud: CloudLink? = nil) {
      self.file = file
      self.backups = backups
      self.cloud = cloud ?? CloudLink.standard
  }
  ```
  `??` 右邊是不會跑掉的 autoclosure，跟著 init 的隔離，各版編譯器都過。測試照舊傳 `cloud: phone.link`，不用改。
- 嚴重度：必修（改兩行，不改就是賭一輪 CI）。確定程度：會不會紅＝中；改法一定過＝高。

### M2 不知道是哪個 iCloud 時照刪（不可逆）：不只「帳本讀不到」，「這支根本沒有帳本」也會
- `App/CloudLink+Erase.swift:75-77`（`eraseTarget` 落到空字串）、`:88`（空字串＝`erase(for: nil)`，不比帳號）、`:53-63`（`wipe` 先把讀不到的帳本刪掉，之後永遠不知道是誰的）、`:36-38`（`hasCopy` 只要 `isOn` 就算有）。
- 情境 A（JB 記的那筆）：帳本一時讀不到 → 「也刪掉」刪的是現在登入的那個人的 `Records/`。
- 情境 B（更容易）：換機還原、手機轉給別人。`cloudSync` 跟著還原、帳本沒有 → 停在 `.restored` 或按了「先不要」→ 到設定按清除所有資料 → `isOn` 所以問「iCloud 那份也要刪掉嗎」→「也刪掉」→ **這支手機從沒放過東西，卻刪掉現在登入的人在所有手機上的那份**。
- 情境 C：打開同步但沒登入 iCloud、從沒傳過 → 清除選「也刪掉」→ 失敗，留下空字串的 `erasePending`，「沒刪成」那句一直在；之後登入任何一個帳號再點，就把那個帳號的刪了。
- 怎麼改（讀不到就不刪、說沒刪成；沒帳本就沒有要刪的）：
  ```swift
  /// 要刪的是哪個 iCloud。
  private enum Target { case none, unknown, known(String) }

  /// 帳本對的那個；帳本已經忘了就是上次說要刪的那個。帳本讀不到就不知道是誰的：不准刪。
  private var eraseTarget: Target {
      let pending = erasePending.flatMap { $0.isEmpty ? nil : $0 }
      do {
          if let identity = try (ledger ?? ledgerFile.read())?.identity {
              return .known(identity)
          }
      } catch {
          return pending.map { .known($0) } ?? .unknown
      }
      if let pending { return .known(pending) }
      return erasePending == nil ? .none : .unknown
  }
  ```
  1. `wipe(erasing: true)`：`.known` 照現在；`.none` 當成 `erasing: false`；`.unknown`：關同步、`erasePending = ""`、**帳本檔留著不刪**、`problem = .eraseFailed`、不叫 drive。`eraseCloud` 同一套，`.none` 直接回 true，`.unknown` 回 false。
  2. `erasePending` 的註解改：空字串＝要刪但不知道是哪個，不准刪，等讀得到帳本。
  3. `CloudDrive.erase(for:)` 的參數改成 `String`（不給 nil），`ICloudDrive.erase` 的 `if let` 拿掉，`FolderDrive`、`NoCloudDrive` 跟著改：編譯器就守得住。
  4. `hasCopy`：`erasePending != nil`，或帳本在而且（`seen` 或 `isOn`），讀不到照舊當有。單看 `isOn` 的那條拿掉。`AppModel+Backup.swift:93` 的條件改 `cloud.isOn || cloud.hasCopy`，不然沒帳本但開著的人清除時不會關同步。
  5. 測試：帳本 0o000 時 `wipe(erasing: true)` → `stage.hasCloud`、`.eraseFailed`、帳本檔還在；改回 0o644 再 `eraseCloud` → 刪掉。換機還原（`ledgerFile.remove()` 後 `open`）→ `hasCopy` false、`wipe(erasing: true)` 後 drive 的 `erase` 沒被叫、雲端還在。
- 嚴重度：必修。確定程度：高。

### M3 番茄堆：清除或匯入時，排隊還沒掉的那顆沒清掉，會掉一顆幽靈番茄（沒開同步的人也會）
- `UI/JarScene.swift:95-107`（`join` 兩條路都沒清 `pending`）、`UI/JarView.swift:43`（清除、匯入時 `seen` 是 nil，所以走 `drops: false`）。改之前這裡是 `pending = []; seed(next)`。
- 情境：收下一顆 → 休息中滑到設定 → 休息到點，待機的番茄堆掛上、排了一顆 0.18 秒後掉；停在別頁是凍著的，這顆一直在 `pending` → 按清除所有資料（或匯入）→ `follow([], drops: false)` → `join` 的 guard 沒過 → `seed([])` 但 `pending` 還在 → 回主畫面，**清空的番茄堆掉下來一顆**（番茄架是 0 顆）。匯入的話：把匯入那份的最後一顆拿掉，掉下來的是清除前那顆的大小與顏色。正在掉的（`falling`）同理。
- 怎麼改：`join` 要確定「排著的、正在掉的」就是新清單的最後一顆，不是就整份重擺：
  ```swift
  private func join(_ next: [JarBean]) {
      let falling = world.bodies.last(where: \.fresh)
      let waiting = pending.last?.bean
      let color = falling.flatMap { colors[$0.id] }
      guard let mine = next.last, waiting == mine || (waiting == nil && color == mine.color) else {
          pending = []
          seed(next)
          return
      }
      …原本的
  }
  ```
  這樣清除一定乾淨；匯入只有剛好同長度同顏色才會接著掉，看起來一樣。更乾淨的是殼分清楚「整份換過」（匯入、清除）和「合併」，但要多一個旗標；上面那個就夠。
- 加測試：`mounted(seen: 0)` 之後 `follow([], drops: false)`、`advance` → `bodies` 是空的；`follow([別的顏色], drops: false)`、`advance` → 一顆、不是 fresh。
- 嚴重度：必修（沒買、沒開同步的人也會，手感規矩）。確定程度：高。

## 建議（值得改）

- **A1 同一個問題連問兩次，第二次不會跳**：`Screens/CloudAsk.swift:15` 的 `.task(id: question)`。框開著時換成第三個帳號，按「放進去」→ `question` 變 nil、幾毫秒後又變 `.account`；SwiftUI 合成一次更新時 id 沒變，`follow` 不重跑，`isShown` 已經是 false → 停著沒有框、也沒有設定列那句，要重開 app。改：`CloudLink` 加 `private(set) var asks = 0`，`ask` 裡 +1，`.task(id: model.cloud.question == nil ? 0 : model.cloud.asks)`。程式路徑高、發生很低。（加在 `CloudLink+Switch` 拿不到儲存屬性，要放本體：本體剩 2 行，順手把一個方法搬去 extension。）
- **A2 刪雲端前那一眼逾時，晚點會把別人的查詢關掉**：`CloudCatalog.swift:33-37`。`glance` 被 15 秒時限放生後還在等；這時使用者又打開同步（同一個查詢在用），等收齊時 `defer { unwatch() }` 把 `onNotice` 清掉、查詢停掉 → 那趟拉丟 `.stopped`，之後雲端的動靜都聽不到，要等回前景。沒再打開的話，查詢會沒人聽地一直跑。改：`defer { if onNotice == nil { unwatch() } }`；時限到了由 `erase` 叫一次同樣的收尾。高、低。
- **A3 整趟 60 秒到了就當拉完**：`CloudLink+Transfer.swift:56` break 之後照樣 `isDone = true`。沒讀到的檔要等下次回前景或清單變。改：`fetch` 沒讀完時不設 `isDone`（`lastNoticed = nil`）再 `pullSoon()`。不丟資料。高。
- **A4 app 被系統暫停的時間也算進「隔 10 秒再看」**：`CloudLink+Account.swift:101`。進背景那次傳看到空的 → 一小時後回前景，`becameActive` 馬上拉，差值早就超過 10 秒，但 iCloud 這段根本沒機會更新清單 → 誤問「iCloud 裡的番茄不見了」。改：`becameActive` 先 `emptySince = nil`；測試的 `lookAgain` 改用 `requestPull()` 才不會被清掉。高（路徑）、中（發生）。
- **A5 每個人打開 app 多一次 `identifierForVendor`**：`CloudLedger.swift:48-53`，在 App 建立時就問系統（第一次是跨程序同步呼叫，通常幾毫秒、沒量過），而且拿到 nil 就整次打開都是 nil（還沒解鎖過就被叫起來時）。沒開同步的人用不到。改：`phone` 換成 `var phone: () -> String?`（或 lazy），真的要讀寫帳本、記 `erasePending` 時才問。順便修：`erasePending` setter 在 phone 是 nil 時把「要刪」整個丟掉（`Erase.swift:17-19`）。高（有多做）、影響低。
- **A6 測試**：
  - `AppModelCloudTests` 叫真的 `wipeAll`：會動測試宿主的 `UserDefaults.standard`（外觀、觸覺、選過的 app）與 `ManagedSettingsStore`，現在沒有別的測試讀這幾個所以不會紅；寫一行註解，之後誰加這類測試才知道。不碰真 iCloud、`cloudSync` 用的是各自的 suite，乾淨。
  - `CloudFilesTests.swift:176` `run(1)`：一秒內 `.utility` 佇列沒輪到，這件就作廢，「開始寫」永遠等不到。放寬到 3。機率低。
  - M2、M3 沒有測試；`AppModelJarTests` 沒有一則從 `JarView` 的 `drops: seen != nil` 走（純殼測得到的只有 `jarSeen`），清除／匯入那條靠 M3 的 JarScene 測試補。
  - 其他逐則推過：沒有永遠過的；0o000／0o555 在 CI（非 root）成立；`NSFileCoordinator` 同程序兩個實例會互等（文件行為），真紅了就先看那五則。
- **A7 提醒給多米定，不是錯**：同步開著時匯入一份舊的，別台會把現在的又合回來（`replaceAll` 之後照樣 `saved()`），使用者會覺得匯入沒用。出貨前在匯入確認框或流程上給一個說法。

## 查過、沒事（不用再查）
- **沒開同步的人**：`commit`／`replaceAll`／`becameActive`／進背景多的是兩三個 Bool 判斷就回（`allowed` 第一關就擋），不比對整份、不建背景時間、不碰檔案。打開 app：`ICloudDrive()` 只建一條佇列與一個空物件、`CloudLink` 讀一個開關、`start` 讀一個 UserDefaults 陣列；**一個 iCloud API 都沒叫**，所以沒有 entitlement 也不會有例外或警告。真的叫到時 `url(forUbiquityContainerIdentifier:)` 回 nil，後面 token、查詢都走不到。
- 匯入：先備份、備份不成那句、確認換掉都跟原本一樣。清除：多一次「帳本在不在」，沒有就兩個框照舊、同樣排到下一拍。
- 收番茄：`jarFresh` 跟 `commit` 同一次更新，單機時最後一顆本來就是它，順序不變；`jarBeans` 的成本跟原本一樣。清除／匯入後下一顆會掉下來（原本不會，是順帶修好）。
- `RootView` 讀 `shop.status`：只在 unknown→答案那一次重算，三頁的參數沒變不跟著重算；`refresh` 沒變不寫。
- 框：`CloudAsk` 等畫面空著才跳；`SettingsCloud` 關掉時同步的問題已經收掉；清除三個框各隔一拍。剩下的縫是框與框交替的那一拍剛好被 250 毫秒輪詢碰到，只有開同步的人、機率極低。
- 編譯：`FolderDrive`（@MainActor）當 async 協定見證、`NoCloudDrive` 靠預設實作、`[weak self]`＋隱含 self、`Result<Void, Error> { }`、非逃逸 `check` 被 NS_NOESCAPE 的 accessor 抓、`MainActor.assumeIsolated`（跟 PoseWatch 同寫法）、`case any`／`.none` 的推斷、三元運算子轉協定型別、`private` 跨檔可見性、switch 窮舉（含 `.eraseOther`、`.restored`）：都對。`XCTAssert…(try …)` 有既有先例，hoistTry 不會紅。
- 丟資料：`isHollow` 換編號、`isGone` 不補寫、`write` 不開資料夾、帳本先寫旁邊再換、讀寫刪都在 accessor 裡再比帳號、拉的期間本機變就重合：都推過。
- project.yml、PrivacyInfo 只有註解；iCloud 權限沒加，符合規格。

## 修了（2026-11-24，另一個代理；本機編不了，測試一則都沒跑過；沒有 git 寫入）
check_swift 0、check_refs 沒定義 0、check_words 0；每檔 300 行內、型別 200 行內（`CloudLink` 本體把「雲端的動靜」搬到同檔 extension）。
- **M1** 照改。**M2** 三條路（關掉、清除、再按一次，含退款後）都走 `eraseTarget`；比審查嚴一點：帳本讀不到時，就算上次記得是哪個也不刪（那個留著）。另修一個洞：`ICloudDrive.erase` 登入別的帳號、那裡是空的會當成刪好了，改成先比帳號。沒刪成用既有那句，沒加字。測試 `CloudEraseGuardTests`（9）、`AppModelCloudTests` 加 1。
- **M3** `join` 照改。審查的第二則測試光改 `join` 過不了（顆數一樣不會進去），所以 `drops: false` 時改看內容有沒有變；別台改標籤顏色合進來時，整堆會重新安置一次。JarSceneTests 加 5。
- **A1** `asks`。**A2** `endGlance`，`glance` 抽成一支。**A3** 記 `unread`，下一趟從它接著讀（從頭重讀的話一直逾時會讀不完），一趟至少一個檔。
- **A4** 進背景就不算、也不問（`isAway`），回前景從頭算：只在回前景清的話，醒來那一刻 10 秒的計時先響，還是會誤問。**A5** `phone` 改成要用才問；問不到時「要刪」先記空的。**A6** 註解、`run(3)`。測試各補 1–2 則，A2 的逾時那半沒測（要真的查詢）。
- A7 沒動。文件改五句：切片帳本 AI21 沒把握那行、黃金 223 與 224、安全 P5 與 N6。操作清單沒有不一致的。
