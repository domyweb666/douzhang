# 工作包 I 施工規格（多米 2026-11-24 回覆四題）

多米原話：
1. 「設定頁：缺的列（外觀、觸覺、iCloud、購買、支援、關於、頁尾等）要不要加，VeggieKit 要不要接？做」
2. 「『長大』：主要是看著感覺不對勁，只變色倒是還好，但是一直變大會有點煩，除非它變大的動畫是很柔順的，因為目前看起來他都是跳著變大的。要變化可以但是動畫得調」
3. 「補數字，以及想一下如果超過13顆後該如何顯示，畫一張畫步給我挑選」
4. 「說明字：其他畫面還留著的…拿掉」
push 沒提 → 不推、不打 tag、不打包。

所有人照 `計畫.md`「所有人都要守」＋「補充」。HEAD＝ea044e9。不准任何 git 寫入動作。改檔用 Edit／Write，不用 heredoc python。共用檔（Words*、Params、Tokens*）Edit 前一刻重讀、最小插入。

## 包 S：設定頁補列＋VeggieKit（檔：project.yml、Screens/Settings*、UI/SettingsParts、App/新檔 VeggieSetup.swift、DouzhangApp、RootView／Controls／MinuteRuler／TabBar／JarSounds 的震動那幾行、AppModel+Backup 的匯入確認、Assets、PrivacyInfo、測試）
先讀 `E:\多米ios開發準則\book\03-設計準則.md` 3-3 到 3-12（46–150 行）、`E:\VeggieKit\README.md` 與 `Sources`（只讀不改）、`E:\人篸修煉\ios\Rencan\App\VeggieSetup.swift`、`Services/HapticsService.swift`、`Views/Settings/*` 的接法。
- `project.yml`：`packages: VeggieKit url https://github.com/domyweb666/VeggieKit exactVersion 1.0.1`（遠端 tag 已確認存在、公開），只有 Douzhang target 依賴。規矩檔 P4 禁第三方 SDK：這是自家、不連網，檔頭一行註解寫明。`check_swift.py`／pre-commit／`testflight-native.yml`／CI 若有擋 `url:` 或鎖套件的規則，照最小改。
- `VeggieConfig`：name「番茄帳」、slug `fanqiezhang`、tagline 從產品定稿取一句短的（AI 味禁）、appStoreID nil（repo 裡找不到 Apple ID，等多米給）、supportEmail 照 VeggieKit README 的共用信箱、privacyURL nil（沒有網頁）。
- 順序：app 專屬 → 一般（外觀三選一、到點通知、觸覺回饋、聲音）→ 資料（匯出資料、匯入資料、清除所有資料）→ 支援（意見回饋、分享給朋友；評分因沒有 Apple ID 自動藏）→ 關於（蔬菜家族的其他 app；隱私權政策 nil 自動藏；開源授權：查實際有沒有要列的第三方，沒有就整列藏）→ 頁尾 `VeggieFooter`（要一張 logo 圖：看 Assets 的 AppIcon，人蔘怎麼做就怎麼做）。
- 每一列都要圖示（SF Symbol，iOS 17 有的），全部換 `VeggieRow`／`VeggieToggleRow`；app 專屬那些列也要圖示（標籤列用它的番茄）。`.veggieStyle` 接番茄帳的代號。字用 `VeggieText.*`（匯出備份→匯出資料、清空→清除，相關確認字一致）。
- 外觀：開 app 套一次、選完立刻生效（聚焦模式照舊黑底）。觸覺：全部震動（sensoryFeedback、UIImpactFeedbackGenerator）先看 `VeggieHaptics.isEnabled`，做成一個自己的小 modifier，改開關要立刻生效。清除所有資料時把 `Appearance.storageKey`、`VeggieHaptics.storageKey` 一起清、外觀立刻回跟隨系統。
- 匯入：現在是整份換掉。驗過格式後，確認框先講「這份有 N 天、M 顆；會換掉現在的 X 顆」（純函式算＋測試），按了才寫。
- 不做：新功能卡（第一版沒有內容，3-4 值空不出現）、評分彈窗、購買區與 iCloud（等多米，見包 R）。
- 設定頁 NavigationStack：左右滑三頁裡怎麼推下一頁（家族、授權）自己挑最穩的（sheet 內包 NavigationStack 也行），不准影響左右滑與分頁列。

