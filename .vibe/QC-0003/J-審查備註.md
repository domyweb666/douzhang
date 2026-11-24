# C-8、C-9：產品的審查截圖與備註（2026-11-24）

## C-8 審查截圖
傳這張：`審查截圖/完整版-審查截圖.png`（1206×2622，去掉透明層，拍自 run 45395635008 的模擬器）。

- **先放這張，送審前要換。** 圖上沒有價格、寫「現在讀不到價格。」，因為產品還沒建好；承諾句也還是草稿字。
- 買得到之後，用手機在付費頁截一張有價格、有「購買」的換上去。
- Apple 寫審查截圖傳了只能換、不能拿掉。

## C-9 審查備註
整段貼進產品的「審查備註」。上限 4000 字。英文是給審查員看的，中文是畫面上的字，別改。

```
"番茄帳完整版" (Full Version) is a one-time, non-consumable purchase. It is not a subscription. The app has no account or sign-in, no ads and no third-party SDKs. Family Sharing is off.

HOW TO FIND IT
1. Open the app and stop any running timer. Tap 設定 (Settings) in the bottom bar.
2. Scroll down to 購買 (Purchase) and tap 完整版 (Full Version).
3. The purchase page opens. The price comes from the App Store. Tap 購買 (Buy).
4. If the price cannot be loaded, the button reads 再讀一次 (Try again).

RESTORE
恢復購買 (Restore) is at the bottom right of the purchase page and in Settings > 購買.

WHAT IT UNLOCKS (right after the purchase, no relaunch)
1. 聚焦模式 (Focus view): start a timer, then tap 聚焦 below the timer or turn the phone to landscape. Shows a full-screen clock.
2. 計時中擋住其他 app (Block other apps during a timer): Settings > 專注. Turn it on, then tap 要擋的 app to choose apps. It asks for Screen Time permission (FamilyControls, individual). Only the apps the user picks are blocked, and only during a timer. If the timer ends while our app is in the background, the block is removed when the user returns to our app. Optional: the rest works without this permission.
3. iCloud 同步 (iCloud sync): Settings > 資料, first row. Off by default. The device must be signed in to iCloud. Records stay in the user's own iCloud; we have no server and cannot see them.

The page also says 之後新增的背景音與外觀 (background sounds and appearances added later) are included. There is nothing to unlock for that line in this version.

FREE WITHOUT THE PURCHASE
Timer, records, statistics, tags, backup import and export, and the current background sounds. These three features are hidden until the purchase.
```

## 貼之前要知道
- 這份是寫**送審那一版**的樣子。現在的程式還沒加 iCloud 權限，第 3 點要等容器勾好、權限加進 app、兩支手機同步走過才成立。
- 「The page also says…」那段跟著承諾句 5-2 走：5-2 不留就整段刪掉。
- 送審前再對一次程式與手機，對不上就改這份再貼；產品送審前備註都能改。
- 這是**產品**的備註。1.0 版本頁還有另一份審查備註（登入、錄影那些），送審前另外寫。
