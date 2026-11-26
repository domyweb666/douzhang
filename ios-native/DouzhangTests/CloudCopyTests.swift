@testable import Douzhang
import XCTest

/// 拉的時候沒改過的檔不再讀（效能審查乙6）：只有修改時間與大小都一樣才沿用，拿不準就整份重讀。
@MainActor
final class CloudCopyTests: XCTestCase {
    private let october = "2026-10-05"
    private let september = "2026-09-03"

    /// a 有十月、十一月各一顆，b 的清單帶修改時間與大小，兩台都拉過一次。
    private func pair(_ stage: CloudStage) async throws -> (one: TestPhone, two: TestPhone) {
        let one = try stage.phone("a", bean: "r1")
        one.host.keep("r2", on: october)
        await one.turnOn()
        let two = try stage.phone("b")
        two.drive.isStamped = true
        await two.turnOn()
        return (one, two)
    }

    private func path(_ phone: TestPhone, _ name: String) -> String {
        "\(phone.device)/\(name)"
    }

    private func all(_ phone: TestPhone) -> Set<String> {
        Set(FolderDrive.paths(in: phone.drive.root).filter { $0.hasPrefix("\(phone.device)/") })
    }

    /// 拉一次，回這次讀了哪些檔。
    private func reads(_ phone: TestPhone) async -> [String] {
        let mark = phone.drive.reads.count
        await phone.wakeUp()
        return Array(phone.drive.reads[mark...])
    }

    /// 在這台收一顆，等它傳上去。
    private func keep(_ phone: TestPhone, _ id: String, on key: String = CloudStage.day) async {
        let mark = phone.drive.written.count
        phone.host.keep(id, on: key)
        await CloudStage.until("傳上去") { phone.drive.written.count > mark }
        await phone.idle()
    }

    /// 合進去的那幾份，要跟現在雲端別台的檔整包讀一次一樣。
    private func assertSameAsFullRead(_ phone: TestPhone) throws {
        var files: [String: Data] = [:]
        for path in FolderDrive.paths(in: phone.drive.root) where !path.hasPrefix(phone.device) {
            files[path] = try Data(contentsOf: phone.drive.root.appendingPathComponent(path))
        }
        let full = SyncFiles.remotes(files, except: phone.device)
        let kept = SyncFiles.joined(phone.link.copies.files.values.compactMap(\.piece))
        XCTAssertEqual(kept, full)
        XCTAssertEqual(Set(phone.link.copies.files.keys), Set(files.keys))
    }

    func test沒改過的第二次拉不再讀() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let (one, two) = try await pair(stage)
        XCTAssertEqual(Set(two.drive.reads), all(one))
        XCTAssertEqual(all(one).count, 3)

        let again = await reads(two)
        XCTAssertEqual(again, [])
        XCTAssertEqual(two.host.ids, ["r1", "r2"])
        try assertSameAsFullRead(two)
    }

    func test改了一個月只重讀那一個() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let (one, two) = try await pair(stage)
        await keep(one, "r3")

        let again = await reads(two)
        XCTAssertEqual(again, [path(one, "2026-11.json")])
        XCTAssertEqual(two.host.ids, ["r1", "r2", "r3"])
        try assertSameAsFullRead(two)
    }

    func test新增的月份只讀它刪掉的月份忘掉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let (one, two) = try await pair(stage)
        await keep(one, "r4", on: september)

        let added = await reads(two)
        XCTAssertEqual(added, [path(one, "2026-09.json")])
        XCTAssertEqual(two.host.ids, ["r1", "r2", "r4"])
        try assertSameAsFullRead(two)

        let gone = path(one, "2026-10.json")
        try FileManager.default.removeItem(at: stage.cloud.appendingPathComponent(gone))
        let after = await reads(two)
        XCTAssertEqual(after, [])
        XCTAssertNil(two.link.copies.files[gone])
        // 手機裡的番茄不會因為同步而刪（N9）
        XCTAssertEqual(two.host.ids, ["r1", "r2", "r4"])
        try assertSameAsFullRead(two)
    }

    func test有檔拿不到修改時間就整份重讀() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let (one, two) = try await pair(stage)
        two.drive.unstamped = [path(one, "2026-10.json")]

        let again = await reads(two)
        XCTAssertEqual(Set(again), all(one))
        XCTAssertEqual(again.count, 3)
    }

    func test修改時間往回跳就整份重讀() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let (one, two) = try await pair(stage)
        let file = stage.cloud.appendingPathComponent(path(one, "2026-10.json"))
        let earlier = Date(timeIntervalSince1970: 0)
        try FileManager.default.setAttributes([.modificationDate: earlier], ofItemAtPath: file.path)

        let again = await reads(two)
        XCTAssertEqual(Set(again), all(one))
        try assertSameAsFullRead(two)
    }

    func test重開App從頭全讀() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let (one, _) = try await pair(stage)
        let reopened = try stage.phone("b")
        reopened.drive.isStamped = true
        await reopened.open()
        XCTAssertTrue(all(one).isSubset(of: Set(reopened.drive.reads)))
    }

    func test關掉再打開從頭全讀() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let (one, two) = try await pair(stage)
        two.link.turnOff()
        XCTAssertTrue(two.link.copies.files.isEmpty)
        let mark = two.drive.reads.count
        two.link.turnOn()
        await two.idle()
        XCTAssertEqual(Set(two.drive.reads[mark...]), all(one))
    }
}
