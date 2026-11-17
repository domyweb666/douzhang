# 番茄帳打包上 TestFlight：照著做的步驟

寫於 2026-11-16。打包走 GitHub Actions（EAS 這個月的免費額度用完了，12/01 才重置）。

一共六步。第 1、2、3 步只有第一次要做，之後每次出新版只做第 4、5、6 步。

| 步驟 | 在哪裡做 | 大概多久 | 狀態 |
|---|---|---|---|
| 1. 登記 Bundle ID、新增 App | Apple 網站 | 5 分鐘 | 11/16 做完，Apple 查得到 |
| 2. 設四個 Apple 金鑰 secret | GitHub 網站 | 5 分鐘 | 11/16 做完，Apple 認了 |
| 3. 建 deploy key | 跟 Claude 說一句 | 1 分鐘 | 11/16 做完，實測讀得到 |
| 4. 推分支和 tag，開始打包 | 跟 Claude 說一句 | 約 10 分鐘（機器跑） | 11/16 第三次（`tf-3`）成功，1.0.0 build 3 已上傳 |
| 5. 在 App Store Connect 把 build 加進測試群組 | Apple 網站 | 5 分鐘＋等處理 | 還沒做 |
| 6. 手機裝起來 | iPhone 的 TestFlight | 2 分鐘 | 還沒做 |

Apple 和 GitHub 的網頁偶爾會改按鈕名稱，下面寫的名稱對不上時，找意思最接近的那顆。

---

## 第 1 步：在 Apple 那邊登記這個 app

打包流程一開始會先問 Apple「有沒有 `org.domyweb.douzhang` 這個 app」，沒有就直接停，所以這步要先做。

### 1-1 登記 Bundle ID

1. 開 <https://developer.apple.com/account/resources/identifiers/list>，登入。
2. 按「Identifiers」旁邊的藍色 ＋。
3. 選 App IDs → Continue，再選 App → Continue。
4. Description 填 `Douzhang`（這欄只給自己看，填英文比較不會被擋）。
5. Bundle ID 選 Explicit，填 `org.domyweb.douzhang`。
6. 下面那一長串 Capabilities 都不用勾。番茄帳的到點通知是本機通知，不需要 Push Notifications。
7. Continue → Register。

如果它說這個 ID 已經被用過，先停下來跟 Claude 說。之前史萊姆和茄記撞過一次號，處理方式不一樣。

### 1-2 新增 App

1. 開 <https://appstoreconnect.apple.com/apps>。
2. 按「App」旁邊的 ＋ → 新增 App。
3. 照這樣填：
   - 平台：iOS
   - 名稱：`番茄帳`
   - 主要語言：繁體中文
   - 套件識別碼：下拉選 `org.domyweb.douzhang`（剛登記的，要等一兩分鐘才會出現）
   - SKU：`douzhang`
   - 使用者存取權限：完整存取權限
4. 按「建立」。

名稱在整個 App Store 不能重複。如果「番茄帳」被別人用掉了，這裡先隨便取一個過得去的（例如「番茄帳 Domy」），之後上架前還能改。手機桌面上顯示的名字是另外設的，還是「番茄帳」。

---

## 第 2 步：把 Apple 的金鑰交給 GitHub

打包機器要用你的 App Store Connect API 金鑰簽章和上傳。豆鍵 10/31 設過一樣的四個值，這次是把同樣的值再貼一次到番茄帳的 repo。GitHub 不讓人把舊的 secret 讀回來，所以沒辦法從豆鍵那邊複製，要回 Apple 那邊拿。

### 2-1 先把四個值找齊

| 名稱 | 去哪裡看 |
|---|---|
| `ASC_KEY_ID` | <https://appstoreconnect.apple.com/access/integrations/api> →「團隊金鑰」那張表的「金鑰 ID」欄，十碼英數 |
| `ASC_ISSUER_ID` | 同一頁最上面的「Issuer ID」，一長串帶連字號的 |
| `ASC_PRIVATE_KEY` | 10/31 下載的那個 `AuthKey_XXXXXXXXXX.p8` 檔。用記事本打開，全部內容都要 |
| `APPLE_TEAM_ID` | <https://developer.apple.com/account> →「會員資格詳細資訊」→ 團隊 ID，十碼英數 |

