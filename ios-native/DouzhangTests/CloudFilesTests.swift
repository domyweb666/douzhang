@testable import Douzhang
import XCTest

/// 同步的帳本：存得住、不進備份、不對的當沒有。
final class CloudLedgerTests: XCTestCase {
    private var folder = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CloudLedgerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: folder)
    }

    private func place(phone: String? = "a") -> CloudLedgerFile {
        CloudLedgerFile(folder: folder, phone: { phone })
    }

    private var url: URL {
        folder.appendingPathComponent(CloudLedgerFile.fileName)
    }

    func test存了再讀一樣而且每次存都不進備份() throws {
        var book = place().fresh()
        book.identity = "me"
        for round in 0 ..< 2 {
            book.sent["\(book.device)/tags.json"] = "sha\(round)"
            XCTAssertTrue(place().save(book))
            XCTAssertEqual(place().load(), book)
            let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
            XCTAssertEqual(values.isExcludedFromBackup, true)
        }
    }

    func test沒有讀不懂編號不對都當沒有() throws {
        XCTAssertNil(place().load())
        let bad = ["", "{壞掉", #"{"device":"../x","seen":true,"sent":{}}"#]
        for text in bad {
            try text.write(to: url, atomically: true, encoding: .utf8)
            XCTAssertNil(place().load(), text)
        }
    }

    func test別支手機寫的帳本不認() {
        XCTAssertTrue(place(phone: "a").save(place(phone: "a").fresh()))
        XCTAssertNotNil(place(phone: "a").load())
        XCTAssertNil(place(phone: "b").load())
    }

    func test每次給的編號都是新的而且路徑認得() {
        let one = place().fresh().device
        XCTAssertNotEqual(one, place().fresh().device)
        XCTAssertNotNil(SyncFiles.locate("\(one)/tags.json"))
    }

    func test存不進去就回報失敗() {
        let blocked = folder.appendingPathComponent("not-a-folder")
        XCTAssertTrue(FileManager.default.createFile(atPath: blocked.path, contents: Data()))
        let file = CloudLedgerFile(folder: blocked, phone: { nil })
        XCTAssertFalse(file.save(file.fresh()))
    }

    // MARK: 存不成、讀不到

    func test存不成時原本那本還在() throws {
        var book = place().fresh()
        book.identity = "me"
        XCTAssertTrue(place().save(book))
        try setMode(0o555, folder)
        defer { try? setMode(0o755, folder) }
        var next = book
        next.identity = "someone"
        XCTAssertFalse(place().save(next))
        XCTAssertEqual(try place().read(), book)
    }

    func test讀不到要丟錯不是當沒有() throws {
        XCTAssertNil(try place().read())
        XCTAssertTrue(place().save(place().fresh()))
        try setMode(0o000, url)
        XCTAssertThrowsError(try place().read())
        try setMode(0o644, url)
        XCTAssertNotNil(try place().read())
    }

    func test問不到是哪支手機丟錯帳本沒記的不認() throws {
        XCTAssertNil(try place(phone: nil).read())
        XCTAssertTrue(place(phone: nil).save(place(phone: nil).fresh()))
        XCTAssertThrowsError(try place(phone: nil).read())
        XCTAssertNil(try place(phone: "a").read())
    }

    private func setMode(_ mode: Int, _ place: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: place.path)
    }

    // MARK: 被刪掉了沒

    func test少一個月份算意外少標籤或少兩個才算被刪() {
        var book = place().fresh()
        XCTAssertFalse(book.isGone([]))
        let names = ["2026-10.json", "2026-11.json", "tags.json"]
        let files = names.map { CloudFile(path: "\(book.device)/\($0)", isReady: true) }
        for file in files {
            book.sent[file.path] = "sha"
        }
        XCTAssertFalse(book.isGone(files))
        XCTAssertFalse(book.isGone([files[1], files[2]]))
        XCTAssertTrue(book.isGone([files[0], files[1]]))
        XCTAssertTrue(book.isGone([files[2]]))
        // 還沒傳過的不看自己的，只看看過的是不是整個空了
        book.sent = [:]
        XCTAssertFalse(book.isGone([]))
        book.seen = true
        XCTAssertTrue(book.isGone([]))
        XCTAssertFalse(book.isGone([files[0]]))
    }

    func test刪掉就沒有了() {
        XCTAssertTrue(place().save(place().fresh()))
        place().remove()
        XCTAssertNil(place().load())
        place().remove()
    }
}

