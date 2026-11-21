import CryptoKit
import Foundation

/// Expo 版留在手機上的存檔（AsyncStorage）。同一個 Bundle ID 接手後，第一次打開從這裡把資料搬過來。
/// 只讀不寫、不刪：搬完之後舊檔原封不動留著。
enum LegacyStore {
    static let key = "douzhang.v1"
    private static let folderName = "RCTAsyncLocalStorage_V1"
    private static let manifestName = "manifest.json"

    /// AsyncStorage 把短的值直接寫在 manifest.json 裡；超過 1024 字的另外存成一個檔，
    /// 檔名是鍵的 MD5，manifest 裡那一欄是 null。
    static func read(appSupport: URL, bundleId: String) -> String? {
        let folder = appSupport.appendingPathComponent(bundleId).appendingPathComponent(folderName)
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(manifestName)) else {
            return nil
        }
        guard let manifest = (try? JSONSerialization.jsonObject(with: data)) as? JSONObject else {
            return nil
        }
        guard let value = manifest[key] else { return nil }
        if let inline = value as? String { return inline }
        return try? String(contentsOf: folder.appendingPathComponent(md5(key)), encoding: .utf8)
    }

    static func md5(_ text: String) -> String {
        Insecure.MD5.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// 讀到的狀態。unreadable＝存著的東西讀不懂：state 是空的，原本存的原封不動留在那裡，
/// 只有匯入或清空能換掉它。
struct LoadedState {
    var state: AppState
    var unreadable: Bool
}

/// 狀態檔：Application Support 裡的一個 JSON 檔，格式跟 Expo 版相同。
struct StateFile {
    static let fileName = "douzhang.v1.json"

    let folder: URL
    /// 沒有新檔時去哪裡找 Expo 版的舊資料
    var legacy: () -> String? = { nil }

    static var standard: StateFile {
        let folder = URL.applicationSupportDirectory
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        return StateFile(folder: folder) {
            LegacyStore.read(appSupport: folder, bundleId: bundleId)
        }
    }

    private var url: URL {
        folder.appendingPathComponent(StateFile.fileName)
    }

    /// 原封不動讀出存著的字。沒存過回 nil；讀取失敗丟例外：
    /// 「讀不到」不能當成「沒東西要備份」，不然會沒備份就覆蓋。
    func readRaw() throws -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// 讀狀態。永遠不寫檔。
    func load() -> LoadedState {
        let blank = Store.blank()
        let stored: String?
        do {
            stored = try readRaw()
        } catch {
            return LoadedState(state: blank, unreadable: true)
        }
        guard let text = stored, !text.isEmpty else {
            // 沒有新檔：第一次從 Expo 版換過來，或全新安裝。舊資料讀不懂就從空的開始，舊檔不動
            let moved = legacy().flatMap { try? StateDecoding.parse($0) }
            return LoadedState(state: moved ?? blank, unreadable: false)
        }
        guard let state = try? StateDecoding.parse(text) else {
            return LoadedState(state: blank, unreadable: true)
        }
        return LoadedState(state: state, unreadable: false)
    }

    /// 寫狀態。回成不成功，不丟例外；不成功時畫面要顯示那一行。
    func save(_ state: AppState) -> Bool {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try StateEncoding.text(state).write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}
