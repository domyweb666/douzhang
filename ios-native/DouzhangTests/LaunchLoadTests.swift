@testable import Douzhang
import XCTest

/// 共用的那一份日曆：手機換時區就跟著換，算出來的日期鍵跟每次新建一份時一模一樣。
final class SharedCalendarTests: XCTestCase {
    private let zones: [String?] = [
        nil,
        TimeZone.current.identifier,
        "Asia/Taipei",
        "America/New_York",
        "Pacific/Chatham",
        "Australia/Lord_Howe",
        "Mars/Base",
    ]

    /// 改之前的寫法：每次新建一份日曆、用 String(format:) 拼字。
    private func oldDayKey(_ time: Millis, zone: String?) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        if let zone, let known = TimeZone(identifier: zone) {
            calendar.timeZone = known
        }
        let shifted = time - Params.dayStartHour * Params.msPerHour
        let parts = calendar.dateComponents([.year, .month, .day], from: Store.date(shifted))
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// 一年裡每隔 3 小時 7 分一個時刻，夏令時間切換那幾天也會踩到。
    private var moments: [Millis] {
        let start = Moment.local(2026, 1, 1, 0)
        let step = 187 * Moment.minute
        return Array(stride(from: start, to: start + 366 * 24 * 60 * Moment.minute, by: step))
    }

    private func expectSameAsOld(file: StaticString = #filePath, line: UInt = #line) {
        let times = moments
        for zone in zones {
            let wrong = times.first { Store.dayKey($0, zone: zone) != oldDayKey($0, zone: zone) }
            XCTAssertNil(wrong, "\(zone ?? "nil") 這一刻不一樣", file: file, line: line)
        }
    }

    func test換時區才換一份() throws {
        let taipei = try XCTUnwrap(TimeZone(identifier: "Asia/Taipei"))
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let shared = Store.SharedCalendar(zone: taipei)
        XCTAssertEqual(shared.calendar(in: taipei).timeZone, taipei)
        XCTAssertEqual(shared.calendar(in: newYork).timeZone, newYork)
        XCTAssertEqual(shared.calendar(in: newYork).identifier, .gregorian)
        XCTAssertEqual(shared.calendar(in: taipei).timeZone, taipei)
    }

    func test日期鍵跟每次新建日曆的寫法一模一樣() {
        expectSameAsOld()
    }

    func test手機換了時區日期鍵跟著換() throws {
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        for name in ["America/New_York", "Asia/Tokyo"] {
            NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: name))
            XCTAssertEqual(Store.localCalendar().timeZone, TimeZone.current)
            expectSameAsOld()
        }
    }

    func test補零跟StringFormat一樣() {
        for number in [-12345, -5, -1, 0, 1, 7, 12, 99, 100, 2026, 12345] {
            XCTAssertEqual(Store.zeroPadded(number, width: 4), String(format: "%04d", number))
            XCTAssertEqual(Store.zeroPadded(number, width: 2), String(format: "%02d", number))
        }
    }
}

/// 開機讀檔在背景：讀完之前不准存檔，不然空的那份會蓋掉存著的。
@MainActor
final class LaunchLoadTests: XCTestCase {
    /// 讀檔的那條執行緒是不是主執行緒（背景叫的，所以上鎖）。沒叫到也算在主執行緒，測試才會紅
    private final class Seen: @unchecked Sendable {
        private let lock = NSLock()
        private var onMain = true

        func mark() {
            lock.withLock { onMain = Thread.isMainThread }
        }

        var wasMain: Bool {
            lock.withLock { onMain }
        }
    }

    private func makeModel(_ stage: CloudStage, _ file: StateFile, _ home: URL) throws -> AppModel {
        try AppModel(
            file: file,
            backups: BackupFiles(folder: home.appendingPathComponent("backups")),
            cloud: stage.phone(AppShell.name).link
        )
    }

    func test讀完檔之前改動不寫檔() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let home = stage.root.appendingPathComponent(AppShell.name)
        let file = StateFile(folder: home)
        let stored = CloudStage.holding("r1")
        XCTAssertTrue(file.save(stored))
        let before = try file.readRaw()
        let model = try makeModel(stage, file, home)
        model.commit(Store.blank())
        model.flushSaves()
        XCTAssertEqual(try file.readRaw(), before)
        let running = Task { await model.run() }
        defer {
            model.flushSaves()
            running.cancel()
        }
        await CloudStage.until("讀完檔") { model.loaded }
        XCTAssertEqual(model.state.days, stored.days)
        model.flushSaves()
        XCTAssertEqual(try file.readRaw(), before)
    }

    func test開機在背景讀檔舊資料照樣搬過來() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let home = stage.root.appendingPathComponent(AppShell.name)
        let stored = CloudStage.holding("r1")
        let legacyText = try StateEncoding.text(stored)
        let seen = Seen()
        let file = StateFile(folder: home) {
            seen.mark()
            return legacyText
        }
        let model = try makeModel(stage, file, home)
        let running = Task { await model.run() }
        defer {
            model.flushSaves()
            running.cancel()
        }
        await CloudStage.until("讀完檔") { model.loaded }
        XCTAssertFalse(seen.wasMain)
        XCTAssertEqual(model.state.days, stored.days)
        XCTAssertFalse(model.unreadable)
    }
}
