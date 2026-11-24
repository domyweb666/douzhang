# 回報 K 審查（AI23 付費頁 1C＋購買區 2A＋擋 app 與聚焦的鎖，2026-11-24）

範圍：`git diff`＋未追蹤的 ios-native 檔。只讀，沒改、沒 git 寫入。這台編不了，以下都是讀出來的；XcodeGen 2.46.0 的原始碼有抓下來對。檢查器：check_swift 問題 0、check_refs 沒定義 0。

## 結論
- **編不過的：沒找到。** 金額寫死、正式版後門、沒買能用：沒找到。
- **擋板鎖住手機：程式路徑逐條走過，沒找到鎖死的路。** 缺一條殼的測試（R3）。
- **聚焦模式（ZenClock）：沒變**，逐行對過。
- 必修 1 筆、打包前要處理的 2 筆（不是程式錯）、建議 10 筆。

## 必修

### R1 最大字級在小手機上，「購買」按得到、價格看不到
- 檔：`UI/FullOfferBlock.swift:16-21`、`Screens/FullScreen.swift:17-28`
- 情境：外層 VStack 有兩個會伸縮的（上面清單的 ScrollView、下面這塊），下面這塊只分到剩下高度的一半，放不下就把訊息＋價格一起丟進沒有捲動提示的小 ScrollView。AX5（body 53pt）「付一次就能一直用」折兩行、價格排第三行，這段自然高約 205。算出來分到的高：SE 約 86、mini 約 139、iPhone 17 約 164。SE 與 mini 的價格整個在可視範圍外，iPhone 17 切一半；AX4 在 SE 也看不到。有錯誤句時更早發生（句子排在價格上面，把價格擠下去）。購買鈕照樣能按，違反「沒看到價格不准付錢」（`FullOffer.swift` 自己的註解）與 6-17 第 3 點。
- 怎麼改：①`FullScreen.swift:25` 的 `FullOfferBlock(...)` 加 `.layoutPriority(1)`，讓它先拿滿自然高度，上面的清單讓位（SE AX5 約需 400，有 570 可用）。②`price` 移出 ViewThatFits，放在可捲的訊息下面、購買鈕上面，只讓 `FullLine` 可捲。兩個都做才蓋得住「有錯誤句＋AX5＋SE」。
- 確定程度：中高（VStack 分配規則確定，字高是估的，SE AX5 差距大到估計誤差蓋不掉）。iPhone 17 有沒有切到要看真機。

## 打包前要處理（不是程式錯，順序錯會出事）

### G1 這版一上 TestFlight，產品還沒建好之前聚焦與擋 app 誰都用不到，AI16 就驗不了
- 檔：`AppModel+Gates.swift:77-90`、`SettingsScreen.swift:30`；`.vibe/QC-0003/J-照做清單.md` A、C
- 情境：J-規格包 E 當初不接鎖，理由之一就是「AI16 的聚焦模式也驗不到」。現在有付費頁了，但付費協議沒生效、`org.domyweb.douzhang.full` 沒建，TestFlight 讀不到價格，等於沒有路可以買，也沒有假解鎖（這是對的）。
- 怎麼做：打包前確認 A「有效」＋C-1 到 C-7 做完；或先用 AI23 之前的 commit 打一版讓多米驗 AI16，再打這版。
- 確定程度：高。

### G2 付費頁賣「iCloud 同步」，iCloud 權限還沒加進 project.yml
- 檔：`project.yml:54`、`WordsFull.swift:82`（5-3 承諾句）
- 情境：容器沒勾好時 `url(forUbiquityContainerIdentifier:)` 回 nil，買了的人打開同步只會看到沒在同步的句子。產品一建好就真的買得到，會變成收錢但給不出第一項。TestFlight 測試沒差，送審版不行。
- 怎麼做：寫進送審前條件：容器＋權限＋兩台真機同步走過，才准把這版送審。`.vibe/安全標準.md` 同時補兩處：F3 寫「送審前真機走過再接鎖」，現在鎖先接了，改成「鎖已接，飛航重開沒在真機走過不准送審」；F5 寫「`.storekit` 只在測試 target」，現在執行 scheme 也用（不進正式包，但那句不對了）。
- 確定程度：高。

## 建議

