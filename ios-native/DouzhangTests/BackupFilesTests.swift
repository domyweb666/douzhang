@testable import Douzhang
import XCTest

/// 備份的檔案處理：自動備份、匯出的暫存檔、匯入時讀檔。每條測試用自己的暫存資料夾。
final class BackupFilesTests: XCTestCase {
    private var folder = URL(fileURLWithPath: NSTemporaryDirectory())
    private let noon = Moment.local(2026, 11, 1, 12)

    override func setUpWithError() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BackupFilesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: folder)
    }

    private func file(_ name: String, _ text: String) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func problem(_ result: Result<AppState, BackupProblem>) -> BackupProblem? {
        if case let .failure(problem) = result { return problem }
        return nil
    }

    func test匯出檔名是軟體名加日期() {
        XCTAssertEqual(BackupFiles.backupName(noon), "番茄帳備份-2026-11-01.json")
    }

    func test匯出寫好的暫存檔讀得回來() throws {
        let text = try StateEncoding.text(Store.blank())
        let url = try XCTUnwrap(BackupFiles.writeExport(text, now: noon, into: folder))
        XCTAssertEqual(url.lastPathComponent, "番茄帳備份-2026-11-01.json")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), text)
    }

    func test自動備份寫一份原文而且查得到上次是什麼時候() throws {
        let backups = BackupFiles(folder: folder)
        XCTAssertNil(backups.lastAutoBackupAt())
        XCTAssertTrue(backups.autoBackup("{原本的字", now: noon))
        XCTAssertTrue(backups.autoBackup("{後來的字", now: noon + Moment.minute))
        XCTAssertEqual(backups.lastAutoBackupAt(), noon + Moment.minute)
        let name = BackupFiles.autoPrefix + String(Int(noon)) + BackupFiles.autoSuffix
        let saved = try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
        XCTAssertEqual(saved, "{原本的字")
    }

    func test清空時自動備份全刪別的檔不動() throws {
        let backups = BackupFiles(folder: folder)
        XCTAssertTrue(backups.autoBackup("a", now: noon))
        let other = try file("notes.json", "{}")
        XCTAssertTrue(backups.removeAutoBackups())
        XCTAssertNil(backups.lastAutoBackupAt())
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path))
    }

    func test匯入讀得懂的備份() throws {
        var state = Store.blank()
        state.settings.restShort = .minutes(10)
        let url = try file("backup.json", StateEncoding.text(state))
        XCTAssertEqual(try BackupFiles.readImport(url).get(), state)
    }

    func test匯入讀不懂的檔或不是備份的檔原因是讀不懂() throws {
        let broken = try file("bad.json", "{壞")
        XCTAssertEqual(problem(BackupFiles.readImport(broken)), .unreadable)
        let noVersion = try file("other.json", #"{"settings":{},"days":{}}"#)
        XCTAssertEqual(problem(BackupFiles.readImport(noVersion)), .unreadable)
        let missing = folder.appendingPathComponent("missing.json")
        XCTAssertEqual(problem(BackupFiles.readImport(missing)), .unreadable)
    }

    func test匯入太大的檔原因是太大() throws {
        let big = try file("big.json", String(repeating: "x", count: Params.importMaxBytes + 1))
        XCTAssertEqual(problem(BackupFiles.readImport(big)), .tooBig)
    }
}
