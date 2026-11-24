# 回報 J（切片帳本 AI18；跟 `J-規格.md` 那包收費與 iCloud 不是同一件。A1 鈴響總數＋B2 番茄柔順變大，2026-11-24）：本機編不了，逐行讀過；沒有 git 寫入

檢查：check_swift 問題數 0；check_refs 沒定義 0；check_words 0。

**A1**：`Words.todayTotal` 門檻改 `Params.todayTotalFrom`（8）；小番茄照舊最後 12 顆。`TodayRow` 寫總數時兩邊從上面排起（畫布 A1 是 0／26），7 顆以內照舊對齊中線。「今天」那欄不會縮，番茄吃剩下的寬，所以大字級只會多折行、不會互蓋。測試 `UsualRangeTests` 改一則。
**B2**：新元件 `GrowingTomato`（`UI/TomatoView`），`HomeRings` 與 `FocusScreen` 共用。frame 固定全熟大小，`scaleEffect` 從中心縮；`Grow.scale`、`growMinScale` 放回來，加 `Grow.redraw`；`GrowPostureTests` 加三則、改一則。`RingTomato`、`RingBlock` 的 `scale` 參數換成 `growing`＋`now`，休息那顆照舊 0.4。

**為什麼不會跳**
- 不用補間：每格照真實時間算，所以第一格、回前景、進出聚焦、提早做完（`endAt` 沒變）都直接是對的大小。補間會在回前景追一段，也慢 0.25 秒。
- 取「畫面時鐘」與「這一格」較晚的：timeline 停著時時刻會留在過去，番茄不會縮回去；間隔拉長時 0.25 秒的畫面時鐘也會重算。
- 間隔＝總長 ÷ 6000，最短 0.0075 秒：25 分 0.25 秒、90 分 0.9 秒、50 秒以內的顆每格。一步邊緣 0.008 點。暫停：背景（含鎖屏，有背景音也停）、減少動態、再做。inactive 不停，回來露出的第一格才對。
- 線條、光澤：番茄是 Canvas，照全熟大小畫好整塊等比縮；只縮不放大，不會糊。

**自己決定**：帳本代決 102–105。
**文件**：切片帳本 AI18（AI15 筆 21、AI16 筆 20、AI17 ②③ 標明）、待驗 AI18 十一列、黃金 128／156／167／183／188／203 改、205–207 新、參數表、詞彙表、`.analytics` 05／07／08／閘門紀錄。產品定稿、核心動作卡、HANDOFF 沒碰：HANDOFF 第 6、10、16 行還寫等多米挑。
**沒把握**：SwiftFormat 排版；`TimelineView` 長間隔在真機的實際節奏；5 秒顆順不順；耗電；一開始 0.4 那段邊緣的細緻度要真機看。
