# 包 B 回報（2026-11-24，全部做完；沒編過、手機沒驗、沒 commit）

檢查：check_swift 0 問題；check_refs 包 B 的名字都有定義（剩下的「沒定義」是包 A、C 還在改的字與 growMinScale，外加固定誤報 ZenLayout.self）。

- **補充（間距）**：`Tokens.Layout` 加在 Tokens.swift 的 extension；`PageTitle` 上方 40（11、12）。標題到第一塊 24 由包 C 改。Tokens.swift 現在 297 行，再加就破 300。
- **9**：①project.yml 補 120Hz。②新檔 `UI/PagerMotion.swift`：三頁停在哪，iOS 18 用 onScrollPhaseChange，iOS 17 與不帶動畫的跳頁用換頁後 0.5 秒；滑動一開始番茄堆就凍結。③分頁列影子只掛膠囊底。④加速度計停穩 0.5 秒後才開關。⑤HomeScreen 不再讀 model.page。⑥新檔 `App/FrameMeter.swift`：開發版與 TestFlight 才開，寫 os.Logger（org.domyweb.douzhang／pager）。
  - 讀程式多找到一個單子沒寫的根因：`@State private var scene = JarScene()` 在主畫面每次重算都會多建一個再丟掉（讀五個音檔、AVAudioSession setActive、CMMotionManager）；model.page 在手指還在動時換，剛好就在那一拍。改成出現時才建、只建一次。
  - 沒有宣稱修好：錄影量不出掉幾格，要看卡格計的 log。
- **21**：FocusScreen 番茄固定大小只變色；Grow.scale 這邊已不用。
- **28 根因**：新的一顆沒有走「掉下來」，是回待機第一次安置時被當成看過的直接擺在底。證據：826.68 秒還是休息頁，826.72–826.80 待機第一格就已躺在底、到約 829 秒都沒動（正常要等 0.18 秒再掉 1 秒以上）；錄影時間戳在這段沒有缺口，所以不是漏拍。之後 829–836 秒是手機放平，傾斜讓它飄到頂再掉下來；「下一格不見」（835.9 附近）是從開始鈕後面穿過去。
  - 程式上對得到的原因：onKnown 在 onAppear 才接，Canvas 第一次畫早於它，jarSeen 一直是空，每次回待機都整批擺好。錄影證到「被當成看過」，「畫早於 onAppear」這半步是推論，沒有 Mac 驗不了；改法（現場在 onAppear 建好、接好才畫）跟順序無關，測試 JarSceneTests 看住。
- **29**：jar 左右撐掉內距、上下 ignoresSafeArea，地板是螢幕底；分頁列蓋在上面。
- 測試新增：FrameTallyTests、PagerMotionTests、JarSceneTests。JarScene.swift 太長，SlowWatch 搬到 UI/SlowWatch.swift。

自己決定：120Hz 開了之後番茄堆仍鎖每秒 60 步（物理數值是每步的，不鎖會變手感）；滑到一半分頁列換選中格與輕觸覺照舊；iOS 17 滑動前半段凍不到。

沒把握：①撐進安全區靠「ScrollView 裡 ignoresSafeArea 有效」，依據是設定頁內容本來就畫到螢幕底，上緣是類推，要看截圖；②螢幕底那一條點番茄收不收得到，要真機；③`Tokens.Layout` 與 SwiftUI 的 Layout 同名，`Tokens` 裡沒用到協定，應該沒事；④selector(count) 這類 NSObject 寫法沒編過。

沒做、留給別人：`HomeIdle` 的 `.onChange(of: model.page)` 滑動中仍會讓它重算一次（包 A 的檔）；跨午夜時 jarSeen 大於今天顆數、或休息中被系統關掉重開，那顆仍會直接在底；多米沒有 Mac，Windows 讀 log 要另外裝工具。
