# 包 E2 回報（接線，2026-11-24；含中途兩則追加）：本機編不了，逐行讀過，測試一則都沒跑過；沒有 git 動作；App/Cloud*、Core 沒碰

檢查：check_swift 0；check_refs 沒定義 0，沒人用只剩 `Words.priceReading`（等付費頁）與既有 Tokens 誤報；check_words 0。
**狀態**：包 B 審查後的版本已對過（回報-JB「給 E2」）。`DouzhangTests/Cloud*` 另一個代理在改，我的測試等它的 `prepare`、`empty` 補好才跑得過。

**改了**：`App/AppModel`（收 cloud；load／commit／replaceAll／becameActive 各叫一次）、`AppModel+Actions`（keep 記編號）、`AppModel+Backup`（`backUpSaved` 拆出來共用；`wipeAll(erasingCloud:)`）、`DouzhangApp`、`RootView`（status → setPaid；掛 CloudAsk）、`SettingsData`、`HomeScreen`（番茄堆順序）、`UI/JarView`＋`JarScene`、`project.yml` 與 `PrivacyInfo`（只有註解）。
**新檔**：`App/AppModel+Cloud`、`Screens/{SettingsCloud,SettingsWipe,CloudAsk}`、`DouzhangTests/{AppShellSupport,AppModelCloudTests(12),AppModelJarTests(6)}`；JarSceneTests 加 3 則。擋 app、聚焦、購買區、付費頁沒接。

**追加兩則**
- 清除時問雲端：直接用 `cloud.hasCopy`（開著、有沒刪成的、或 seen 過；不看買了沒），`wipeAsksCloud` 拿掉了。
- 番茄堆：`jarSeen`＝合完的顆數扣掉這台收了還沒掉的；待機都掉完了才是 nil。計時、鈴響、休息、回待機還沒看到，都掉自己那顆。只記顆數不夠：休息中別台較晚收的會排最後、掉成它的，所以加 `jarFresh`，自己那顆排最後（`jarBeans`）。待機正在掉到一半時合進來，它照樣掉完，別台的躺好（`JarScene.join`）。

**代決（都好改回來）**
1. iCloud 列照 4A，多米沒挑。改 4B／4C 只動 `SettingsCloud.swift`。
2. 關掉時雲端沒有這台放的（`hasCopy`）就不問留或刪。關掉的框沒有「取消」，預設留著；清除那個框有「取消」。
3. 沒刪成的兩句（`eraseFailed`、`eraseOther`）都能點，退款後也列。`off`、`paused` 灰字，其他紅字。
4. 清除：第一個框 →（看過才有）留著／也刪掉 →「永久清除」，最後一下才真的關、真的刪。
5. 「放進去／先不要」等計時與鈴響過了、沒有別的框或半頁才跳。
6. PrivacyInfo 沒有新的理由代碼（憑記憶對的，送審前對原文）。

**對接包 B 的**：關掉的框用 `cloudEraseOffNote`、清除的框用 `cloudEraseNote`；`.restored` 的字 CloudAsk 直接吃；NoCloudDrive 不用改；`saved()` 補拉他們做了。沒有沒人用的 `Words.cloud*`，不用刪。

**要主對話知道**
- iCloud 權限兩個鍵不夠，還要 `icloud-services: [CloudDocuments]`（註解寫了）；茄記另有 `icloud-container-environment: Production`。
- 待機時合進來，整堆番茄會重新安置一次（跟匯入同一種，會換位置）；要不動原本的、只多放幾顆，是另一題。
- 標準檔、詞彙表、操作清單、資料結構第 21 條沒動。

**沒把握編得過**：預設參數 `cloud: CloudLink = .standard`（@MainActor 靜態值）、SwiftFormat 換行。`ScreenCover` 靠 `presentedViewController` 判斷，要真機看。
**手機要驗**：開關三種樣子、刪失敗那句點得到、清除三個框不被吞、開著半頁時換 Apple ID 收起半頁才跳、休息中別台收一顆再回待機掉的是自己那顆。
