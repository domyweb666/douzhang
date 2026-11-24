@testable import Douzhang
import XCTest

/// 合併落在哪一態，番茄堆都一樣：這台自己收的那顆從上面掉下來，別台來的直接躺好。
/// 番茄堆只掉排最後、而且比「上次看到幾顆」多出來的那一顆。
@MainActor
final class AppModelJarTests: XCTestCase {
    /// 今天這幾顆，一分鐘一顆往後排。
    private func today(_ ids: [String], from start: Millis) -> AppState {
        var state = Store.blank()
        let beans = ids.enumerated().map { index, id in
            SyncSample.bean(id, at: start + Double(index) * Moment.minute)
        }
        state.days[Store.dayKey(TimeText.nowMillis())] = DayRecord(beans: beans)
        return state
    }

    /// 別台在那個時刻收了一顆，合進來。
    private func merge(_ model: AppModel, _ id: String, at keptAt: Millis) {
        var merged = model.state
        let bean = SyncSample.bean(id, at: keptAt)
        merged.days[model.todayKey, default: DayRecord()].beans.append(bean)
        model.takeCloud(merged)
    }

    private func expectMineDrops(_ model: AppModel, _ mine: String?) {
        XCTAssertNotNil(mine)
        XCTAssertEqual(model.jarSeen, model.jarBeans.count - 1)
        XCTAssertEqual(model.jarBeans.last?.id, mine)
    }

    func test計時中合進來收下自己那顆照樣掉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let now = TimeText.nowMillis()
        let mine = Machine.start(today(["r1"], from: now - Moment.minute), now: now)
        let shell = try await AppShell.open(stage, mine)
        defer { shell.close() }
        let id = shell.model.state.focusRun?.id
        shell.model.jarSeen = 1
        merge(shell.model, "r8", at: now)
        XCTAssertEqual(shell.model.jarSeen, 2)
        shell.model.keep(text: "")
        expectMineDrops(shell.model, id)
    }

    func test鈴響時合進來自己那顆照樣掉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let now = TimeText.nowMillis()
        // 早就響了還沒收
        var mine = today(["r1"], from: now - Moment.minute)
        mine = Machine.start(mine, now: now)
        if var run = mine.focusRun {
            run.endAt = now - Moment.minute
            mine.current = .focus(run)
        }
        let shell = try await AppShell.open(stage, mine)
        defer { shell.close() }
        XCTAssertEqual(shell.model.phase, .bell)
        let id = shell.model.state.focusRun?.id
        shell.model.jarSeen = 1
        merge(shell.model, "r8", at: now)
        shell.model.keep(text: "")
        expectMineDrops(shell.model, id)
    }

    func test這次打開還沒看過番茄堆合進來自己那顆也掉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let now = TimeText.nowMillis()
        let mine = Machine.start(today(["r1"], from: now - Moment.minute), now: now)
        let shell = try await AppShell.open(stage, mine)
        defer { shell.close() }
        let id = shell.model.state.focusRun?.id
        merge(shell.model, "r8", at: now)
        shell.model.keep(text: "")
        expectMineDrops(shell.model, id)
    }

    func test休息中合進來比它晚收的掉下來的還是自己那顆() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let now = TimeText.nowMillis()
        let mine = Machine.start(today(["r1"], from: now - Moment.minute), now: now)
        let shell = try await AppShell.open(stage, mine)
        defer { shell.close() }
        let id = shell.model.state.focusRun?.id
        shell.model.jarSeen = 1
        shell.model.keep(text: "")
        XCTAssertEqual(shell.model.phase, .rest)
        merge(shell.model, "r8", at: now + Moment.minute)
        merge(shell.model, "r9", at: now - Moment.minute)
        XCTAssertEqual(shell.model.jarBeans.count, 4)
        expectMineDrops(shell.model, id)
    }

    func test待機時合進來番茄堆當場躺好不重播() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let now = TimeText.nowMillis()
        let shell = try await AppShell.open(stage, today(["r1"], from: now - Moment.minute))
        defer { shell.close() }
        shell.model.jarSeen = 1
        merge(shell.model, "r8", at: now)
        XCTAssertNil(shell.model.jarSeen)
    }

    func test回到待機還沒看到番茄堆就合進來自己那顆照樣掉() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let now = TimeText.nowMillis()
        let shell = try await AppShell.open(stage, today(["r1", "r2"], from: now - Moment.minute))
        defer { shell.close() }
        shell.model.jarSeen = 1
        shell.model.jarFresh = "r2"
        merge(shell.model, "r8", at: now + Moment.minute)
        expectMineDrops(shell.model, "r2")
    }
}
