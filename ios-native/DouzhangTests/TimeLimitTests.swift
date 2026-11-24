@testable import Douzhang
import XCTest

/// 時限：先到的算數、晚到的丟掉，不會等它跑完。
final class TimeLimitTests: XCTestCase {
    private struct Broken: Error {}

    func test在時限內回來就用它的結果() async throws {
        let value = try await TimeLimit.run(5) { 7 }
        XCTAssertEqual(value, 7)
    }

    func test丟出來的錯照樣丟() async {
        do {
            _ = try await TimeLimit.run(5) { () async throws -> Int in throw Broken() }
            XCTFail("要丟錯")
        } catch {
            XCTAssertTrue(error is Broken)
        }
    }

    func test超過時限就丟Expired不等它跑完() async {
        let clock = ContinuousClock()
        let began = clock.now
        do {
            _ = try await TimeLimit.run(0.05) {
                await TimeLimitTests.stubborn(seconds: 3)
            }
            XCTFail("要逾時")
        } catch {
            XCTAssertTrue(error is TimeLimit.Expired)
        }
        XCTAssertLessThan(clock.now - began, .seconds(2))
    }

    func test晚到的回覆丟掉不會閃退() async throws {
        _ = try? await TimeLimit.run(0.02) {
            await TimeLimitTests.stubborn(seconds: 0.1)
        }
        try await Task.sleep(for: .seconds(0.3))
    }

    /// 跟 StoreKit 一樣不理會取消的工作。
    private static func stubborn(seconds: Double) async -> Int {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                continuation.resume(returning: 1)
            }
        }
    }
}