`.p8` 檔 Apple 只給下載一次。如果 10/31 那個檔找不到了，在同一頁按 ＋ 產生一把新的：名稱隨意、存取權限選「管理」，產生後立刻下載存好。用新金鑰的話，`ASC_KEY_ID` 也要填新的那個。舊金鑰不要撤銷，豆鍵還在用。

### 2-2 貼進 GitHub

1. 開 <https://github.com/domyweb666/douzhang/settings/secrets/actions>。
2. 按「New repository secret」。
3. Name 填上表的名稱（大小寫、底線要一模一樣），Secret 貼值，按「Add secret」。
4. 重複四次。

`ASC_PRIVATE_KEY` 要整段貼，從 `-----BEGIN PRIVATE KEY-----` 那行到 `-----END PRIVATE KEY-----` 那行都要。貼上去換行跑掉沒關係，打包流程會自己重排（11/16 第一次就是整把變成一行，Xcode 不收，後來改成流程自動修）。頭尾少字的話會在「金鑰自檢」那步停下來，並且印出原因。

做完之後那一頁應該列出四個名稱。值看不到是正常的。

---

## 第 3 步：建 deploy key

番茄帳的畫面用了 `@domy/design` 這個套件，它放在私有的 `domy-design` repo。打包機器沒有你的身分，下載不到，需要一把只能讀的鑰匙。

最省事的做法是跟 Claude 說：

> 幫我建 deploy key

Claude 會產生一對鑰匙，公開的那半登記到 `domy-design`（唯讀），私密的那半存進番茄帳的 secret `DOMY_DESIGN_DEPLOY_KEY`，然後把本機的鑰匙檔刪掉。`domy-design` 裡的程式一行都不會動。

想自己來的話，步驟在文件最後的「附錄」。

---

## 第 4 步：開始打包

前三步都好了之後，跟 Claude 說：

> 打包

Claude 會把 `uiux-graybox` 分支和一個 `tf-` 開頭的 tag 推上 GitHub，打包就開始了，然後盯著它跑。11/16 第一輪跑了三次才過（前兩次的原因寫在最後的「11/16 第一次打包的紀錄」），現在這條流程是跑通過的。

推之前要知道一件事：番茄帳的 repo 是公開的，`uiux-graybox` 這條分支目前只在你電腦上。推上去之後，分支裡的程式和 `.vibe`、`.uiux` 這些工作紀錄都會公開。

想自己推的話，在 `E:\豆帳` 開終端機，一行一行跑：

```bash
git push origin uiux-graybox
```

```bash
git tag tf-6
```

```bash
git push origin tf-6
```

分支和 tag 要分兩次推。11/16 第一次兩個一起推，GitHub 沒有開始跑；把 tag 單獨再推一次才觸發。`tf-1` 到 `tf-5` 已經用掉了，下一個從 6 開始（11/17：`tf-4` 紅在一個套件版本、`tf-5` 綠，1.0.0 build 5）。

進度在這裡看：<https://github.com/domyweb666/douzhang/actions>

全部打綠勾大約 10 分鐘（11/16 那次是 9 分半）。機器會照這個順序做：問 Apple 金鑰對不對 → 裝套件 → 跑測試 → 產生 iOS 專案 → 封存簽章 → 上傳。哪一步紅了，把那一步的名稱告訴 Claude。

以後出新版，tag 的數字往上加就好。build 號機器會自己編（等於第幾次跑），不用手動改。

---

## 第 5 步：把 build 加進測試群組

上傳成功後，Apple 還要處理一下，通常 5 到 30 分鐘，好了會寄信。

