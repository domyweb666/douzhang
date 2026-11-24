@testable import Douzhang
import XCTest

/// 帳號的代號：比的是解開之後是不是同一個，不是封存的字一不一樣。
final class CloudTokenTests: XCTestCase {
    private func code(_ token: String, like known: String?) throws -> String {
        try CloudToken.code(NSString(string: token), like: known)
    }

    func test同一個帳號回原本那個字() throws {
        let known = try code("one", like: nil)
        XCTAssertEqual(try code("one", like: known), known)
    }

    func test同一個帳號封存的寫法不同也回原本那個字() throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.outputFormat = .xml
        archiver.encode(NSString(string: "one"), forKey: NSKeyedArchiveRootObjectKey)
        let known = archiver.encodedData.base64EncodedString()
        XCTAssertNotEqual(known, try code("one", like: nil))
        XCTAssertEqual(try code("one", like: known), known)
    }

    func test不同帳號回新的() throws {
        let known = try code("one", like: nil)
        let other = try code("two", like: known)
        XCTAssertNotEqual(other, known)
        XCTAssertEqual(try code("two", like: other), other)
    }

    func test解不開的當不同() throws {
        let fresh = try code("one", like: nil)
        let bad = ["", "亂碼", Data("不是封存".utf8).base64EncodedString()]
        for known in bad {
            XCTAssertEqual(try code("one", like: known), fresh, known)
        }
    }
}

/// 等 iCloud 讓路之後才做的事：輪到自己那一刻才比帳號，叫停了就不做。
final class CloudAccessTests: XCTestCase {
    private var folder = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CloudAccessTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: folder)
    }

    private func oldFile() throws -> URL {
        let url = folder.appendingPathComponent("2026-11.json")
        try Data("舊的".utf8).write(to: url)
        return url
    }

    private func text(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    // MARK: 等的時候換了帳號

    func test等讓路時換了帳號不寫() throws {
        let url = try oldFile()
        let holder = try Holder(url)
        holder.start {
            try CloudAccess.write(Data("新的".utf8), to: url, CloudTicket()) {
                try holder.refuse()
            }
        }
        holder.release()
        holder.finish()
        XCTAssertEqual(holder.diary.all, ["放手", "比帳號", "不准"])
        XCTAssertEqual(text(url), "舊的")
    }

    func test等讓路時換了帳號不讀() throws {
        let url = try oldFile()
        let holder = try Holder(url)
        holder.start {
            _ = try CloudAccess.read(url, CloudTicket()) { try holder.refuse() }
        }
        holder.release()
        holder.finish()
        XCTAssertEqual(holder.diary.all, ["放手", "比帳號", "不准"])
    }

    func test等讓路時換了帳號不刪() throws {
        let url = try oldFile()
        let home = folder
        let holder = try Holder(home)
        holder.start {
            try CloudAccess.erase(home, CloudTicket()) { try holder.refuse() }
        }
        holder.release()
        holder.finish()
        XCTAssertEqual(holder.diary.all, ["放手", "比帳號", "不准"])
        XCTAssertEqual(text(url), "舊的")
    }

    // MARK: 叫停

    func test等讓路時叫停就不寫() throws {
        let url = try oldFile()
        let holder = try Holder(url)
        let ticket = CloudTicket()
        holder.start {
            try CloudAccess.write(Data("新的".utf8), to: url, ticket) { try holder.refuse() }
        }
        ticket.cancel()
        // 對方還佔著就回來了
        holder.finish()
        XCTAssertEqual(holder.diary.all, ["沒做"])
        holder.release()
        XCTAssertEqual(text(url), "舊的")
    }

    func test等讓路時叫停就不刪() throws {
        let url = try oldFile()
        let home = folder
        let holder = try Holder(home)
        let ticket = CloudTicket()
        holder.start {
            try CloudAccess.erase(home, ticket) { try holder.refuse() }
        }
        ticket.cancel()
        holder.finish()
        XCTAssertEqual(holder.diary.all, ["沒做"])
        holder.release()
        XCTAssertEqual(text(url), "舊的")
    }

    // MARK: 資料夾

    func test資料夾不在寫不進去也不會自己開() {
        let home = folder.appendingPathComponent("gone")
        let url = home.appendingPathComponent("tags.json")
        XCTAssertThrowsError(try CloudAccess.write(Data(), to: url, CloudTicket()) {})
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.path))
    }

    func test開好資料夾就寫得進去讀得到刪得掉() throws {
        let home = folder.appendingPathComponent("Records/one")
        let url = home.appendingPathComponent("tags.json")
        let data = Data("內容".utf8)
        try CloudAccess.makeFolder(home, CloudTicket()) {}
        try CloudAccess.write(data, to: url, CloudTicket()) {}
        let found = try CloudAccess.read(url, CloudTicket()) {}
        XCTAssertEqual(found, data)
        try CloudAccess.erase(home, CloudTicket()) {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.path))
    }
}

/// 另一個協調器先佔住一個位置，叫它放手才放。發生過的事照先後記著。
private final class Holder: @unchecked Sendable {
    let diary = CloudDiary()
    private let taken = DispatchSemaphore(value: 0)
    private let letGo = DispatchSemaphore(value: 0)
    private let done = DispatchSemaphore(value: 0)
    private let limit = DispatchTimeInterval.seconds(10)

    private struct NotTaken: Error {}

    init(_ url: URL) throws {
        DispatchQueue.global().async { [self] in
            // 佔不到就不會有「佔住了」，下面等不到會丟錯
            NSFileCoordinator(filePresenter: nil).coordinate(
                writingItemAt: url,
                options: [],
                error: nil
            ) { _ in
                taken.signal()
                letGo.wait()
                diary.add("放手")
            }
        }
        if taken.wait(timeout: .now() + limit) == .timedOut {
            throw NotTaken()
        }
    }

    /// 別的執行緒開始做那件事了才回。
    func start(_ work: @escaping @Sendable () throws -> Void) {
        let begun = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { [self] in
            begun.signal()
            do {
                try work()
                diary.add("做了")
            } catch {
                diary.add((error as? CloudError) == .otherAccount ? "不准" : "沒做")
            }
            done.signal()
        }
        begun.wait()
    }

    /// 等那件事回來。
    func finish() {
        if done.wait(timeout: .now() + limit) == .timedOut {
            XCTFail("卡住沒回來")
        }
    }

    func release() {
        letGo.signal()
    }

    func refuse() throws {
        diary.add("比帳號")
        throw CloudError.otherAccount
    }
}

/// 系統的清單：沒人聽就不准開查詢（關掉同步之後才輪到的那一趟）。
@MainActor
final class CloudCatalogTests: XCTestCase {
    func test刪之前那一眼收掉時有人在聽就不關() {
        let catalog = CloudCatalog()
        catalog.watch { _ in }
        catalog.endGlance()
        XCTAssertTrue(catalog.isWatched)
        catalog.unwatch()
        XCTAssertFalse(catalog.isWatched)
    }

    func test沒人聽就不開查詢() async {
        let catalog = CloudCatalog()
        catalog.watch { _ in }
        catalog.unwatch()
        do {
            _ = try await catalog.listed()
            XCTFail("要丟錯")
        } catch {
            XCTAssertEqual(error as? CloudError, .stopped)
        }
    }
}
