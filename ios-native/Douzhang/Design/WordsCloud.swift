import Foundation

/// iCloud 同步的字。平常什麼都不說，出狀況才有一句。
extension Words {
    static let cloudRow = "iCloud 同步"

    // MARK: 停下來問

    static let cloudAdopt = "放進去"
    static let cloudDecline = "先不要"

    static func cloudAsk(_ question: CloudQuestion) -> String {
        switch question {
        case .account: "換了 Apple 帳號。要把這支手機的番茄放進這個 iCloud 嗎？"
        case .emptied: "iCloud 裡的番茄不見了。要把這支手機的放進去嗎？"
        case .restored: "這支手機還沒同步過。要把它的番茄放進這個 iCloud 嗎？"
        }
    }

    // MARK: 關掉、清除時問

    static let cloudEraseTitle = "iCloud 那份也要刪掉嗎？"
    /// 清除所有資料時
    static let cloudEraseNote = "其他手機放進去的也會一起刪。"
    /// 關掉同步時
    static let cloudEraseOffNote = "其他手機放進去的也會一起刪，手機裡的番茄不會動。"
    static let cloudKeep = "留著 iCloud 那份"
    static let cloudErase = "也刪掉"

    // MARK: 出狀況

    static func cloudLine(_ problem: CloudProblem) -> String {
        switch problem {
        case .off: "沒登入 iCloud，或 iCloud 雲碟沒開，新的番茄先存在這支手機。"
        case .backupFailed: "沒辦法先把現在的資料備份起來，還沒開始同步。"
        case .paused: "沒有放進這個 iCloud，新的番茄先存在這支手機。"
        case .eraseFailed: "iCloud 那份沒刪成，點這裡再試一次。"
        case .eraseOther: "iCloud 那份在別的 Apple 帳號，登入原本的才刪得掉。"
        }
    }
}
