import Foundation
import UIKit

/// 這支手機的同步帳本：編號、上次對的是哪個 iCloud、傳過什麼。
struct CloudLedger: Codable, Equatable {
    /// 這支手機在雲端的資料夾名
    var device: String
    /// 上次對上的 iCloud；還沒對過是 nil
    var identity: String?
    /// 在那個 iCloud 看過東西。看過、現在整個空了，就是有人刪了或換了地方
    var seen = false
    /// 傳過的檔：路徑 → 內容的 SHA256。一樣就不重寫
    var sent: [String: String] = [:]
    /// 寫這本帳的是哪支手機（vendor 識別碼，只存本機拿來比）
    var phone: String?

    /// 一定會有的那個檔：標籤不會空。
    static func tagsPath(_ device: String) -> String {
        "\(device)/tags.json"
    }

    /// 有人把雲端的刪了：整個空了，或這台放過的少了標籤檔、少了兩個以上。
    /// 別台選「也刪掉」時這台剛好在離線改，清單會剩那一個改過的，光看空不空會漏掉。
    /// 只少一個月份檔算意外，補寫就好。
    func isGone(_ files: [CloudFile]) -> Bool {
        if seen, files.isEmpty {
            return true
        }
        let there = Set(files.map(\.path))
        let lost = sent.keys.filter { !there.contains($0) }
        return lost.count > 1 || lost.contains(CloudLedger.tagsPath(device))
    }

    /// 傳過番茄，不只標籤。
    var hasSentRecords: Bool {
        sent.keys.contains { SyncFiles.locate($0)?.month != nil }
    }
}

/// 帳本存成 Application Support 裡的一個檔，不進備份：換機還原後兩支手機同一個編號，
/// 會互相蓋掉，也永遠不讀對方的。手機對手機的轉移不保證跳過這種檔，所以裡面再記是哪支手機寫的。
struct CloudLedgerFile {
    static let fileName = "cloud-ledger.json"

    let folder: URL
    /// 這是哪支手機。真的要用才問系統：沒開同步的人用不到；太早問（還沒解鎖過）會問不到。
    let phone: () -> String?

    @MainActor static var standard: CloudLedgerFile {
        CloudLedgerFile(
            folder: LaunchOptions.dataFolder ?? URL.applicationSupportDirectory,
            phone: { UIDevice.current.identifierForVendor?.uuidString }
        )
    }

    private var url: URL {
        folder.appendingPathComponent(CloudLedgerFile.fileName)
    }

    /// 沒有這個檔、解不開、編號不對、別支手機寫的是 nil：當第一次，重新給一個編號。
    /// 讀不到、還問不到是哪支手機就丟錯：當成第一次的話，換過 Apple 帳號也不會問，直接合進去。
    func read() throws -> CloudLedger? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard let owner = phone() else { throw CloudError.stopped }
        guard let book = try? JSONDecoder().decode(CloudLedger.self, from: data),
              UUID(uuidString: book.device)?.uuidString == book.device,
              book.phone == owner else { return nil }
        return book
    }

    func fresh() -> CloudLedger {
        CloudLedger(device: UUID().uuidString, phone: phone())
    }

    /// 先寫在旁邊、標好不進備份，才換上去：寫不成時原本那本好好的，
    /// 也沒有「換上去了、還沒標」的空窗。
    func save(_ book: CloudLedger) -> Bool {
        let manager = FileManager.default
        var draft = folder.appendingPathComponent("\(CloudLedgerFile.fileName).new")
        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(book).write(to: draft, options: .atomic)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try draft.setResourceValues(values)
            if manager.fileExists(atPath: url.path) {
                _ = try manager.replaceItemAt(
                    url,
                    withItemAt: draft,
                    options: .usingNewMetadataOnly
                )
            } else {
                try manager.moveItem(at: draft, to: url)
            }
            return true
        } catch {
            try? manager.removeItem(at: draft)
            return false
        }
    }

    func remove() {
        // 本來就沒有也算刪好了；真的刪不掉，下次打開同步會接著用舊的編號，不會弄丟東西
        try? FileManager.default.removeItem(at: url)
    }
}
