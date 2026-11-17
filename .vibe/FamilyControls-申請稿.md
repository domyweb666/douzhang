# Family Controls (Distribution) 申請稿（番茄帳）

> 2026-11-17 多米決定申請。這份是給你照著填的，英文段落可以直接貼。
> 送出後把日期補在最下面「紀錄」，核准信來了也記一筆，我才知道可以動工。

## 送之前先確認兩件事

1. 用**帳號持有人（Account Holder）**的 Apple ID 登入。申請是跟著開發者團隊走的，其他角色可能送不出去。
2. 到 App Store Connect → 番茄帳 → App 資訊，抄下「Apple ID」那串數字（表單上叫 App Apple ID，不是你登入用的信箱）。

## 表單

網址：https://developer.apple.com/contact/request/family-controls-distribution

表單的欄位我沒辦法登入看，下面是別人回報過的欄位。2026 年有人說表單改版成整個帳號填一次、沒有 bundle ID 欄位，所以**以你實際看到的為準**；看到下面沒列的欄位，截圖給我，我幫你寫。

| 欄位 | 填什麼 |
|---|---|
| App name | 番茄帳 |
| App Apple ID | App Store Connect 上那串數字 |
| Bundle ID | `org.domyweb.douzhang` |
| 用途說明（自由填寫） | 貼下面那段英文 |

### 用途說明（貼這段）

```
番茄帳 is a Pomodoro focus timer for individual users. The user writes down one concrete next step, starts a focus session (5 to 90 minutes), and gets a notification when it ends.

We are requesting Family Controls so users can optionally block distracting apps on their own device during a focus session. This is a self-control feature for the device owner. It is not used to monitor or manage another person's device.

How it works:
1. In Settings, the user turns on "Block apps during focus". We request authorization with AuthorizationCenter (individual authorization) and the user confirms with Face ID or passcode.
2. The user picks apps, categories, or websites with the system FamilyActivityPicker. We only store the opaque selection tokens on the device.
3. When the user starts a focus session, we apply a shield to the selected apps with ManagedSettings.
4. When the session ends, or the user stops it, we remove the shield.

The feature is off by default and the user can turn it off at any time. The app has no account system, no server, no analytics or advertising SDKs. Nothing about the user's app selection or app usage leaves the device, and we do not use the DeviceActivity report data.
```

## 要不要連擴充一起送

建議**主 app 先送，三個擴充也順手各送一次**。表單免費，每個 bundle ID 各自排隊；之後如果要「到點自動解開」或自訂擋板的樣子就會用到，現在一起送可以少等一輪。

擴充的 bundle ID（其他欄位跟主 app 一樣，用途說明最前面加一句）：

| Bundle ID | 最前面加這句 |
|---|---|
| `org.domyweb.douzhang.ActivityMonitor` | `This is the Device Activity Monitor extension of 番茄帳 (org.domyweb.douzhang). It removes the shield when a focus session ends while the app is in the background.` |
| `org.domyweb.douzhang.ShieldConfiguration` | `This is the Shield Configuration extension of 番茄帳 (org.domyweb.douzhang). It shows the app's own text on the shield screen.` |
| `org.domyweb.douzhang.ShieldAction` | `This is the Shield Action extension of 番茄帳 (org.domyweb.douzhang). It handles the button on the shield screen.` |

如果表單要求 bundle ID 必須先在開發者後台登記過，擴充這三個就先跳過，只送主 app。

## 核准之後（我來做，除了第 1 步）

1. 你到 developer.apple.com → Identifiers → `org.domyweb.douzhang`，在 Additional Capabilities 勾 Family Controls (Distribution)，再加一個 App Group。
2. 我裝套件、改打包流程、寫功能，用 GitHub Actions 出 TestFlight build。
3. 你在手機上驗。

## 等太久怎麼辦

論壇上的等待時間從一天到一個多月都有。超過兩週沒消息，Apple 工程師在論壇上的建議是開一張 code-level support ticket，附上 Team ID 和 bundle ID。

## 紀錄

- 2026-11-17 多米決定申請。
- 送出日期：
- 核准日期：
