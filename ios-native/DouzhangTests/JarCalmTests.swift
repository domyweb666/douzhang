@testable import Douzhang
import XCTest

/// 睡著時醒不醒：手抖醒不了，真的斜了很快就醒；睡著讀慢、醒來讀快。
@MainActor
final class JarCalmTests: XCTestCase {
    private let restY = JarTuning.standard.gravity

    /// 第幾秒的讀數換成重力單位（只斜左右），一秒讀 restRate 次，回平滑後最大偏了多少、第幾個讀數過門檻。
    private func watch(seconds: Double, tiltG: (Double) -> Double) -> (most: Double, wokeAt: Int?) {
        var calm = JarCalm()
        var most = 0.0
        var wokeAt: Int?
        for index in 1 ... Int(seconds * Tokens.Motion.restRate) {
            let time = Double(index) / Tokens.Motion.restRate
            let x = tiltG(time) * Tokens.Motion.tiltPerG
            let shift = calm.shift(x: x, y: restY, gravityX: 0, gravityY: restY)
            most = max(most, shift)
            if wokeAt == nil, shift > Tokens.Motion.tiltWake {
                wokeAt = index
            }
        }
        return (most, wokeAt)
    }

    /// 斜 degrees 度，左右那一軸讀到幾 g
    private func lean(_ degrees: Double) -> Double {
        sin(degrees * .pi / 180)
    }

    func test手抖的小雜訊沒平滑會醒平滑後醒不了() {
        let shake = 0.03
        // 改前比的是原始讀數：這麼大的抖動一下就過門檻
        XCTAssertGreaterThan(shake * Tokens.Motion.tiltPerG, Tokens.Motion.tiltWake)
        let flicker = watch(seconds: 10) { time in
            Int((time * Tokens.Motion.restRate).rounded()).isMultiple(of: 2) ? shake : -shake
        }
        XCTAssertNil(flicker.wokeAt)
        // 手抖大約一秒 8 到 12 下
        for hertz in [8.0, 10, 12] {
            let tremor = watch(seconds: 10) { time in shake * sin(2 * .pi * hertz * time + 0.3) }
            XCTAssertNil(tremor.wokeAt, "\(hertz) 下")
            XCTAssertLessThan(tremor.most, Tokens.Motion.tiltWake)
        }
    }

    func test一下子斜五度第一個讀數就醒() {
        XCTAssertEqual(watch(seconds: 1) { _ in self.lean(5) }.wokeAt, 1)
    }

    func test半秒慢慢斜到五度三個讀數內醒() throws {
        let ramp = watch(seconds: 1) { time in self.lean(5 * min(1, time / 0.5)) }
        let woke = try XCTUnwrap(ramp.wokeAt)
        XCTAssertLessThanOrEqual(woke, 3)
    }

    func test睡著讀慢點一下醒來馬上讀快() async {
        let scene = JarScene()
        scene.layout(width: 393, height: 852, beans: [JarBean(len: 5, color: .yellow)], seen: 1)
        XCTAssertEqual(scene.sensorInterval, JarWorld.frame)
        for _ in 0 ..< 100 where !scene.asleep {
            JarLab.play(scene, seconds: 0.1)
            await Task.yield()
        }
        XCTAssertTrue(scene.asleep)
        XCTAssertEqual(scene.sensorInterval, 1 / Tokens.Motion.restRate)
        scene.tap(x: 196, y: 800)
        XCTAssertFalse(scene.asleep)
        XCTAssertEqual(scene.sensorInterval, JarWorld.frame)
    }
}
