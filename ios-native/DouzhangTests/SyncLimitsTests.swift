@testable import Douzhang
import XCTest

/// 讀雲端檔擋極端數字：壞的那筆跳過，同一個檔裡好的照收。
final class SyncLimitsTests: XCTestCase {
    private let device = SyncSample.other
    private let key = "2026-11-24"

    private func read(_ file: String, _ body: String) -> SyncFiles.Remote? {
        let text = #"{"v":\#(Store.formatVersion),\#(body)}"#
        let files = ["\(device)/\(file)": Data(text.utf8)]
        return SyncFiles.remotes(files, except: SyncSample.phone).first
    }

    private func day(beans: [String] = [], voids: [String] = []) -> DayRecord? {
        let beansText = beans.joined(separator: ",")
        let voidsText = voids.joined(separator: ",")
        let day = #"{"beans":[\#(beansText)],"voids":[\#(voidsText)]}"#
        return read("2026-11.json", #""days":{"\#(key)":\#(day)}"#)?.days[key]
    }

    func test番茄的分鐘或時刻太極端就跳過那顆() {
        let bad = [
            #""len":1e300"#, #""len":-1"#, #""len":1441"#,
            #""len":25,"flow":1e300"#, #""len":25,"flow":-5"#,
            #""len":25,"start":1e300"#, #""len":25,"start":-1"#,
            #""len":25,"doneAt":5e12"#, #""len":25,"t":5e12"#, #""len":25,"t":-1"#,
        ]
        let beans = bad.enumerated().map { #"{"id":"b\#($0.offset)",\#($0.element)}"# }
        let good = #"{"id":"ok","t":4e12,"len":1440,"flow":0,"start":1}"#
        XCTAssertEqual(day(beans: beans + [good])?.beans.map(\.id), ["ok"])
    }

    func test作廢的分鐘或時刻太極端就跳過那筆() {
        let bad = [
            #""len":1e300"#, #""len":-1"#,
            #""t":5e12"#, #""t":-1"#, #""start":-1"#,
        ]
        let voids = bad.enumerated().map { #"{"id":"b\#($0.offset)",\#($0.element)}"# }
        let good = #"{"id":"ok","t":5000,"minute":1440}"#
        XCTAssertEqual(day(voids: voids + [good])?.voids.map(\.id), ["ok"])
    }

    func test作廢的第幾分鐘超出範圍夾住不擋() {
        let voids = [-5, 2000, 900_000].map { #"{"id":"v\#($0)","t":5000,"minute":\#($0)}"# }
        XCTAssertEqual(day(voids: voids)?.voids.map(\.minute), [0, 2000, 525_600])
    }

    func test標籤的長度或時刻太極端就跳過那個() {
        let types = [
            #"{"id":"a","name":"甲","len":1e300,"mod":5}"#,
            #"{"id":"b","name":"乙","len":25,"mod":5e12}"#,
            #"{"id":"g","name":"庚","len":0,"mod":5}"#,
            #"{"id":"c","name":"丙","len":25,"mod":5}"#,
        ].joined(separator: ",")
        let removed = [
            #"{"id":"d","name":"丁","len":25,"mod":5,"removedAt":5e12}"#,
            #"{"id":"e","name":"戊","len":-1,"mod":5,"removedAt":9}"#,
            #"{"id":"f","name":"己","len":25,"mod":5,"removedAt":9}"#,
        ].joined(separator: ",")
        let remote = read("tags.json", #""types":[\#(types)],"removed":[\#(removed)]"#)
        XCTAssertEqual(remote?.types.map(\.id), ["c"])
        XCTAssertEqual(remote?.removed.map(\.type.id), ["f"])
    }
}