### R2 可能已經付過錢的人，關掉付費頁再進來就又看到「購買」（值得改）
- 檔：`SettingsPurchase.swift:50-61`（`openFull`、`uncover` 都把 note 清成 nil）、`FullOffer.swift:57-64`
- 情境：結果是驗不過、付款完成但讀不到紀錄、等核准 → 按關閉 → 再點「完整版」，主按鈕變回「購買」，可能已扣款那句也不見。`FullNote.main` 的註解寫「不讓他再付一次」，只在沒關頁的時候成立。非消耗性 Apple 一般會擋重複扣款，所以不到必修，但句子跟行為對不上。價格剛好沒讀到時，還會改說「沒有扣款。現在讀不到價格。」，跟剛才的「可能已經扣款」相反。
- 怎麼改：`uncover`、`openFull` 遇到這三種（加一個 `keeps`，`main != nil` 就算）不清 note，直到下一次買／恢復或狀態變 owned；設定頁那一行也就跟著留著（`settingsLine` 已經會在買到後自己不講）。
- 確定程度：高。

### R3 缺「擋板蓋著、重開、還不知道買了沒」之後會解開的殼測試（值得加，最嚴重的那條路）
- 檔：`DouzhangTests/FullLockTests.swift:54-90`
- 情境：規則測了（第 38 行），殼只測「unknown 不動」與「問到沒買就拆」。「unknown＋`applied` 是 unknown＋計時中」→ 作廢／停下來／響 → 真的叫了 clear，沒有測試。有人把 `case .clear where applied != .clear` 改成 `== .blocked` 就會鎖住手機而測試全綠（重開時 `applied` 是 unknown，不是 blocked）。
- 怎麼改：加一個：`open(stage, focusing(...))`，不叫 setFull，`model.stopEarly()` 後 `XCTAssertEqual(model.shield.applied, .clear)`；再一個存檔是已經過了 endAt 的那顆，open 完直接等於 `.clear`。
- 確定程度：高。

### R4 SE 上「範例」壓到「16」的右上角
- 檔：`UI/FullPreview.swift:38-42`、`TokensPages.swift:57-61`
- 情境：寬 335、高 134：數字字級 84（畫布 74），字頭在 y≈24、x 到約 314；「範例」佔 x 293–319、字底 y≈27.5，疊約 3pt。畫布 74 時字頭 y≈27.6，剛好沒碰到，所以是字級跟畫布不同帶出來的。放大模式的 SE、字級放大到 xxxLarge 疊更多。402 寬以上、mini 都沒事。
- 怎麼改：「範例」移到左上或併進下面那行（「範例・寫第三節」）；或 `previewShort` 加高。CI 只拍 iPhone 17，看不到這個。
- 確定程度：中高。

### R5 付款中遇到自動開始下一顆，付完沒有人收這一頁
- 檔：`FullScreen.swift:37-41`
- 情境：只在 phase 變 focus 那一下判斷 `!shop.isBusy`。付款中變 focus → 不收；接著按取消（沒有句子要講）→ 付費頁一直蓋在計時上，違反「做到一半不出現」。
- 怎麼改：再加 `.onChange(of: shop.isBusy)`：變 false 且 `model.phase == .focus` 且這次沒有句子（cancelled／busy）就 onClose；有句子的留著等他看。
- 確定程度：高；很少遇到。

### R6 付款中響鈴，或剛買好時手機橫著拿，付費頁會被整個拆掉
- 檔：`RootView.swift:13-23`、`AppModel+Gates.swift:100-118`
- 情境：響鈴那條回報 K 已寫。另一條沒寫：R5 的情況下買成功 → `setFull(.owned)` → 開始看重力 → 橫拿滿 0.8 秒 → 換成 FocusScreen，PagerView 被拿掉，蓋著的付費頁連同「買好了」一起不見，`onDismiss` 也不保證叫。權益不受影響（status 在 Purchases）。
- 怎麼改：R5 做了就只剩「付完有句子還沒按好」那幾秒，可以不管；要管就讓姿勢進聚焦前先看 `ScreenCover.isOn`。會動到 AI16 的進入條件，建議不動，記帳就好。
- 確定程度：中。

