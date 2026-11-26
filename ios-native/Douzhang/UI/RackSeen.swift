import Foundation

/// 番茄架畫的那份資料：看得到時照 model 現在的樣子，看不到時停在上一次看到的（效能審查乙2）。
/// 放在參照型別裡、在 body 一開頭換：看不到時 body 完全不讀 model，主畫面收一顆、記一筆、改設定，這頁就不跟著重算；
/// 用 @State 的值存的話，換新本身又會觸發一次重算。
@MainActor
final class RackSeen {
    private(set) var state = Store.blank()
    private(set) var todayKey = ""
    private(set) var wiped = false
    private var taken = false

    /// 看得到、或一次都還沒拿過：照 model 現在的樣子換新。只有這裡讀 model，讀到的欄位 SwiftUI 才會盯著。
    func refreshed(from model: AppModel, inView: Bool) -> RackSeen {
        if inView || !taken {
            state = model.state
            todayKey = model.todayKey
            wiped = model.wiped
            taken = true
        }
        return self
    }
}
