@testable import Douzhang
import XCTest

/// 都躺好了沒。
final class JarQuietTests: XCTestCase {
    private let still = [JarBody(id: 1, x: 100, y: 372, radius: 28)]

    private func run(_ quiet: inout JarQuiet, isBusy: Bool, ticks: Int) -> Bool {
        var settled = false
        for _ in 0 ..< ticks {
            settled = quiet.settled(still, isBusy: isBusy) || settled
        }
        return settled
    }

    func test果子都躺好了只要還有藤就不睡() {
        var quiet = JarQuiet()
        XCTAssertFalse(run(&quiet, isBusy: true, ticks: 1000))
        // 藤縮完才開始算，從頭算滿
        let needed = Tokens.Motion.quietFrames * Tokens.Motion.substeps
        XCTAssertFalse(run(&quiet, isBusy: false, ticks: needed - 2))
        XCTAssertTrue(run(&quiet, isBusy: false, ticks: 4))
    }
}