1. 開 <https://appstoreconnect.apple.com/apps> → 番茄帳 → 上面的「TestFlight」分頁。
2. 看到 1.0.0 (3) 出現、狀態從「處理中」變成可以點。build 號是 3，因為前兩次沒傳成功。出口合規那題已經在設定檔裡答過了，不會再問。
3. 左邊「內部測試」旁邊按 ＋，建一個群組，名字隨意（例如「自己」）。「啟用自動分發」留著勾，以後的 build 會自動進來。
4. 在群組裡的「測試人員」按 ＋，勾你自己的帳號。
5. 如果 build 沒有自動出現在群組裡，到群組的「Build」區塊按 ＋ 手動加。

內部測試不用等 Apple 審核，加進去就能裝。

---

## 第 6 步：手機裝起來

1. iPhone 開 TestFlight（沒裝的話去 App Store 裝），用同一個 Apple ID 登入。
2. 列表裡會出現番茄帳，按「安裝」。

裝起來之後會跟你在 Expo Go 上看到的有幾個地方不一樣，都是已知的：

- 資料是空的。TestFlight 版和 Expo Go 版的資料不相通。
- 長按「開始」不會出現 5 秒測試顆，那是開發版才有的。要測就得真的跑完一顆。
- 啟動時會白一下。啟動畫面還沒做。

接著就可以照 `.vibe/操作清單-待驗.md` 在真機上走 Y1–Y8 和 AA1–AA9。減少動態（Y5）在模擬器上測不到，這次要特別看一下。

---

## 卡住的時候

| 看到什麼 | 多半是什麼原因 |
|---|---|
| 「金鑰自檢」紅，寫金鑰被 Apple 拒絕 | 四個 secret 有一個貼錯；`.p8` 少了頭尾那兩行 |
| 「金鑰自檢」紅，寫還沒有這個 bundle ID 的 app 紀錄 | 第 1-2 步沒做，或建的時候選錯套件識別碼 |
| 「裝套件」紅，訊息裡有 `Permission denied (publickey)` | 第 3 步的 deploy key 沒建好 |
| 「測試與 lint」紅 | 程式本身有測試沒過，跟打包設定無關 |
| 「封存」或「上傳 TestFlight」紅 | 第一次最可能卡的地方，把那一步的名稱告訴 Claude |
| Actions 頁完全沒有東西在跑 | tag 沒推上去，或 tag 名稱開頭少了 `tf-` |

---

## 附錄：自己建 deploy key

1. 開 PowerShell，跑下面這行。它會問兩次密碼，兩次都直接按 Enter。

   ```bash
   ssh-keygen -t ed25519 -C douzhang-ci -f "$env:USERPROFILE\douzhang_ci"
   ```

   跑完在你的使用者資料夾（`C:\Users\你的帳號\`）會多兩個檔：`douzhang_ci`（私密的那半）和 `douzhang_ci.pub`（公開的那半）。

2. 開 <https://github.com/domyweb666/domy-design/settings/keys> → Add deploy key。Title 填 `douzhang-ci`，Key 貼 `douzhang_ci.pub` 的全部內容。「Allow write access」不要勾。

3. 開 <https://github.com/domyweb666/douzhang/settings/secrets/actions> → New repository secret。Name 填 `DOMY_DESIGN_DEPLOY_KEY`，Secret 貼 `douzhang_ci` 的全部內容（這個檔沒有副檔名，用記事本開）。

4. 兩個檔都刪掉。鑰匙已經存在 GitHub 上，本機不用留。

---

## 11/16 第一次打包的紀錄

| 次 | 結果 | 原因與處理 |
|---|---|---|
| `tf-1` | 紅在封存 | 金鑰貼進 GitHub 後整把變成一行，Xcode 不收。流程改成自動把金鑰重排回標準格式 |
| `tf-2` | 紅在封存 | Expo 58 的 `expo-modules-jsi` 在 Xcode 26.3 編不過。打包機器從 macOS 15 換成 macOS 26，用 Xcode 26.6 |
| `tf-3` | 全綠 | 1.0.0 build 3 上傳成功，9 分半 |

上傳時有三行 dSYM 的警告（React、ReactNativeDependencies、hermesvm 三個預先編好的框架沒帶除錯符號）。不影響安裝和使用，只是之後閃退報告裡這三塊的堆疊會看不到函式名稱。

