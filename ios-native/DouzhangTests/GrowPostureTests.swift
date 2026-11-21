@testable import Douzhang
import XCTest

/// 計時中長大的番茄：走了幾成、畫多大、什麼顏色。翻自 Expo 版 grow.test.js。
final class GrowTests: XCTestCase {
    private let base = Moment.local(2026, 11, 17, 9)
    private let minute = Moment.minute
    private let unripe = RGB(red: 0.5, green: 0.75, blue: 0.25)
    private let ripe = RGB(red: 1, green: 0.25, blue: 0.25)

    func test剛開始是零一半是零點五到點是一過了也不超過一() {
        let current = Machine.start(Store.blank(), now: base).current
        XCTAssertEqual(Grow.progress(current, now: base), 0)
        XCTAssertEqual(Grow.progress(current, now: base + 12.5 * minute), 0.5)
        XCTAssertEqual(Grow.progress(current, now: base + 25 * minute), 1)
        XCTAssertEqual(Grow.progress(current, now: base + 40 * minute), 1)
    }

    func test再做一下的那段維持全熟不倒回去變青() {
        let rang = base + 25 * minute
        let focusing = Machine.start(Store.blank(), now: base)
        let more = Machine.flow(focusing, now: rang + minute, minutes: 15).current
        XCTAssertEqual(Grow.progress(more, now: rang + 2 * minute), 1)
    }

    func test沒在計時是零() {
        XCTAssertEqual(Grow.progress(nil, now: base), 0)
        let focusing = Machine.start(Store.blank(), now: base)
        let rest = Machine.keep(focusing, now: base + 25 * minute, text: "").current
        XCTAssertEqual(Grow.progress(rest, now: base + 26 * minute), 0)
    }

    func test大小從最小那一成一路長到全熟只變大() {
        XCTAssertEqual(Grow.scale(0), Params.growMinScale)
        XCTAssertEqual(Grow.scale(1), 1)
        XCTAssertGreaterThan(Grow.scale(0.5), Grow.scale(0.25))
        XCTAssertEqual(Grow.scale(2), 1)
    }

    func test顏色開始是青的到點是標籤色中間是兩色各一半() {
        XCTAssertEqual(Grow.ripeColor(0, unripe: unripe, ripe: ripe), unripe)
        XCTAssertEqual(Grow.ripeColor(1, unripe: unripe, ripe: ripe), ripe)
        XCTAssertEqual(Grow.ripeColor(3, unripe: unripe, ripe: ripe), ripe)
        let half = Grow.ripeColor(0.5, unripe: unripe, ripe: ripe)
        XCTAssertEqual(half, RGB(red: 0.75, green: 0.5, blue: 0.25))
    }
}

/// 姿勢判斷（聚焦模式）：直拿、橫放、平放分得出來，要維持一下才算。翻自 Expo 版 posture.test.js。
final class PostureTests: XCTestCase {
    private let upright = Acceleration(x: 0, y: -1, z: 0)
    private let side = Acceleration(x: 1, y: 0, z: 0)
    private let otherSide = Acceleration(x: -1, y: 0, z: 0)
    private let flat = Acceleration(x: 0, y: 0, z: -1)
    private let dwell = Params.Zen.dwellMs
    private let sample = Params.Zen.sampleMs

    private struct Held {
        var tracker: PoseTracker
        var changes: [Pose]
        var clock: Millis
    }

    /// 每 sampleMs 餵一筆同樣的加速度，餵 span 這麼久；回最後的追蹤狀態與途中確定換成的姿勢。
    private func hold(
        _ from: PoseTracker,
        _ reading: Acceleration,
        at start: Millis,
        for span: Double
    ) -> Held {
        var held = Held(tracker: from, changes: [], clock: start)
        while held.clock <= start + span {
            let step = Posture.track(held.tracker, sample: reading, now: held.clock)
            held.tracker = step.tracker
            if let changed = step.changed {
                held.changes.append(changed)
            }
            held.clock += sample
        }
        return held
    }

    func test直拿橫放兩邊平放分得出來單位不影響() {
        XCTAssertEqual(Posture.poseOf(upright), .portrait)
        XCTAssertEqual(Posture.poseOf(side), .landscape)
        XCTAssertEqual(Posture.poseOf(otherSide), .landscape)
        XCTAssertNil(Posture.poseOf(flat))
        XCTAssertEqual(Posture.poseOf(Acceleration(x: 9.8, y: 0.5, z: 1)), .landscape)
        XCTAssertNil(Posture.poseOf(Acceleration(x: 0, y: 0, z: 0)))
    }

    func test斜四十五度拿著兩個都不算() {
        XCTAssertNil(Posture.poseOf(Acceleration(x: 0.7, y: -0.7, z: 0)))
    }

    func test橫放維持夠久才算而且只回報一次() {
        let short = hold(PoseTracker(), side, at: 0, for: dwell - sample)
        XCTAssertEqual(short.changes, [])
        let long = hold(PoseTracker(), side, at: 0, for: dwell * 3)
        XCTAssertEqual(long.changes, [.landscape])
    }

    func test拿起來晃一下又回到直拿不算() {
        let first = hold(PoseTracker(), side, at: 0, for: dwell - sample)
        let second = hold(first.tracker, upright, at: first.clock, for: dwell * 2)
        let third = hold(second.tracker, side, at: second.clock, for: dwell - sample)
        XCTAssertEqual(first.changes + second.changes + third.changes, [])
    }

    func test橫放之後平放在桌上維持橫放() {
        let first = hold(PoseTracker(), side, at: 0, for: dwell * 2)
        let second = hold(first.tracker, flat, at: first.clock, for: dwell * 5)
        XCTAssertEqual(second.changes, [])
        XCTAssertEqual(second.tracker.pose, .landscape)
    }

    func test橫放再直拿回來先回報橫放再回報直拿() {
        let first = hold(PoseTracker(), side, at: 0, for: dwell * 2)
        let second = hold(first.tracker, upright, at: first.clock, for: dwell * 2)
        XCTAssertEqual(first.changes + second.changes, [.landscape, .portrait])
    }

    func test橫放時左右翻面還是橫放不回報() {
        let first = hold(PoseTracker(), side, at: 0, for: dwell * 2)
        let second = hold(first.tracker, otherSide, at: first.clock, for: dwell * 2)
        XCTAssertEqual(second.changes, [])
    }
}
