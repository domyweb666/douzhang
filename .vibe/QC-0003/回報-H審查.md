# 工作包 H 審查（2026-11-24）：整份 diff 與新檔逐行讀過、對過六張圖；本機編不了；沒有 git 動作

檢查：check_swift 問題數 0；check_refs 沒定義 0；check_words 0；lint 的寫死數值（間距、字級、秒數、顏色）在 Screens、UI 掃過 0。
「沒人用」跟 HEAD 比：只剩 HEAD 就有的 `Words.beansCount`、`Tokens.Rack.statsName`（其餘是列舉名自己的誤報，新列舉 Bell、Home 也各一條），這次沒有新增。

**改了**
1. `UI/Buttons`＋`Screens/RackScreen`：`CompactButton` 只剩番茄架空狀態一處、一律茄紫底，`primary` 參數與淡底那條路拿掉。
2. `Screens/HomeIdle`：`HomeCaption` 註解「鈴響頁的標籤」已經沒有了，改成「鈴響後很久才回來」。
3. `UI/BellReceipt`：「寫一句」那行字是 UIKit 的 UILabel，包在 Button 裡可能擋到點擊；加 `.allowsHitTesting(false)`，整塊照樣按得到。
4. `Screens/BellScreen`：「再做 15 分」在最大字級（AX5）縮到一半仍差約 5pt 會變「…」，膠囊左右內距 8 改 4（膠囊本來就撐滿，平常看不出差別）。

**查過沒問題**
- 編譯：memberwise 順序、ViewBuilder 的 let、AnyLayout、UIViewRepresentable 簽名、Shape、switch 齊全、tuple 比較；被刪的型別、字、代號在 Douzhang、DouzhangTests、scripts 都沒有殘留。
- 1B：前景只有 Spacer、frame、不吃點擊的 overlay，沒有容器 contentShape；開始鈕用圓形 contentShape，番茄堆點得到。座標算回去跟圖同位（那組中心 293、開始鈕 484–664、左右欄 79）。SE 剩 251 高放得下。
- 2A：整塊環是按鈕，點空白處記一筆還在；算出來環中心 442、下排 738，跟圖同。
- 3A：`children: .ignore` 只包時鐘，按鈕列在外面；數字等寬、各佔固定一塊；874 寬縮到約 213（圖 220）不出安全區；667 寬字級 168、左右各留約 35、按鈕列約 482 寬放得下，跟數字不重疊。`leaveZen(opening: .sound)` 與記一筆同一條路，HomeScreen 重新掛上時 `initial: true` 會開。
- 4B：草稿每字存、`keep`／`flow`／`lateMinutes` 沒變；按鈕在捲動區外；番茄彈出超出約 1pt、上面留 12，不會被切。
- 測試與 `make_users.py`：實跑 week3-bell，「鈴響頁今天那列」是 4 顆，等於已收 3 加這一顆，合理；「第二行」是分析文件的固定叫法，不改。

**留著沒改**：收據最後一條線到鋸齒 24（圖 36）：補成一樣的話 SE 一定要捲，照 H2 的取捨。`SheetRow.selected` HEAD 就沒人傳，不碰。
**只能真機或雲端看**：SwiftFormat 排版、UILabel 折行高度、橫放左右 insets、番茄堆穿透點一次、待機 AX1 加作廢那行在 SE 的距離（行框疊約 17，字本身不疊）。
