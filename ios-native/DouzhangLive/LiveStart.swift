import Foundation

/// 擴充這邊的開始鈕那一頭：LiveActivityIntent 由系統在 app 的行程裡跑（app 那份在 AppModel+Live），
/// 這裡不會被叫到，只是讓 Shared/StartNextIntent.swift 在擴充裡也編得過。
enum LiveStart {
    static func run(typeId _: String) async {}
}
