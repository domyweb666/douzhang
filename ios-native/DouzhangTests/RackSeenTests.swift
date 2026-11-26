@testable import Douzhang
import Observation
import XCTest

/// 番茄架看不到時停在上一次看到的資料，而且不讀 model（效能審查乙2）：主畫面改了東西，這頁不跟著重算。
@MainActor
final class RackSeenTests: XCTestCase {
    /// 記下「讀過的 model 欄位有沒有改」：SwiftUI 也是靠這個決定要不要重算
    private final class Touched: @unchecked Sendable {
        var hit = false
    }

    private func addBean(_ model: AppModel, _ id: String) {
        var merged = model.state
        let bean = SyncSample.bean(id, at: CloudStage.base + Moment.minute)
        merged.days[CloudStage.day, default: DayRecord()].beans.append(bean)
        model.takeCloud(merged)
    }

    func test一次都沒拿過的話看不到也先拿一次() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        let seen = RackSeen().refreshed(from: shell.model, inView: false)
        XCTAssertEqual(seen.state, shell.model.state)
        XCTAssertEqual(seen.todayKey, shell.model.todayKey)
    }

    func test看不到時停在上一次而且不讀model() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        let seen = RackSeen().refreshed(from: shell.model, inView: true)
        let before = shell.model.state
        let touched = Touched()
        withObservationTracking {
            _ = seen.refreshed(from: shell.model, inView: false)
        } onChange: {
            touched.hit = true
        }
        addBean(shell.model, "r2")
        XCTAssertNotEqual(shell.model.state, before)
        XCTAssertEqual(seen.state, before)
        XCTAssertFalse(touched.hit)
    }

    func test看得到時照model現在的樣子() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, CloudStage.holding("r1"))
        defer { shell.close() }
        let seen = RackSeen().refreshed(from: shell.model, inView: false)
        addBean(shell.model, "r2")
        // 開始滑（或停在這頁）：換成新的
        XCTAssertEqual(seen.refreshed(from: shell.model, inView: true).state, shell.model.state)
        let touched = Touched()
        withObservationTracking {
            _ = seen.refreshed(from: shell.model, inView: true)
        } onChange: {
            touched.hit = true
        }
        addBean(shell.model, "r3")
        XCTAssertTrue(touched.hit)
    }
}
