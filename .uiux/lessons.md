# lessons

| 日期 | skill | 發生什麼 | 下次規則 |
|---|---|---|---|
| 2026-10-31 | domi-uiux-core | 原型是 domi-learn-app 階段三產物，但階段一到三的設計文件在 claude.ai Project，本機 repo 只有程式。Agent 只能從 index.html 與 commit 考古，核心動詞出現四個候選。 | 進 UIUX 線前先把 learn-app 的產出存進 `.uiux/00-來源/`，考古只當補充，不當主來源。 |
| 2026-10-31 | domi-uiux-wireframe | 書與 skill 預設 SwiftUI＋Xcode，多米實際用 Expo Go、沒有 Mac。到 wireframe 第 9 步才問到，前面交接寫的都是 SwiftUI 灰盒子。 | core 開場就問開發環境（Mac 有無、框架），寫進卡的第 9 欄；「回補書」：3-3／3-4 的灰盒子與原型章節該加一段 React Native／Expo 的對應（鍵盤、動態字級、Live Activity 的可用邊界不同）。 |
| 2026-10-31 | domi-uiux-wireframe（灰盒子） | 子元件寫在 App 函式裡，計時器每 250ms re-render 就讓它們重掛：輸入框吃不到字、半頁一直重播動畫。在 web 驗證時才發現。 | 灰盒子也要守「元件在模組層級」；有計時器的畫面一律先在 web 或真機走一遍打字與半頁，不要只看靜態截圖。 |
