@testable import Douzhang
import XCTest

/// 番茄堆一週一堆：同一週換日不清空、到下週一才清；這台剛收的那顆排最後才會從上面掉。
final class JarWeekTests: XCTestCase {
    /// 這幾天各收了哪幾顆，當天 0 點過後一分鐘一顆。2026-11-23 是週一。
    private func state(_ days: [String: [String]]) -> AppState {
        var made = Store.blank()
        for (key, ids) in days {
            let start = DayKeys.start(key)
            let beans = ids.enumerated().map { index, id in
                SyncSample.bean(id, at: start + Double(index + 1) * Moment.minute)
            }
            made.days[key] = DayRecord(beans: beans)
        }
        return made
    }

    func test同一週換日番茄堆不變() {
        let made = state(["2026-11-23": ["a", "b"], "2026-11-25": ["c"]])
        let wednesday = JarWeek.beans(made, todayKey: "2026-11-25", fresh: nil).map(\.id)
        let sunday = JarWeek.beans(made, todayKey: "2026-11-29", fresh: nil).map(\.id)
        XCTAssertEqual(wednesday, ["a", "b", "c"])
        XCTAssertEqual(sunday, wednesday)
        XCTAssertEqual(JarWeek.count(made, todayKey: "2026-11-29"), 3)
    }

    func test跨到下週一上週的就不放() {
        let made = state(["2026-11-29": ["a"], "2026-11-30": ["b"]])
        XCTAssertEqual(JarWeek.beans(made, todayKey: "2026-11-29", fresh: nil).map(\.id), ["a"])
        XCTAssertEqual(JarWeek.beans(made, todayKey: "2026-11-30", fresh: nil).map(\.id), ["b"])
        XCTAssertEqual(JarWeek.count(made, todayKey: "2026-12-01"), 1)
    }

    func test這台剛收的那顆排最後就算別台的比較晚() {
        let made = state(["2026-11-24": ["mine", "other"]])
        let list = JarWeek.beans(made, todayKey: "2026-11-26", fresh: "mine").map(\.id)
        XCTAssertEqual(list, ["other", "mine"])
    }

    // MARK: 放不下時縮小

    func test放得下是一放不下就縮到剛好裝滿() {
        XCTAssertEqual(JarFit.scale(radii: [28, 28], width: 402, height: 874, share: 0.3), 1)
        let radii = Array(repeating: 28.0, count: 100)
        let scale = JarFit.scale(radii: radii, width: 402, height: 874, share: 0.3)
        XCTAssertLessThan(scale, 1)
        let area = radii.reduce(0) { $0 + Double.pi * $1 * scale * $1 * scale }
        XCTAssertEqual(area, 402 * 874 * 0.3, accuracy: 1e-6)
        let twice = JarFit.scale(radii: radii + radii, width: 402, height: 874, share: 0.3)
        XCTAssertLessThan(twice, scale)
        // 還沒量到寬高不縮
        XCTAssertEqual(JarFit.scale(radii: radii, width: 0, height: 0, share: 0.3), 1)
    }

    // MARK: 傾斜的重力保底

    func test斜著拿方向照傾斜大小保底() {
        let full = Tokens.Motion.tiltPerG
        let back = JarPull.gravity(x: 0, y: -cos(40 * Double.pi / 180))
        XCTAssertEqual(back.x, 0, accuracy: 1e-9)
        XCTAssertEqual(back.y, JarTuning.tiltFloor * full, accuracy: 1e-9)
        let side = JarPull.gravity(x: 0.3, y: -0.4)
        XCTAssertEqual(side.x / side.y, 0.3 / 0.4, accuracy: 1e-9)
        XCTAssertEqual(hypot(side.x, side.y), JarTuning.tiltFloor * full, accuracy: 1e-9)
        // 直拿本來就超過保底，不變
        XCTAssertEqual(JarPull.gravity(x: 0, y: -1).y, full, accuracy: 1e-9)
    }

    func test幾乎平放不保底() {
        let full = Tokens.Motion.tiltPerG
        let flat = JarPull.gravity(x: 0.1, y: -0.05)
        XCTAssertEqual(flat.x, 0.1 * full, accuracy: 1e-9)
        XCTAssertEqual(flat.y, 0.05 * full, accuracy: 1e-9)
        XCTAssertEqual(JarPull.gravity(x: 0, y: 0).y, 0)
    }
}

/// 一週的番茄進了番茄堆：放不下全部一起縮、都畫；畫到上限只放最近的。
@MainActor
final class JarWeekSceneTests: XCTestCase {
    private let red = JarBean(len: 25, color: .red)

    private func mounted(_ beans: [JarBean]) -> JarScene {
        let scene = JarScene()
        scene.layout(width: 402, height: 874, beans: beans, seen: beans.count)
        return scene
    }

    func test放不下時全部等比縮小而且每顆都畫() {
        let scene = mounted(Array(repeating: red, count: 80))
        XCTAssertEqual(scene.world.bodies.count, 80)
        XCTAssertLessThan(scene.scale, 1)
        let area = scene.world.bodies.reduce(0) { $0 + Double.pi * $1.radius * $1.radius }
        XCTAssertEqual(area, 402 * 874 * JarTuning.standard.fillShare, accuracy: 1)
        XCTAssertEqual(scene.world.bodies.first?.radius ?? 0, 28 * scene.scale, accuracy: 1e-9)
    }

    func test放得下照原本大小() {
        let scene = mounted(Array(repeating: red, count: 10))
        XCTAssertEqual(scene.scale, 1)
        XCTAssertEqual(scene.world.bodies.first?.radius, 28)
    }

    func test多一顆放不下了已經在裡面的跟著縮小() throws {
        // 42 顆 25 分剛好還放得下
        let full = Array(repeating: red, count: 42)
        let scene = mounted(full)
        XCTAssertEqual(scene.scale, 1)
        scene.follow(full + [JarBean(len: 90, color: .yellow)])
        JarLab.play(scene, seconds: 0.5)
        XCTAssertLessThan(scene.scale, 1)
        XCTAssertEqual(scene.world.bodies.first?.radius ?? 0, 28 * scene.scale, accuracy: 1e-9)
        let hung = try XCTUnwrap(scene.vines.holding.first)
        let ninety = scene.world.radiusFor(minutes: 90)
        XCTAssertEqual(hung.radius, ninety * scene.scale, accuracy: 1e-9)
    }

    func test超過上限開機安置只擺最近的() {
        let many = (0 ..< 130).map { JarBean(len: 25, color: $0 < 10 ? .yellow : .red) }
        let scene = mounted(many)
        XCTAssertEqual(scene.world.bodies.count, 120)
        XCTAssertFalse(scene.world.bodies.contains { scene.color(of: $0) == .yellow })
        XCTAssertEqual(scene.known, 130)
    }

    func test畫到上限再收一顆拿掉最早那顆() throws {
        let many = (0 ..< 120).map { JarBean(len: 25, color: $0 == 0 ? .yellow : .red) }
        let scene = mounted(many)
        let oldest = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertEqual(scene.color(of: oldest), .yellow)
        // 靜止版：新的一顆直接放在底，不用等藤
        scene.reduceMotion = true
        scene.follow(many + [JarBean(len: 25, color: .pink)])
        scene.advance(now: Date().timeIntervalSinceReferenceDate + 1)
        XCTAssertEqual(scene.world.bodies.count, 120)
        XCTAssertFalse(scene.world.bodies.contains { $0.id == oldest.id })
        let newest = try XCTUnwrap(scene.world.bodies.last)
        XCTAssertEqual(scene.color(of: newest), .pink)
    }
}
