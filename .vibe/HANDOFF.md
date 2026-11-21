# HANDOFF（2026-11-21 23:34）：番茄帳 SwiftUI 版整個搬完、雲端全綠、手機沒開過；手感指南對照完，七處要補，等多米點頭

> 給下一個新會話的交接便條。先向多米摘要「上次做完什麼、卡在哪」，等他點頭再動工。
> 真相源：根目錄 `OVERNIGHT.md`（早上摘要、待確認八條）、`.vibe/切片帳本.md`「AI 轉 SwiftUI」那節（切片與代決二十二條）、`.vibe/規矩檔.md`。
> 上一份便條（Expo 版 AG、AH、AF 的細節都在裡面）備份在 `.vibe/handoff/archive/HANDOFF-2026-11-21-2334-replaced.md`。

## 一句話現況
番茄帳從 Expo 轉成 SwiftUI，新程式在 `ios-native/`，分支 `overnight-20261121-2033`。雲端 `ios-native-ci.yml` 全綠（格式、規矩、編譯、186 條測試、15 張模擬器截圖），最後一輪 run 44914577723。**手機上一次都沒開過。** Expo 版 `douzhang/` 一行沒動，還在 TestFlight 上（1.0.0 build 6）。

分支位置：`origin/overnight-20261121-2033` 在 a381599；這份便條的 commit 只在本機、還沒推。`uiux-graybox` 本機在 e2bd12d、遠端在 5891d11。都還沒合併。

## 這次完成了什麼（2026-11-21 一天）
- 白天：多米說「我要轉成 SwiftUI」「直接開始轉」（沒先驗 Expo 版的 AH1–AH15）。做完 AI1：骨架、狀態機、狀態檔讀寫、約 110 條測試。
- 晚上：多米說「先一次全做好再推，然後熬夜做」。做完 AI2–AI9：算法、設計代號、殼、主畫面四態、番茄堆、番茄架、設定與備份、聚焦模式、白噪音、擋 app、icon、隱私清單、新的 TestFlight 流程。
- 推上 GitHub 三輪到全綠（第一輪編譯就過，紅的是排版格式與一條寫錯的測試）。
- 加了模擬器截圖走查：雲端每次把 15 個畫面截圖存成 `screens` 那一包。逐張看過，修掉一個版面問題（番茄架空狀態標題掉到中間）。這次的圖在 `.vibe/overnight-screens/`。
- 讀了多米給的《SwiftUI 蘋果風格手感指南》，對照現在的程式，列出七處不合與四處定案（見下一節）。**只盤點，沒改程式。**

## 還沒做完／待決定

### A. 手感指南的七處（多米看完清單後說「先寫 handoff」，還沒回要不要做）
指南原檔在 `C:\Users\fcharlie\Downloads\SwiftUI-蘋果風格手感指南.md`，還沒搬進任何 repo。多米還沒說要放哪（我提議 `E:\domy-design`）。動工前先重讀它，特別是第四節的動作代號表。

不合、建議補的七處（我建議一批做完跑一輪雲端）：
1. 數字直接跳：倒數時間、番茄架那行小計、分析的數字，加 `.contentTransition(.numericText)`。
2. 每顆主要按鈕都震（`UI/Buttons.swift` 的 `BigButton`）：改成只在有意義的時刻。收下 `.success`；作廢、刪標籤、清空用輕的 `.impact`；存不進去、匯入讀不懂 `.error`。切換選項的 `.selection` 留著。
3. 資料變化沒動畫：換檢視、加刪標籤、設定列出現消失、鈴響頁選填輸入框展開。
4. 動畫寫死秒數：`UI/Buttons.swift` 按壓、`Screens/FocusScreen.swift` 翻牌與三顆鈕淡入，換成 `.snappy`／`.smooth`。`Screens/HomeRings.swift` 進度環的線性補間留著（時鐘該等速）。
5. 動作代號表：在 `Design/Tokens.swift` 的 `Motion` 加按壓、變化、轉場、慶祝四個代號，畫面只准從這裡拿；`.swiftlint.yml` 加規則擋寫死的曲線。
6. 收下那一刻沒有慶祝：`Screens/BellScreen.swift` 那顆番茄出現時 `.bouncy` 一下，只在那一瞬間。
7. 空狀態是自己排的：番茄架與分析的空狀態改用 `ContentUnavailableView`，字照舊。

跟指南不同、但是多米定案過的四處（**不要自己動**，他說要改才改）：
- 三頁左右滑加懸浮分頁列（指南說 `TabView` 別自訂；11-01、11-14 定的）。
- 設定頁是自己排的白卡不是 `List`（Domy 設計系統的樣子）；標籤沒有左滑刪除、拖曳排序。
- 按壓縮到 0.97、變淡到 0.6（指南是 0.96、0.85；數字來自 `domy-design`，改了會影響其他 app）。
- 懸浮分頁列是實心白底加影子，不是毛玻璃。

下一步框裡問的是「要照指南把這七處手感補上嗎」，兩顆鈕是「照建議做」「連定案一起改」。多米沒按。

### B. `OVERNIGHT.md` 的待確認八條（都還沒回）
最要緊的三條：
- 要不要打一包上 TestFlight 真機驗（推 tag `tfn-1` 就會打包，build 號 101 起跳）。裝上去會直接換掉 Expo 版，裝之前請多米先在 Expo 版匯出備份。
- 已拿掉的功能留在存檔裡的舊欄位要不要留（現在不讀也不寫回去）。
- `.vibe/規矩檔.md` 的憲法寫的是 Expo，要補 SwiftUI 那段。改之前要先給多米看現況。