/// 會卡住執行緒的呼叫排的那一條佇列：有時限、照順序、逾時的不會晚點又冒出來。
@MainActor
final class CloudLineTests: XCTestCase {
    private struct Broken: Error {}

    func test結果與錯誤照樣回來() async throws {
        let line = CloudLine()
        let value = try await line.run(5) { _ in 7 }
        XCTAssertEqual(value, 7)
        do {
            try await line.run(5) { _ in throw Broken() }
            XCTFail("要丟錯")
        } catch {
            XCTAssertTrue(error is Broken)
        }
    }

    func test前一件卡住時逾時的那件之後也不會做() async throws {
        let line = CloudLine()
        let diary = CloudDiary()
        let gate = DispatchSemaphore(value: 0)
        let stuck = Task {
            try await line.run(30) { _ in
                diary.add("卡住了")
                gate.wait()
                diary.add("放開了")
            }
        }
        await CloudStage.until("卡住") { diary.all == ["卡住了"] }
        do {
            try await line.run(0.05) { _ in diary.add("逾時的") }
            XCTFail("要逾時")
        } catch {
            XCTAssertTrue(error is TimeLimit.Expired)
        }
        gate.signal()
        try await stuck.value
        try await line.run(30) { _ in diary.add("後來的") }
        XCTAssertEqual(diary.all, ["卡住了", "放開了", "後來的"])
    }

    func test逾時但已經在做的一定排在後來的前面() async throws {
        let line = CloudLine()
        let diary = CloudDiary()
        let gate = DispatchSemaphore(value: 0)
        let slow = Task {
            // 太短的話，佇列還沒輪到它就先作廢了
            try await line.run(3) { _ in
                diary.add("開始寫")
                gate.wait()
                diary.add("寫完")
            }
        }
        await CloudStage.until("開始寫") { diary.all == ["開始寫"] }
        // 趁它還卡著就排進去
        let later = Task {
            try await line.run(30) { _ in diary.add("刪雲端") }
        }
        do {
            try await slow.value
            XCTFail("要逾時")
        } catch {
            XCTAssertTrue(error is TimeLimit.Expired)
        }
        gate.signal()
        try await later.value
        XCTAssertEqual(diary.all, ["開始寫", "寫完", "刪雲端"])
    }

    func test一件卡住時其他的照時限回來不會卡在一起() async {
        let line = CloudLine()
        let jobs = (0 ..< 20).map { _ in
            Task { try? await line.run(0.1) { _ in Thread.sleep(forTimeInterval: 0.3) } }
        }
        let clock = ContinuousClock()
        let began = clock.now
        for job in jobs {
            _ = await job.value
        }
        XCTAssertLessThan(clock.now - began, .seconds(1))
    }
}

/// 同步的字：每一種都有一句，不寫驚嘆號。
final class CloudWordsTests: XCTestCase {
    func test每一種狀況都有一句() {
        let lines = CloudProblem.allCases.map { Words.cloudLine($0) }
        let questions: [CloudQuestion] = [.account, .emptied, .restored]
        let asks = questions.map { Words.cloudAsk($0) }
        XCTAssertEqual(Set(lines + asks).count, lines.count + asks.count)
        for line in lines + asks {
            XCTAssertFalse(line.isEmpty)
            XCTAssertFalse(line.contains("！"))
        }
    }
}
