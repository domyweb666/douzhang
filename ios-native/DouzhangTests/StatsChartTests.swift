@testable import Douzhang
import SwiftUI
import XCTest

/// 分析第一張選長條還是圓餅：記在這支手機上，下次打開照舊。
@MainActor
final class StatsChartTests: XCTestCase {
    private let suite = "StatsChartTests"

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func stored(_ defaults: UserDefaults) -> AppStorage<StatsChart> {
        AppStorage(wrappedValue: StatsChart.bars, StatsChart.storageKey, store: defaults)
    }

    func test存在手機上的字不改改了她選過的就忘了() {
        XCTAssertEqual(StatsChart.storageKey, "statsChart")
        XCTAssertEqual(StatsChart.bars.rawValue, "bars")
        XCTAssertEqual(StatsChart.donut.rawValue, "donut")
    }

    func test沒選過是長條選了圓餅再打開還是圓餅() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertEqual(stored(defaults).wrappedValue, .bars)
        stored(defaults).wrappedValue = .donut
        XCTAssertEqual(stored(defaults).wrappedValue, .donut)
        XCTAssertEqual(defaults.string(forKey: StatsChart.storageKey), "donut")
    }

    func test讀到認不得的字就回長條() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("pie", forKey: StatsChart.storageKey)
        XCTAssertEqual(stored(defaults).wrappedValue, .bars)
    }
}
