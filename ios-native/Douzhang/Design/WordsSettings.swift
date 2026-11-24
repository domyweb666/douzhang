import Foundation

/// 設定頁自己的句子。全家共用的字（區名、匯出資料、清除所有資料…）用 VeggieText，不在這裡重打。
extension Words {
    static let close = "關閉"
    static let noMailApp = "這支手機沒有可以寄信的 app"

    /// 匯入確認框：先講這份有多少、會換掉現在的多少。沒有番茄的那一邊換一種說法，不寫 0 顆。
    /// current 是 nil 代表手機裡存的那份讀不懂，數不出來。
    static func importPreview(_ incoming: BeanTally, current: BeanTally?) -> String {
        let head = incoming.beans > 0
            ? "這份有 \(incoming.days) 天、\(incoming.beans) 顆"
            : "這份還沒有番茄"
        guard let current else { return "\(head)；現在存的那份讀不懂，會整份換掉。" }
        if current.beans > 0 {
            return "\(head)；會換掉現在的 \(current.beans) 顆。"
        }
        return "\(head)；現在還沒有番茄。"
    }
}
