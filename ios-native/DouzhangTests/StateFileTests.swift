@testable import Douzhang
import XCTest

/// 狀態檔的讀寫與從 Expo 版搬資料。每條測試用自己的暫存資料夾，不碰 app 真的存檔。
final class StateFileTests: XCTestCase {
    private var folder = URL(fileURLWithPath: NSTemporaryDirectory())
    private let bundleId = "org.domyweb.douzhang"

    override func setUpWithError() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StateFileTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: folder)
    }

    private var fileURL: URL {
        folder.appendingPathComponent(StateFile.fileName)
    }

    private func write(_ text: String) throws {
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// 在暫存資料夾裡擺一份 Expo 版（AsyncStorage）的存檔。
    private func writeLegacy(manifest: String, bigValue: String? = nil) throws {
        let legacyFolder = folder
            .appendingPathComponent(bundleId)
            .appendingPathComponent("RCTAsyncLocalStorage_V1")
        try FileManager.default.createDirectory(at: legacyFolder, withIntermediateDirectories: true)
        let manifestURL = legacyFolder.appendingPathComponent("manifest.json")
        try manifest.write(to: manifestURL, atomically: true, encoding: .utf8)
        if let bigValue {
            let valueURL = legacyFolder.appendingPathComponent(LegacyStore.md5(LegacyStore.key))
            try bigValue.write(to: valueURL, atomically: true, encoding: .utf8)
        }
    }

    private func sampleState() -> AppState {
        let base = Moment.local(2026, 11, 1, 9)
        let focusing = Machine.start(Store.blank(), now: base)
        return Machine.keep(focusing, now: base + 25 * Moment.minute, text: "寫完第二節")
    }

    // MARK: 存與讀

    func test全新安裝讀出來是空的而且讀取不會寫檔() {
        let loaded = StateFile(folder: folder).load()
        XCTAssertFalse(loaded.unreadable)
        XCTAssertEqual(loaded.state, Store.blank())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func test存了再讀回來一模一樣() {
        let file = StateFile(folder: folder)
        let state = sampleState()
        XCTAssertTrue(file.save(state))
        let loaded = file.load()
        XCTAssertFalse(loaded.unreadable)
        XCTAssertEqual(loaded.state, state)
    }

    func test壞掉的字讀不懂時原本的資料還在而且會告訴上層() throws {
        try write("{這不是 JSON")
        let file = StateFile(folder: folder)
        let loaded = file.load()
        XCTAssertTrue(loaded.unreadable)
        XCTAssertEqual(loaded.state, Store.blank())
        XCTAssertEqual(try file.readRaw(), "{這不是 JSON")
    }

    func test是別的檔一樣當讀不懂原本的資料還在() throws {
        try write(#"{"hello":"world"}"#)
        let file = StateFile(folder: folder)
        XCTAssertTrue(file.load().unreadable)
        XCTAssertEqual(try file.readRaw(), #"{"hello":"world"}"#)
    }

    func test存不進去時回報失敗不會把軟體弄當() {
        let blocked = folder.appendingPathComponent("not-a-folder")
        XCTAssertTrue(FileManager.default.createFile(atPath: blocked.path, contents: Data()))
        XCTAssertFalse(StateFile(folder: blocked).save(Store.blank()))
    }

    func test沒存過時原文是空的() throws {
        XCTAssertNil(try StateFile(folder: folder).readRaw())
    }

    // MARK: 從 Expo 版搬資料

    func test舊存檔鍵名的雜湊跟舊版算的一樣() {
        XCTAssertEqual(LegacyStore.md5("douzhang.v1"), "5ff61db3c35c4dbb7a067791921164ce")
    }

    func test短的舊資料直接寫在清單裡讀得到() throws {
        let text = try StateEncoding.text(Store.blank())
        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        try writeLegacy(manifest: #"{"douzhang.v1":"\#(escaped)"}"#)
        XCTAssertEqual(LegacyStore.read(appSupport: folder, bundleId: bundleId), text)
    }

    func test長的舊資料另外存成一個檔也讀得到() throws {
        let text = try StateEncoding.text(sampleState())
        try writeLegacy(manifest: #"{"douzhang.v1":null}"#, bigValue: text)
        XCTAssertEqual(LegacyStore.read(appSupport: folder, bundleId: bundleId), text)
    }

    func test沒有舊資料或清單裡沒有這個鍵就是沒有() throws {
        XCTAssertNil(LegacyStore.read(appSupport: folder, bundleId: bundleId))
        try writeLegacy(manifest: #"{"other":"x"}"#)
        XCTAssertNil(LegacyStore.read(appSupport: folder, bundleId: bundleId))
    }

    func test沒有新檔時把舊資料搬過來舊檔不動() throws {
        let state = sampleState()
        let text = try StateEncoding.text(state)
        try writeLegacy(manifest: #"{"douzhang.v1":null}"#, bigValue: text)
        let appSupport = folder
        let legacyId = bundleId
        let file = StateFile(folder: folder) {
            LegacyStore.read(appSupport: appSupport, bundleId: legacyId)
        }
        let loaded = file.load()
        XCTAssertFalse(loaded.unreadable)
        XCTAssertEqual(loaded.state, state)
        XCTAssertEqual(LegacyStore.read(appSupport: folder, bundleId: bundleId), text)
    }

    func test已經有新檔就不再看舊資料() {
        let file = StateFile(folder: folder) { "{壞掉的舊資料" }
        // 收下後那句是抽的：同一份狀態存了再比，不能造兩次
        let state = sampleState()
        XCTAssertTrue(file.save(state))
        XCTAssertEqual(file.load().state, state)
    }

    func test舊資料讀不懂就從空的開始() {
        let file = StateFile(folder: folder) { "{壞掉的舊資料" }
        let loaded = file.load()
        XCTAssertFalse(loaded.unreadable)
        XCTAssertEqual(loaded.state, Store.blank())
    }
}

/// 時間怎麼寫成字。
final class TimeTextTests: XCTestCase {
    func test剩餘時間無條件進位到秒不足零顯示零() {
        XCTAssertEqual(TimeText.mmss(25 * Moment.minute), "25:00")
        XCTAssertEqual(TimeText.mmss(59001), "1:00")
        XCTAssertEqual(TimeText.mmss(59000), "0:59")
        XCTAssertEqual(TimeText.mmss(1), "0:01")
        XCTAssertEqual(TimeText.mmss(-500), "0:00")
    }

    func test聚焦模式的分與秒補到兩位超過百分照樣寫() {
        XCTAssertTrue(TimeText.clockParts(25 * Moment.minute) == ("25", "00"))
        XCTAssertTrue(TimeText.clockParts(61000) == ("01", "01"))
        XCTAssertTrue(TimeText.clockParts(200 * Moment.minute) == ("200", "00"))
    }

    func test鈴響收據上的長度與起訖() {
        XCTAssertEqual(Words.lenWithFlow(25, flow: 0), "25 分")
        XCTAssertEqual(Words.lenWithFlow(25, flow: 15), "25 分＋15")
        let start = Moment.local(2026, 11, 1, 8, 11)
        XCTAssertEqual(Words.clockRange(start, start + 25 * Moment.minute), "08:11–08:36")
    }

    func test收據上的時刻是本地的時與分() {
        XCTAssertEqual(TimeText.hhmm(Moment.local(2026, 11, 1, 9, 5)), "09:05")
        XCTAssertEqual(TimeText.hhmm(Moment.local(2026, 11, 1, 23, 59)), "23:59")
    }
}
