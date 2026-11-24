# Handoff：QC-0003 三批都 commit 在本機，等多米挑畫布與定 iCloud／購買

> 更新：2026-11-24（接續會話，主對話已近交接線）。分支 `overnight-20261121-2033`，沒推。

## ✅ 做完了
- `60a0ac5` 第一批（AI15）、`ea044e9` 第二批四個版面（AI16）、`8c50ff9` 第三批（AI17：設定頁補列＋VeggieKit 1.0.1、說明字拿掉、鈴響第 13 顆起寫總數）。三批都有乾淨審查員讀過；沒編過、測試沒跑、手機沒驗。
- 逐筆回報 22 筆：`.vibe/QC-0003/逐筆回報.md`。多米對五題的回覆與第三批規格：`.vibe/QC-0003/I-規格.md`。

## 🚧 等多米
1. 畫布（文字版 `.vibe/QC-0003/I-設計選項.md`，本機 `.uiux/03-線框/2026-11-24-I-選項.html`）：A 鈴響 13 顆以上（推薦 A3 縮小排滿）、B 番茄變大（推薦 B2 一路柔順變大；會改掉 2A 的番茄固定 164）。畫布 https://claude.ai/artifact/YV39J2bBcsP1gfEaz5LMsg ，可播放頁 https://claude.ai/artifact/RNJQagG5mJ3XtoQURjArAw
2. iCloud 與購買：`.vibe/QC-0003/I-iCloud購買提案.md`。
3. Apple ID 數字（評分列、分享連結）；隱私權政策與支援網頁要不要發；一句話介紹「種番茄，記下每天做了什麼」對不對；鈴響「收下後直接回待機」後半句要不要拿；`pop`、`hit*` 音效來源（上架前）。
4. 推雲端編譯：多米沒開口，不推。

## ⏭️ 下一步
- 多米挑完：A 改 `UI/BellReceipt.swift` 的 `TodayRow`；B 若選 B2／B3，改 `Screens/HomeRings.swift`（縮放用 scaleEffect 連續動，不改 frame，減少動態時只變色），聚焦模式要不要一起問；再改產品定稿、核心動作卡的「長大」（選 B1 才改字；核心動作卡有閘門 1）。審過、文件同步、commit（訊息帶 QC-0003）。
- 多米說推：`git push` 這個分支 → iOS Native CI；SwiftFormat 紅就套 swiftformat-patch。全綠後他開口才打 tfn-3。

## 🗑️ 雜訊
- 版面已定：1B、2A、3A、4B（今天的顆數用小番茄畫）。第 1 筆左右滑不能說修好，要真機。
- 芹查說「資料夾不是它認得的 app」：它把路徑存成帶引號，內容照給。
