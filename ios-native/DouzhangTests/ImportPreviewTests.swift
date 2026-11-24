@testable import Douzhang
import XCTest

/// 匯入前的確認框：這份有幾天、幾顆，會換掉現在的幾顆。
final class ImportPreviewTests: XCTestCase {
    private let base = Moment.local(2026, 11, 1, 9)

    /// 每天各收幾顆；0 顆的那天只有一筆作廢。
    private func state(_ beansPerDay: [Int]) -> AppState {
        var state = Store.blank()
        for (day, count) in beansPerDay.enumerated() {
            let bean = Bean(
                keptAt: base,
                typeId: "t1",
                len: 25,
                clue: "",
                notes: [],
                pings: [],
                flow: 0
            )
            var record = DayRecord(beans: Array(repeating: bean, count: count))
            if record.beans.isEmpty {
                record.voids = [
                    VoidEntry(voidedAt: base, typeId: "t1", minute: 8, reason: "", text: ""),
                ]
            }
            state.days["2026-11-0\(day + 1)"] = record
        }
        return state
    }

    private func tally(_ beansPerDay: [Int]) -> BeanTally {
        BeanTally(state(beansPerDay))
    }

    func test數有番茄的日子與顆數只有作廢的日子不算() {
        XCTAssertEqual(tally([]).days, 0)
        XCTAssertEqual(tally([]).beans, 0)
        XCTAssertEqual(tally([3, 0, 2]).days, 2)
        XCTAssertEqual(tally([3, 0, 2]).beans, 5)
        XCTAssertEqual(tally([0]).beans, 0)
    }

    func test兩邊都有番茄先講這份再講會換掉幾顆() {
        XCTAssertEqual(
            Words.importPreview(tally([3, 2]), current: tally([4])),
            "這份有 2 天、5 顆；會換掉現在的 4 顆。"
        )
    }

    func test沒有番茄的那一邊不寫零顆() {
        XCTAssertEqual(
            Words.importPreview(tally([3]), current: tally([])),
            "這份有 1 天、3 顆；現在還沒有番茄。"
        )
        XCTAssertEqual(
            Words.importPreview(tally([]), current: tally([4])),
            "這份還沒有番茄；會換掉現在的 4 顆。"
        )
    }

    func test現在存的讀不懂就說讀不懂() {
        XCTAssertEqual(
            Words.importPreview(tally([3]), current: nil),
            "這份有 1 天、3 顆；現在存的那份讀不懂，會整份換掉。"
        )
    }
}
