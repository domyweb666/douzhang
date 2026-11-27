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

    /// 卡在別顆中間原地來回抖的（每 1/60 秒常常走過門檻，平均位置卻不動）：兩秒內也算躺好。
    /// 以前靠真的物理堆出來的抖堆測；改物理之後那幾堆不抖了，改成直接餵抖的位置。
    func test原地來回抖的兩秒內也會睡() throws {
        var quiet = JarQuiet()
        var settledAt: Int?
        for tick in 0 ..< 600 where settledAt == nil {
            let look = Double(tick / Tokens.Motion.substeps)
            let shake = 0.6 * sin(2 * Double.pi * look / 7)
            let body = JarBody(id: 1, x: 100 + shake, y: 372, radius: 28)
            if quiet.settled([body], isBusy: false) {
                settledAt = tick
            }
        }
        let tick = try XCTUnwrap(settledAt)
        XCTAssertLessThan(Double(tick) * JarTuning.tick, 2)
    }
}
