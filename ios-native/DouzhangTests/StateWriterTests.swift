@testable import Douzhang
import XCTest

/// 存檔在背景寫：落地順序跟交進來的一樣、最新一份勝出、flush 之後檔裡就是最後一份。
final class StateWriterTests: XCTestCase {
    private let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("StateWriterTests-\(UUID().uuidString)")

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
        super.tearDown()
    }

    /// 第 index 份：「在做什麼」寫成編號，讀回來看得出是哪一份。
    private func numbered(_ index: Int) -> AppState {
        Machine.setDoing(Store.blank(), text: "第\(index)份")
    }

    func test連續交好幾份flush之後檔裡是最後一份() {
        let file = StateFile(folder: folder)
        let writer = StateWriter(file: file)
        XCTAssertTrue(writer.flush())
        for index in 0 ..< 30 {
            writer.save(numbered(index)) { _ in }
        }
        XCTAssertTrue(writer.flush())
        XCTAssertEqual(file.load().state, numbered(29))
    }

    @MainActor
    func test寫完照順序報被蓋掉的不報最後一份一定報() async {
        let writer = StateWriter(file: StateFile(folder: folder))
        var reported: [Int] = []
        for index in 0 ..< 30 {
            writer.save(numbered(index)) { isSaved in
                XCTAssertTrue(isSaved)
                reported.append(index)
            }
        }
        XCTAssertTrue(writer.flush())
        await CloudStage.until("最後一份報回來") { reported.last == 29 }
        XCTAssertEqual(reported, reported.sorted())
        XCTAssertEqual(Set(reported).count, reported.count)
        XCTAssertLessThanOrEqual(reported.count, 30)
    }

    @MainActor
    func test寫不進去報失敗() async throws {
        let blocked = folder.appendingPathComponent("not-a-folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "x".write(to: blocked, atomically: true, encoding: .utf8)
        let writer = StateWriter(file: StateFile(folder: blocked.appendingPathComponent("inside")))
        var results: [Bool] = []
        writer.save(numbered(0)) { results.append($0) }
        await CloudStage.until("報回來") { !results.isEmpty }
        XCTAssertEqual(results, [false])
        XCTAssertFalse(writer.flush())
    }

    // MARK: 接在殼上

    @MainActor
    func test殼的每個動作flush之後檔裡就是現在的狀態() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        for index in 0 ..< 10 {
            shell.model.setDoing("第\(index)次")
        }
        shell.model.flushSaves()
        XCTAssertEqual(StateFile(folder: shell.home).load().state, shell.model.state)
    }

    @MainActor
    func test本機檔讀不懂時動作不寫檔() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let home = stage.root.appendingPathComponent(AppShell.name)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let url = home.appendingPathComponent(StateFile.fileName)
        try "{讀不懂".write(to: url, atomically: true, encoding: .utf8)
        let shell = try await AppShell.open(stage)
        defer { shell.close() }
        shell.model.setDoing("寫第三節")
        shell.model.flushSaves()
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "{讀不懂")
        XCTAssertFalse(shell.model.saveFailed)
    }
}