### R7 退款踢出聚焦沒有走 `page = .home`
- 檔：`AppModel+Gates.swift:24-32`
- 情境：其他離開聚焦的路（`leaveZen`）都會設 `page = .home`，這條只清 `zenFor`。計時開始時 `enter()` 設過，捲動位置被拿掉時有沒有寫回 nil 沒法在這台確定；就算是 nil，`defaultScrollAnchor(.center)` 也停在主畫面，所以只是一致性。
- 怎麼改：`setFull` 第一行（換 `fullStatus` 之前）記 `let wasZen = zenOn`，鎖上時 `if wasZen { page = .home }`。不要用 `zenFor != nil` 判斷：響過的那顆記號還留著，會把人從設定頁拉回主畫面。
- 確定程度：低。

### R8 買過的人冷啟動正在計時：下面那排先兩顆、問到了變三顆，會跳一下
- 檔：`HomeScreen.swift:138`
- 情境：unknown 時不畫聚焦鈕，問到 owned 多一顆，另外兩顆往左移。正常零點幾秒，Apple 慢時最多 10–20 秒。6-7 與「冷啟動等驗證上限 2 秒」（多米 2026-11-21 定）這次沒做，回報 K 只講了設定頁。
- 怎麼改：不做也行，記進代決；要做就是 unknown 時留空位、notOwned 才收成兩顆（沒買的人冷啟動計時中會看到一小段空位，也是跳一下，二選一）。兩顆時置中沒問題，`roundColumn` 固定寬，不會撐開。
- 順便：這裡用 `shop.allows`，`enterZen` 用 `model.fullStatus`，兩份差一拍，不影響結果。
- 確定程度：高。

### R9 讀屏「兩指搓」關不掉付費頁
- 檔：`FullScreen.swift:30`
- 怎麼改：VStack 外加 `.accessibilityAction(.escape, onClose)`。順序是對的（第一個焦點是「關閉」，價格那行合成一句，購買中會念新名字）。
- 確定程度：高。

### R10 打開第一格主按鈕是「再讀一次」
- 檔：`Purchases.swift:60`、`FullScreen.swift:32-36`
- 情境：`onChange(initial:)` 裡開 Task，第一次畫的時候 `isPricing` 還是 false → idle → 「再讀一次」，下一拍才變「正在讀價格」。頁還在往上滑，多半看不出來；點到也只是再讀一次、不會付錢。
- 怎麼改：不改也行。要改就在 `idle` 且 `!priceFailed` 時畫 `readingPrice`，並保證打開一定會讀（現在已保證）；`test還沒開始讀也按得到` 要跟著改。
- 確定程度：中高。

### R11 `test清除所有資料不動買了沒` 幾乎永遠過
- 檔：`FullLockTests.swift:139-147`
- 情境：`wipeAll` 裡本來就沒有任何碰 `fullStatus` 的路，這條只在有人故意加才會紅，卻真的跑一次 wipeAll（動宿主的外觀、觸覺、擋板）。
- 怎麼改：改成有意義的：owned＋計時中 wipeAll 後 `shield.applied == .clear` 且 `fullStatus == .owned`。
- 確定程度：高。

### R12 「沒有扣款。現在讀不到價格。」在他什麼都還沒按的時候就出現
- 檔：`WordsFull.swift:9`、`FullOffer.swift:86`
- 情境：打開頁讀不到價格就講「沒有扣款」。對「買過、離線、還不知道買了沒」的人，這句像在說以前那筆沒扣。畫布寫的是「還沒買，沒有扣款」，對這種人更不對，K 改掉是對的。
- 怎麼改：「現在讀不到價格，這次沒有扣款。」或只有按過購買的 `.noPrice` 才講扣款，頁面自己讀不到只講「現在讀不到價格。」。第一句講錢的狀態是 6-18 對「購買流程的結果」的要求，還沒按不算結果。`FullRuleTests` 的 `.noPrice` 開頭要跟。
- 確定程度：中（語感，要多米看）。

### R13 記帳用
- 設定頁那一行沒有收掉的時機：恢復「沒有找到購買紀錄⋯」會留到下次按或重開。3-4「只在要講結果時出現」，其他列是 `noticeMs` 收掉。可接受，建議寫進代決。
- `product.purchase()`、`AppStore.sync()` 不回來（茄記遇過）時，`doing` 會卡到重開 app 為止，購買與恢復都按不了。照 6-11 不設時限，不改。

