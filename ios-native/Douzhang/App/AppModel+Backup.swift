import Foundation
import VeggieKit

/// 備份三件事：匯出、匯入、清除。確認框由畫面用系統的 alert 問，這裡只做事。
extension AppModel {
    /// 要匯出的字。本機檔讀不懂時，匯出的是那份讀不懂的原文，不是空白。
    private func savedText() -> String? {
        if unreadable {
            return try? file.readRaw()
        }
        return try? StateEncoding.text(state)
    }

    /// 匯出：寫到暫存檔，畫面接著開系統的分享選單。
    func exportBackup() {
        backupProblem = nil
        let folder = FileManager.default.temporaryDirectory
        let now = TimeText.nowMillis()
        guard let text = savedText(),
              let url = BackupFiles.writeExport(text, now: now, into: folder)
        else {
            backupProblem = .exportFailed
            return
        }
        exportFile = ExportFile(url: url)
    }

    /// 分享選單關掉之後：刪掉暫存檔。刪不掉也沒關係，系統清暫存時會清。
    func exportFinished() {
        if let done = exportFile {
            try? FileManager.default.removeItem(at: done.url)
        }
        exportFile = nil
    }

    /// 匯入：使用者在系統的檔案選取器選好了。取消不算錯。
    /// 讀得懂之後先把現在存著的原文自動備份一份，備份不成就不匯；都好了才問要不要換掉。
    func importPicked(_ result: Result<URL, Error>) {
        backupProblem = nil
        guard case let .success(url) = result else { return }
        switch BackupFiles.readImport(url) {
        case let .failure(problem):
            backupProblem = problem
        case let .success(imported):
            if backUpCurrent() {
                pendingImport = imported
            }
        }
    }

    /// 匯入前的自動備份。什麼都還沒存過（剛裝好）就沒有東西要備份。
    /// 讀不到現在的資料就不知道要備份什麼：不匯。
    private func backUpCurrent() -> Bool {
        let raw: String?
        do {
            raw = try file.readRaw()
        } catch {
            backupProblem = .backupFailed
            return false
        }
        guard let raw else { return true }
        let now = TimeText.nowMillis()
        guard backups.autoBackup(raw, now: now) else {
            backupProblem = .backupFailed
            return false
        }
        lastBackup = now
        return true
    }

    /// 按了「換掉」才寫。
    func confirmImport(_ imported: AppState) {
        pendingImport = nil
        wiped = false
        jarSeen = nil
        replaceAll(Machine.settle(imported, now: TimeText.nowMillis(), zone: Store.zoneNow()))
    }

    func cancelImport() {
        pendingImport = nil
    }

    /// 清除所有資料：清乾淨，含自動備份；擋板解開，選過要擋的 app 也忘掉；
    /// 外觀立刻回跟隨系統，觸覺回饋回到預設的開。
    func wipeAll() {
        let removed = backups.removeAutoBackups()
        forgetShield()
        lastBackup = backups.lastAutoBackupAt()
        backupProblem = removed ? nil : .backupsLeft
        wiped = true
        jarSeen = nil
        pulses.removed += 1
        UserDefaults.standard.removeObject(forKey: Appearance.storageKey)
        Appearance.system.apply()
        // 這次震不震（拿掉、換回主畫面、出錯）照清除前的開關：晚一拍才讓開關回到預設的開
        Task {
            try? await Task.sleep(for: .milliseconds(Params.tickMs))
            UserDefaults.standard.removeObject(forKey: VeggieHaptics.storageKey)
        }
        replaceAll(Store.blank())
        page = .home
    }
}
