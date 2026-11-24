# 包 E1 回報（格式 v3 升級，2026-11-24）：本機編不了，逐行讀過；沒有 git 動作

檢查：check_swift 問題數 0；check_refs 沒定義 0。沒人用：`Words.priceReading`（包 C 的新檔，還沒人接）；Tokens 那幾條是既有誤報。

**改了**
- `Core/AppState`：`TagType.mod: Millis = 0`，放最後，既有初始化不用改。
- `Core/Store`：`formatVersion = 3`。
- `Core/StateEncoding`：`writeTagType` 寫 `mod`；`writeDay`、`writeTagType`、`writeRemoved` 放寬成內部可見（同步包直接叫）。
- `Core/StateDecoding.readTagTypes`＋`Core/StateUpgrade.tagMod(_:stored:)`：v3 補值規則。刪掉的標籤走同一條路，也補。
- `Core/SettingsLogic`：`renameType`、`setTypeLen`、`setTypeColor` 最後多收 `now`，`addType` 寫 `mod = now`，其他寫 `max(now, 舊 mod + 1)`。值沒變不動 mod，寫在共用的 `mapType` 一處。
- `App/AppModel+Actions`：三個呼叫端。畫面（TagSheets、TimeDialScreen）不用改。
- 測試：新 `FormatV3Tests`（18 則）；`SettingsLogicTests`、`SmartRestTests` 補 `now`；`FormatV2Tests` 的版本號那則搬到 V3。
- `.analytics/04-資料結構.md`：標籤欄位一段、v2 → v3 一段。第 21 條沒動。

**整個 TagType 拿來比的地方**：正式程式原本 0 處（Stats、Insights、畫面都比 id 或單一欄位；`onChange` 只看 `type.name`；沒有整份 AppState 比較決定存不存）。既有測試有 5 處跟預設標籤比，預設 mod 是 0，照過。

**自己決定的**
- `t<毫秒>` 要剛好 13 位數字才算：不然 t1–t5（改過的預設）、t9 會被當成 1–9 毫秒。其他一律 1。
- 檔裡的 mod 不是數字或是負的，當沒有、照規則補。
- `make_state.py`（v1）、`make_users.py`（v2）不改：它們正好走升級路徑，標準答案不看 mod。

**給主對話留意（照規格做，沒自己改）**
- 兩台時鐘不準（主對話定案，已做）：改與刪一律 `max(now, 舊 mod + 1)`，共用 `SettingsLogic.stamp(_:after:)`；`removeType` 沒給 `now` 時 `removedAt` 最小是 1。加三則測試（共 18 則）。
- `nowMillis()` 帶小數，自己加的標籤 mod 比 id 裡的毫秒多零點幾；檔裡有 mod 就照檔裡的，不影響。
- 沒把握編得過的：`Millis(digits)` 吃 Substring（標準庫有泛型版，應該過）。