## 包 T：說明字拿掉＋鈴響補數字（檔：UI/{FocusSheets,TagSheets,SoundSheet,DoingSheet,SheetCard,StatsPanel,BellReceipt…}、Screens/{HomeScreen,HomeIdle,RackScreen,TimeDialScreen}、Words*；不碰包 S 的檔）
- 先盤點全 app 剩下的常駐說明字（副標、提示、解釋怎麼用的小字），列表寫進回報：檔:行、原文、拿掉或留、為什麼。準則 3-4：說明只在出了狀況、要講結果時出現。**拿掉**：半頁副標（`endSub`、`endSubEarly`、`voidSub`、`doneEarlySub`…）、教學句、統計頁解釋句。**留**：出錯、權限狀態、確認破壞性動作的框、空狀態的一句話、資料本身（日期、顆數、你平常 4 到 6 顆）、讀屏用的 label／hint。拿掉後沒人用的字與參數刪乾淨。
- 分析頁的字可能是 `.analytics` 設計定的（圖表標題、結論句是資料不是說明），不確定就留並列出。
- 鈴響補數字：第 13 顆起（小番茄畫不下全部時）「今天」列把總數「N 顆」寫出來；12 顆以內照舊只畫番茄。版面之後等多米挑畫布再換，這次最小改。

## 包 P：畫布（不碰程式）
- 用 Artifact 工具做（先 quickstart intent design；artifact-design 技能照規矩讀）。一張新畫布，繁中，標題「鈴響 13 顆以上與番茄變大」。尺寸、番茄、收據樣式照 `.uiux/03-線框/2026-11-24-QC0003-選項.html`（fig14＝4B 收據）與 `ios-native/Douzhang/UI/BellReceipt.swift`、`Design/TokensPages.swift`（Bell）、`Tokens.swift`。
- A 鈴響收據「今天」：每個選項畫 5、12、13、20、30 顆，寫一句取捨、標推薦。方向自己想 3–4 個（例：一律最後 12 顆＋左邊總數；十顆一把的大番茄；番茄縮小排滿；一排疊成一串＋數字），要有總數字、5 顆時維持多米喜歡的小番茄、SE 放得下、不跟昨天比、不催促。
- B 番茄變大：可以動的比較（同時跑、有「重播」與快轉），計時中環內那顆：B0 以前的跳法（每秒一格、沒動畫，尺寸對到像素所以會抖）、B1 只變色（現在的程式）、B2 一路連續柔順變大（每格都畫、縮放不重排）、B3 平常不動、分五次彈簧長一下。尺寸從 0.4 成長到 1（舊 `growMinScale` 去 `git show 99f4c5a:ios-native/Douzhang/Design/Params.swift` 查）。畫布元件若不能動，就另外做一頁私人 HTML artifact，兩個連結都給。推薦 B2 或 B3 自己判斷並說理由。
- 本機備份 `.uiux/03-線框/2026-11-24-I-選項.html`，雙擊就能看也能動；用無頭 Chrome 截圖看過（不要用多米的 Chrome）。文字版寫 `.vibe/QC-0003/I-設計選項.md`。

## 包 R：iCloud 與購買的提案（只讀，不碰程式）
看蒜日子、茄記 Swift 版、人蔘修煉怎麼做 iCloud 同步與內購（`E:\蒜日子`、`E:\茄記\qieji-swift`、`E:\人篸修煉`），番茄帳的存檔（`Core/AppState`、`App/StateFile`、`BackupFiles`）與 `.vibe/安全標準.md`（離線、無網路、無金流）、產品定稿。寫 `.vibe/QC-0003/I-iCloud購買提案.md`（60 行內）：iCloud 推薦做法（哪種 API、合併規則、幾天工、動到哪些檔、要多米在 Apple 後台做什麼、哪一步不能還原、要改哪份標準）；購買：番茄帳有沒有定過收費模式（找 .vibe、.uiux、.aso），沒有就列 2–3 個選項＋推薦＋要多米填的（價格、鎖什麼、產品 ID）；Apple ID 與隱私權政策網頁怎麼補（網頁 repo 在哪、其他 app 的頁長怎樣）。
