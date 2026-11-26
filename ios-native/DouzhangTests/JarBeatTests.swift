@testable import Douzhang
import XCTest

/// 番茄堆的碰撞：什麼時候嗒、震多大力。
final class JarBeatTests: XCTestCase {
    func test沒過門檻不嗒過了才嗒() {
        var beat = JarBeat()
        XCTAssertFalse(beat.hits(impact: Tokens.Sound.hitThreshold, now: 10))
        XCTAssertTrue(beat.hits(impact: Tokens.Sound.hitThreshold + 1, now: 10))
    }

    func test離上一下太近不嗒() {
        var beat = JarBeat()
        XCTAssertTrue(beat.hits(impact: 900, now: 10))
        XCTAssertFalse(beat.hits(impact: 900, now: 10 + Tokens.Sound.hitGap / 2))
        XCTAssertTrue(beat.hits(impact: 900, now: 10 + Tokens.Sound.hitGap * 2))
    }

    func test落地啵過之後緊接著的碰撞不再嗒() {
        var beat = JarBeat()
        beat.landed(now: 10)
        XCTAssertFalse(beat.hits(impact: 900, now: 10 + JarWorld.frame))
        XCTAssertTrue(beat.hits(impact: 900, now: 10 + Tokens.Sound.hitGap * 2))
    }

    func test撞得越快震得越重而且分得出來() {
        let light = JarBeat.strength(Tokens.Sound.hitThreshold)
        let middle = JarBeat.strength(700)
        let hard = JarBeat.strength(Tokens.Sound.hitTapFull)
        XCTAssertEqual(light, Tokens.Sound.hitTapMin, accuracy: 0.001)
        XCTAssertGreaterThan(middle, light + 0.1)
        XCTAssertGreaterThan(hard, middle + 0.1)
        XCTAssertEqual(hard, 1, accuracy: 0.001)
        XCTAssertEqual(JarBeat.strength(5000), 1, accuracy: 0.001)
    }

    func test嗒排到時晚太多就不播() {
        XCTAssertFalse(JarBeat.isLate(asked: 10, now: 10 + Tokens.Sound.hitLate * 0.9))
        XCTAssertTrue(JarBeat.isLate(asked: 10, now: 10 + Tokens.Sound.hitLate * 1.1))
    }
}
