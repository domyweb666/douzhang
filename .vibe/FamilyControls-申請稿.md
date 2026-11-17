# Family Controls 權限申請（番茄帳）

> 2026-11-17 多米決定申請並送出。這份原本是照舊版表單寫的填表稿；多米打開後表單已經改版，下面改成實際的樣子。

## 表單實際長怎樣（2026-11-17 多米截圖）

網址：https://developer.apple.com/contact/request/family-controls-distribution

- 標題「Get the Family Controls Framework Entitlement」。
- 只有三格，都是自動帶入、不能改：姓名、Email、Team ID。**沒有 App 名稱、bundle ID、用途說明**。
- 下面是條款，最底下一顆「Get Entitlement」。
- 頁面上寫的是「Once assigned to your developer account」：權限是給**整個開發者帳號**的，不是一個一個 bundle ID 申請。所以不用另外替三個擴充各送一次。

## 條款裡跟番茄帳有關的三條

1. App 的主要用途要是其中一種：家長管小孩的裝置；或「讓個人管理自己的裝置，用專注控制、計時器、任務管理來幫助專注與生產力」。番茄帳是第二種。
2. 不能拿來擋廣告、不能用在公司組織、不能管另一個成年人的裝置。
3. 從這個功能拿到的裝置或使用資料，不能用在廣告、不能給資料仲介，也不能拿去做專注功能以外的事。番茄帳沒有帳號、沒有伺服器、沒有第三方 SDK，本來就不會送出去。

## 還不知道的

- 按下「Get Entitlement」之後是立刻生效，還是要等審核。舊版表單要等一天到一個多月；新版我沒有看過按下去之後的畫面。
- 怎麼確認生效：到 developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → `org.domyweb.douzhang`，看能力清單裡能不能勾 Family Controls。

## 生效之後

1. 多米到上面那一頁，替 `org.domyweb.douzhang` 勾 Family Controls，再加一個 App Group。之後加的擴充（`.ActivityMonitor`、`.ShieldConfiguration`、`.ShieldAction`）要用時再各自登記、勾同一個能力。
2. 我裝套件、改打包流程、寫功能，用 GitHub Actions 出 TestFlight build。
3. 多米在手機上驗。

## 紀錄

- 2026-11-17 多米決定申請。
- 2026-11-17 多米回報已送出（新版表單，按「Get Entitlement」）。按下去之後看到什麼、有沒有收到信：待補。
- 2026-11-17 多米截圖 `org.domyweb.douzhang` 的 Capabilities：清單裡有「Family Controls (Distribution)」，前面的框可以勾（另外還有 Development 版與「Family Controls App and Website Usage」，這兩個不用勾）。看起來按完當下就給了，沒有等審核。
- 還沒做：勾 Family Controls (Distribution) 並按 Save。真正的證明是勾了之後出一個 TestFlight build 簽得過。
- 生效日期：2026-11-17（以清單出現可勾的項目為準；簽章驗過再補一筆）
