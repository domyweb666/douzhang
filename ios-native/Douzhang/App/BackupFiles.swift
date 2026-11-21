import Foundation

/// 備份出了什麼事：設定頁備份區下面那一行寫哪一句。
enum BackupProblem: Error {
    case unreadable, tooBig, backupFailed, exportFailed, backupsLeft

    var words: String {
        switch self {
        case .unreadable: Words.importUnreadable
        case .tooBig: Words.importTooBig
        case .backupFailed: Words.autoBackupFailed
        case .exportFailed: Words.exportFailed
        case .backupsLeft: Words.backupsLeft
        }
    }
}

/// 匯出寫好的暫存檔。
struct ExportFile: Identifiable {
    var url: URL

    var id: URL {
        url
    }
}

/// 備份的檔案處理：匯出的暫存檔、匯入時讀檔、匯入前的自動備份。只碰檔案，不決定要不要覆蓋。
/// 每個系統呼叫失敗都回旗標，不丟到畫面。
struct BackupFiles {
    static let autoPrefix = "auto-backup-"
    static let autoSuffix = ".json"

    /// 自動備份放哪裡（文件資料夾）
    let folder: URL

    static var standard: BackupFiles {
        BackupFiles(folder: URL.documentsDirectory)
    }

    /// 匯出檔名：番茄帳備份-YYYY-MM-DD.json（app 名＋日期，不接受自訂；匯入不看檔名）。
    static func backupName(_ now: Millis) -> String {
        "\(Words.appName)備份-\(Store.dayKey(now)).json"
    }

    /// 匯出：寫到暫存資料夾，回那個檔。分享完由呼叫端刪掉。寫不成回 nil。
    static func writeExport(_ text: String, now: Millis, into folder: URL) -> URL? {
        let url = folder.appendingPathComponent(backupName(now))
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    /// 匯入：看大小 → 讀字 → 驗格式、補欄位。這一步不碰現在的資料。
    static func readImport(_ url: URL) -> Result<AppState, BackupProblem> {
        // 從檔案選取器來的檔要先借權限才讀得到；自己資料夾裡的檔借不到也沒關係
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return .failure(.unreadable)
        }
        if size > Params.importMaxBytes { return .failure(.tooBig) }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return .failure(.unreadable)
        }
        guard let state = try? StateDecoding.parseBackup(text) else {
            return .failure(.unreadable)
        }
        return .success(state)
    }

    /// 自動備份：把現在存著的原文寫一份 auto-backup-<毫秒>.json。回成不成功。
    func autoBackup(_ text: String, now: Millis) -> Bool {
        let name = BackupFiles.autoPrefix + String(Int(now)) + BackupFiles.autoSuffix
        let url = folder.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    private func autoFiles() -> [URL] {
        let all = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )
        return (all ?? []).filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix(BackupFiles.autoPrefix) && name.hasSuffix(BackupFiles.autoSuffix)
        }
    }

    /// 上次自動備份的時刻，沒有就 nil。設定頁顯示用。
    func lastAutoBackupAt() -> Millis? {
        let times = autoFiles().compactMap { url -> Millis? in
            let tail = url.lastPathComponent.dropFirst(BackupFiles.autoPrefix.count)
            return Double(tail.dropLast(BackupFiles.autoSuffix.count))
        }
        return times.max()
    }

    /// 清空所有資料時連自動備份一起刪。回有沒有刪乾淨。
    func removeAutoBackups() -> Bool {
        do {
            for url in autoFiles() {
                try FileManager.default.removeItem(at: url)
            }
            return true
        } catch {
            return false
        }
    }
}