### C. 完全沒驗到的（截圖拍不到）
所有半頁、聚焦模式、番茄堆的掉落傾斜點彈與聲音、到點通知、白噪音在背景、擋 app、匯出匯入的系統畫面、從 Expo 版搬舊資料（只用假造的檔測過）、`testflight-native.yml`（沒跑過）。

### D. Expo 版留下的
AG1–AG25、AH1–AH15、AF1–AF12 的手機驗收都沒做。現在轉 SwiftUI 了，這些清單要不要改成對 SwiftUI 版驗，還沒跟多米談。清單在 `.vibe/操作清單-待驗.md`。

## 關鍵決策（定下來的，別再爭論）
- 番茄帳改走 SwiftUI，新功能寫在 `ios-native/`，不再往 Expo 版加東西。Expo 版留著當對照，功能在真機上驗過才退場。
- Bundle ID 沿用 `org.domyweb.douzhang`，狀態檔格式沿用，第一次打開從 Expo 的存檔把資料搬過來、舊檔不刪。
- 工具鏈照米說：XcodeGen、SwiftFormat 0.64.0、SwiftLint 0.65.1 `--strict`、最低 iOS 17、不裝第三方套件。
- 原本編 Expo 版的 `testflight.yml` 不動；SwiftUI 版另一條 `testflight-native.yml`，tag `tfn-*`。
- 只 commit。推上去、打包 TestFlight 都要多米開口（昨晚的推是他說「全做好再推」）。
- 核心、產品面的定案沒變：種番茄＋時間帳本、不做正計時、不做連續天數、不製造罪惡感。

## 下個會話最重要的檔案
- `OVERNIGHT.md` ← 早上摘要與待確認
- `.vibe/切片帳本.md` ←「AI 轉 SwiftUI」那節
- `C:\Users\fcharlie\Downloads\SwiftUI-蘋果風格手感指南.md` ← 做 A 之前重讀
- `ios-native/.swiftlint.yml`、`ios-native/.swiftformat` ← 寫 Swift 之前看
- `ios-native/Douzhang/Design/Tokens.swift`（`Motion` 在這）、`UI/Buttons.swift`、`Screens/HomeRings.swift`、`Screens/BellScreen.swift`、`Screens/RackScreen.swift`、`UI/StatsPanel.swift`、`App/AppModel+Actions.swift` ← 手感七處會動到的
- `.vibe/overnight-screens/` ← 15 張截圖

## 下一步從哪繼續
1. 摘要一句給多米：「SwiftUI 版搬完、雲端全綠、有截圖，手機沒開過；手感指南對出七處要補，等你說做不做。」然後問 A：照建議做七處，還是連四條定案一起改。
2. 多米說做：重讀指南 → 先在 `Tokens.Motion` 定代號 → 照 1 到 7 改 → 跑 `python .vibe/hooks/check_swift.py ios-native` 與 `check_refs.py` 到 0 問題 → commit → 問能不能推 → 推上去等雲端，格式紅就抓 `swiftformat-patch` 套上，再下載 `screens` 看版面有沒有壞。這批是動畫與震動，截圖看不出來，最後要真機。
3. 多米說要真機驗：先確認他在 Expo 版匯出過備份，再推 tag `tfn-1`。第一次跑這條流程，預期要修幾輪。
4. 多米回 B 的其他條：照他說的做。規矩檔要先 `cat` 現況給他看。

## 踩到、下一個會話要知道的
- 本機沒有 Swift 工具。改了 `ios-native/` 要推上去才知道編不編得過；一輪約 10 分鐘，含截圖約 15 分鐘。
- SwiftFormat 不准單行的 `if x { ... }`、單行的計算屬性，連續兩個結尾一樣的 `guard` 會被要求合併。直接寫成多行。格式不合時 CI 會存 `swiftformat-patch`：`gh run download <run> --name swiftformat-patch` 抓回來 `git apply`。
- SwiftLint：識別字與型別名最少 3 字、不准強制解包、函式 40 行、檔案 300 行、型別 200 行、行寬 100（照字數算，中文一個字算一格）。畫面不准寫死色碼、字級、間距、秒數，只能從 `Tokens` 拿。
- 宣告前的 `//` 會被格式工具改成 `///`；要當分節用就寫 `// MARK:`。
- 改檔的 python 寫成檔再跑；bash heredoc 遇到反斜線會吃掉（今晚又中一次）。
- 寫紀錄的時間先看時鐘。今晚 `OVERNIGHT.md` 的時間我憑感覺寫錯兩次，都更正過了。
- 測試裡不要造兩次會抽亂數的狀態再比（收下後那句是抽的）。
- 截圖走查靠 `App/LaunchOptions.swift`（只有開發版讀得到）與 `ios-native/scripts/screens.sh`。要多截一張就在腳本的清單加一行。

## 怎麼跑
- 粗檢查：`python .vibe/hooks/check_swift.py ios-native`、`python .vibe/hooks/check_refs.py ios-native`（Windows 上前面加 `PYTHONIOENCODING=utf-8`）。
- 雲端：推分支，`gh run list --repo domyweb666/douzhang --branch <分支> --limit 1` 看 run，`gh run download <run> --name screens --dir .vibe/overnight-screens` 抓截圖。
- Expo 版照舊：`cd E:\豆帳\douzhang; npx expo start --tunnel`。

## 這次會話的雜訊（下次別重新討論）
- 轉之前我建議先用 Expo Go 驗完 AH 再轉，多米選直接轉。已定，不用再提。
- 截圖用的起始分頁一開始沒生效，改成畫面排好再換頁就好了，沒有別的含意。
- 計時中番茄半路是土黃色：算法跟 Expo 版一樣，已寫進 `OVERNIGHT.md` 請多米看，等他回。
