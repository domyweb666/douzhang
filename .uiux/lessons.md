# lessons

| 日期 | skill | 發生什麼 | 下次規則 |
|---|---|---|---|
| 2026-10-31 | domi-uiux-core | 原型是 domi-learn-app 階段三產物，但階段一到三的設計文件在 claude.ai Project，本機 repo 只有程式。Agent 只能從 index.html 與 commit 考古，核心動詞出現四個候選。 | 進 UIUX 線前先把 learn-app 的產出存進 `.uiux/00-來源/`，考古只當補充，不當主來源。 |
| 2026-10-31 | domi-uiux-wireframe | 書與 skill 預設 SwiftUI＋Xcode，多米實際用 Expo Go、沒有 Mac。到 wireframe 第 9 步才問到，前面交接寫的都是 SwiftUI 灰盒子。 | core 開場就問開發環境（Mac 有無、框架），寫進卡的第 9 欄；「回補書」：3-3／3-4 的灰盒子與原型章節該加一段 React Native／Expo 的對應（鍵盤、動態字級、Live Activity 的可用邊界不同）。 |
| 2026-10-31 | domi-uiux-wireframe（灰盒子） | 子元件寫在 App 函式裡，計時器每 250ms re-render 就讓它們重掛：輸入框吃不到字、半頁一直重播動畫。在 web 驗證時才發現。 | 灰盒子也要守「元件在模組層級」；有計時器的畫面一律先在 web 或真機走一遍打字與半頁，不要只看靜態截圖。 |
| 2026-10-31 | domi-uiux-tokens | 原型直接沿用 Apple 系統色：systemGreen 上白字 2.2:1、secondaryLabel 在白底 3.4:1、tertiaryLabel 1.9:1、systemRed 3.6:1，淺色模式全部不過 4.5／3。「照 Apple 預設就安全」在對比上不成立。 | 代號檔一開始就算對比，系統色也要算；placeholder 不用 tertiary。「回補書」：2-6 可補一句「系統 secondaryLabel／tertiaryLabel 與 systemGreen 白字在淺色模式不過 WCAG」。 |

## 2026-11-01 usertest
- 書 3-7 進場檢查假設「能裝到測試者手機」＝TestFlight。Expo Go 也能裝到測試者自己的 iPhone（掃 tunnel QR），但圖示、啟動畫面、通知對話框名字三處失真，秒表要從 app 畫面出現起算。**回補書**：進場檢查加一列「Expo Go 版：可測任務與手感，首次體驗秒數與權限那一刻要在 TestFlight 版重測」。
- 閘門 2 的三個測試（方向、秒表、usertest）各自寫在 03、06、07，加起來要 13–15 個只能用一次的新人。一人開發找不到那麼多人，合併成一場是必要的縮小；書沒明講可以合併。
- 多米自己比對選方向，不是閘門 2。記成「偏好定案」比硬說「未測」或「已過」都誠實：往下走不卡，欠的測試還在帳上。
