# 包 A 回報（同步的純邏輯，2026-11-24；審查後第二版）：本機編不了，逐行讀過；沒有 git 動作

檢查：check_swift 問題數 0；check_refs 沒定義 0。規則先用 Python 隨機跑 6 萬組才翻成 Swift；審查後的規則重跑：帶小數的本機 4 萬組（交換、結合、冪等、順序、吸收）、三台來回 2.4 萬組（含全被刪光、沒動過的預設），0 錯。

**新檔** `Core/`：`SyncFiles`（路徑、寫、讀）、`SyncMerge`（番茄與作廢）、`SyncTags`（標籤）、`SyncJoin`（同編號兩份合一份）、`SyncLimits`（讀雲端檔擋極端數字）；`Design/ParamsCloud`；`DouzhangTests/Sync{TestSupport,Merge,Tags,Files,Limits,Laws}Tests`。

**給包 B 叫的**（沒改）：`SyncMerge.merged(_:_:)`、`SyncFiles.outgoing(_:device:)`、`SyncFiles.remotes(_:except:)`、`SyncFiles.locate(_:)`。

**審查修了**
- R1：`RackCalendar.dayBlocks`／`axisHours` 夾進 0–24 點，from 一定小於 upTo；整顆在這天之後的放最底下。別的時區、`t` 不是數字、1e300 都有測試。要畫在對的位置得照那筆的時區換算，這次沒做。
- R2：別台 mod 0 的標籤，這台還在與刪掉都沒有、合完的紀錄也沒人用，就不收。v1 刪過、但舊番茄還掛在上面的那個標籤仍會回來一次（再刪就有紀錄，不會再回來）。
- S3：收下贏作廢時，作廢的 `text` 併進 `clue`、`doing` 併進 `doing`（規格只寫念頭與有人找）。S4：minute 夾在 0–525600，不整筆擋。
- S5：全被刪光時留的那個把 mod 補到刪除那一刻，真的救回來，別台也跟著回來（規格只寫留本機那個）。S6：測試改成真的 removedAt 0；隨機測試的時刻帶小數。
- 小事做了：日期鍵要真的有那天、2000–2099；標籤長度下限 1；自己的編號不分大小寫；`SettingsLogic.removeType` 拿掉 `now` 預設值（測試 5 處跟著改）。
- 小事沒做：雲端字數不截（併過的兩句會超過 120，截了每台會不一樣）、stamp 碰上限、len 小數、兩行的 doing 在分析另成一項。

**給主對話寫進帳本（照規格不改）**
- S1：標籤名字、長度、顏色共用一個 mod，兩台各改不同欄會丟早的那邊。改成一欄一個時刻要趁 v3 出貨前，出貨後就要 v4。
- S2：第一次合併，兩台各自把同一個預設標籤改成不同意思，只剩一個名字，舊番茄會換名字，只能靠自動備份救。

**其他自己決定的**：測試顆用 `typeId == Machine.devTypeId` 認，寫與讀都濾；雲端時刻寫整毫秒；併不起來的欄位（含 keptAt）整組跟一份走，算得出日期的先贏；念頭取次數多的那邊；多行的字兩邊又不同時按行排；檔裡的日子要跟檔名同月。

**沒把握**：`String.contains(String)`、swiftformat 換行。極端數字只擋雲端檔，匯入那條路（`len` 1e300 會讓 `Store.units` 當掉）沒動。
