@testable import Douzhang
import XCTest

/// 鈴響頁「響了 N 分鐘前」：超過這顆的休息長度才有，一分鐘變一次，對齊響的那一刻。
final class BellLateTests: XCTestCase {
    /// 開始的時刻帶零點幾毫秒：真的時鐘也是這樣，換成 Date 再換回來才會差一點點
    private let base = Moment.local(2026, 11, 1, 9) + 0.37
    private let minute = Moment.minute

    private func ringing(_ restMode: RestMode = .auto) throws -> (AppState, FocusRun) {
        var state = Store.blank()
        state.settings.restMode = restMode
        state = Machine.start(state, now: base)
        return try (state, XCTUnwrap(state.focusRun))
    }

    /// 畫面排的那一格：響的那一刻加幾分鐘，經過 Date 再換回毫秒。
    private func shown(_ run: FocusRun, plus minutes: Double) -> Millis {
        let date = Store.date(run.endAt).addingTimeInterval(minutes * Params.secondsPerMinute)
        return date.timeIntervalSince1970 * Params.msPerSecond
    }

    func test還沒超過休息長度就沒有那一行() throws {
        let (state, run) = try ringing()
        let rest = Double(Store.restMinutes(run.len))
        XCTAssertEqual(Machine.lateMinutes(state, run: run, now: run.endAt), 0)
        XCTAssertEqual(Machine.lateMinutes(state, run: run, now: run.endAt + rest * minute - 1), 0)
    }

    func test整分鐘那一格就算到那一分() throws {
        let (state, run) = try ringing()
        let rest = Store.restMinutes(run.len)
        for extra in 0 ..< 5 {
            let late = Double(rest + extra)
            XCTAssertEqual(
                Machine.lateMinutes(state, run: run, now: shown(run, plus: late)),
                rest + extra
            )
        }
    }

    func test兩格之間是前一格的分鐘數() throws {
        let (state, run) = try ringing()
        let rest = Store.restMinutes(run.len)
        let between = run.endAt + (Double(rest) + 3.5) * minute
        XCTAssertEqual(Machine.lateMinutes(state, run: run, now: between), rest + 3)
    }

    func test智能調節照收下時的算法() throws {
        let (state, run) = try ringing(.smart)
        let rest = Machine.restPlan(state, run: run).minutes
        let onTime = shown(run, plus: Double(rest))
        XCTAssertEqual(Machine.lateMinutes(state, run: run, now: onTime), rest)
        XCTAssertEqual(Machine.lateMinutes(state, run: run, now: onTime - minute / 2), 0)
    }
}