## 逐項查過沒問題的
- **XcodeGen**：2.46.0 的 `run.storeKitConfiguration` 是字串，`schemePathPrefix` 預設 `../../`（不是 `../`），組出 `../../DouzhangTests/Full.storekit`，非 workspace 專案正確；檔在。`run.config: Debug` 是原本的預設。archive 不讀執行動作；`xcodebuild test` 與 `simctl launch` 不會套用，`PurchaseTests` 照舊要環境變數才跑。
- **編譯**：`switch` 的 Optional 列舉樣式（`note?.result`）、`told?.main ?? …`、`BigButton` 尾隨閉包、`ZenClock` 的 `@ViewBuilder` 儲存閉包與預設 `gap`、`.haptic` 收 `FullNote?`、`accessibilitySpeechAnnouncementPriority`（iOS 17、要 `import Accessibility`，有）、`action: value == nil ? { openFull() } : nil`、`private(set) var applied`、`fileprivate var main` 同檔用，都成立。`TextTone` 沒有別處窮舉。VeggieKit 1.0.1 的 `purchase／restore／restored／restoreNothing／restoreFailed`、`VeggieRow.Accessory.none` 都有。
- **擋板**：殺掉重開 unknown＋計時中＝不動；響、作廢、停下來、休息、延長後再響、清除、匯入、壞檔（空白待機）、關開關、換日，`shouldShield` 都是 false → `.clear`，而 `applied` 是 unknown 或 blocked 都會真的叫系統。計時中問到沒買、退款 → 拆。問不到一直 unknown：最多擋到這顆結束、打開 app 那一刻（原本就有的取捨）。授權到一半退款、選 app 到一半退款：設定會存，不會蓋。沒有 owned／notOwned 變回 unknown 的路，蓋上之後不會卡在「不動」。
- **買了卻被鎖**：離線、逾時維持已知；買完用手上那筆；退款走再看一眼；回前景重問。冷啟動離線 Apple 回空 → notOwned → 這次打開全鎖、正在擋的會拆，是 F3 已知風險，只有真機驗得到（G2）。
- **沒買能用**：聚焦三個入口（鈕、橫放、`zenOn`）都過 `zenAllowed`；`zenFor` 在非 owned 一律清掉，買回來不會自己轉橫；感測器沒買不開。沒有 DEBUG 當成買了；`DOUZHANG_PAGE=full` 只開畫面、正式版讀不到。
- **ZenClock**：`fruit／room／size／spacing／frame／number` 六項與原本逐字相同，`gap` 預設就是原本的 `section`，`screen／width` 傳的是原本那兩個值；`GrowingTomato` 參數沒變；多一層 View 不影響 VStack 間距與數字動畫。`FocusScreen` 其他行沒動。
- **重複點／付款中關閉／疊框**：第二下拿到 `.busy` 不講話；付款中關掉，Task 抓的是設定頁的 Binding，結果寫在設定頁；頁裡沒有 alert；`CloudAsk` 用 `ScreenCover.isOn` 等這頁收掉才問，不會被吞。
- **左右滑頁**：PagerView 是 HStack 不是 Lazy，cover 掛在離屏頁也開得了，跟 HomeScreen 的刻度尺同一種；環境會帶進 cover。
- **深色**：都走 Tokens，預覽黑底有髮線框。**金額**：程式沒有；290 只在測試用的 `.storekit`。
- **測試隔離**：`FullLockTests` 真的叫 ManagedSettings、ScreenTurn、`isIdleTimerDisabled`，但斷言那段沒有 await，宿主 app 插不進來；結尾都回直向、解開。`FullOfferTests` 每條改壞都會紅。
- **CI 截圖**：22、23 的欄位順序對；`exit` 路徑沒有新的失敗點；03、14 變兩顆、12 少「專注」一區，沒有比對圖，不會紅。拍到讀價格中或讀不到都算正常。

## 跟回報 K 對照
K 說的都對得上程式，兩處說得太滿：「三種都只給恢復購買，不給再買」只在沒關頁時成立（R2）；「ViewThatFits 最大字級要看真機」算得出來會藏掉價格（R1）。
