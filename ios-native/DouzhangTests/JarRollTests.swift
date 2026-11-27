@testable import Douzhang
import XCTest

/// 在底上滾得順不順：斜著會一直加速、放平會自己停、歪一點點不爬，而且跟螢幕多快無關。
@MainActor
final class JarRollTests: XCTestCase {
    /// 底上一顆，先躺穩。degrees 是手機左右斜幾度。
    private func onFloor(degrees: Double, velX: Double = 0, width: Double = 4000) -> JarWorld {
        var world = JarLab.world(width: width)
        world.addBody(JarLab.body(28, 500, 400 - 28))
        walk(&world, seconds: 0.25)
        world.bodies[0].velX = velX
        world.gravityX = 1100 * sin(degrees * .pi / 180)
        world.gravityY = 1100 * cos(degrees * .pi / 180)
        return world
    }

    private func walk(_ world: inout JarWorld, seconds: Double) {
        for _ in 0 ..< Int((seconds / JarTuning.tick).rounded()) {
            world.step(JarTuning.tick)
        }
    }

    /// 滾過這麼遠要幾秒。
    private func timeToRoll(_ distance: Double, degrees: Double) -> Double {
        var world = onFloor(degrees: degrees)
        let start = world.bodies[0].x
        var time = 0.0
        while world.bodies[0].x - start < distance, time < 30 {
            world.step(JarTuning.tick)
            time += JarTuning.tick
        }
        return time
    }

    /// 2026-11-27 空氣阻力從 0.996 改 0.9995，底的摩擦跟著補回去（每步空氣×摩擦不變），秒數照舊。
    func test斜著滾過四百點的秒數跟挑數字時的模擬一樣() {
        XCTAssertEqual(timeToRoll(400, degrees: 15), 2.69, accuracy: 0.1)
        XCTAssertEqual(timeToRoll(400, degrees: 5), 7.29, accuracy: 0.2)
    }

    func test斜著的時候一直在加速不是等速爬() {
        var world = onFloor(degrees: 5)
        var speeds: [Double] = []
        for _ in 0 ..< 4 {
            walk(&world, seconds: 0.5)
            speeds.append(world.bodies[0].velX)
        }
        XCTAssertEqual(speeds, speeds.sorted())
        XCTAssertGreaterThan(speeds[3], speeds[0] * 1.6)
    }

    func test放平後自己停不會一撞底就黏住也不會拖很久() {
        var world = onFloor(degrees: 0, velX: 200)
        walk(&world, seconds: 1)
        XCTAssertGreaterThan(world.bodies[0].velX, 30)
        walk(&world, seconds: 1.5)
        XCTAssertEqual(world.bodies[0].velX, 0)
    }

    func test桌子歪半度不會自己爬() {
        var world = onFloor(degrees: 0.5)
        walk(&world, seconds: 3)
        XCTAssertEqual(world.bodies[0].x, 500, accuracy: 0.5)
    }

    func test六十赫茲與一百二十赫茲滾得一樣遠() throws {
        var moved: [Double] = []
        for hertz in [60.0, 120.0] {
            let scene = JarScene()
            let beans = [JarBean(len: 25, color: .red)]
            scene.layout(width: 4000, height: 852, beans: beans, seen: 1)
            let start = try XCTUnwrap(scene.world.bodies.first).x
            // 往比較遠的那一側斜，不會撞牆
            let side = start > 2000 ? -1.0 : 1.0
            scene.targetX = side * 200
            JarLab.play(scene, seconds: 2, hertz: hertz)
            let end = try XCTUnwrap(scene.world.bodies.first).x
            moved.append((end - start) * side)
        }
        XCTAssertGreaterThan(moved[0], 100)
        XCTAssertEqual(moved[0], moved[1], accuracy: 3)
    }

    func test畫面落在兩步之間時照比例補() {
        var body = JarLab.body(28, 100, 200)
        body.markStep()
        body.x = 110
        body.y = 190
        body.angle = 1
        XCTAssertEqual(body.between(0).x, 100)
        XCTAssertEqual(body.between(0.5).y, 195)
        XCTAssertEqual(body.between(0.5).angle, 0.5)
        XCTAssertEqual(body.between(1).x, 110)
    }

    // MARK: 躺好了沒

    /// 從現在起走這麼久，有沒有被判成躺好。
    private func settles(_ world: JarWorld, seconds: Double) -> Bool {
        var moving = world
        var quiet = JarQuiet()
        for _ in 0 ..< Int(seconds / JarTuning.tick) {
            moving.step(JarTuning.tick)
            if quiet.settled(moving.bodies, isBusy: false) {
                return true
            }
        }
        return false
    }

    func test不動的半秒多就算躺好() {
        XCTAssertTrue(settles(onFloor(degrees: 0), seconds: 0.6))
        XCTAssertFalse(settles(onFloor(degrees: 0), seconds: 0.4))
    }

    func test斜一點點慢慢起步的不會滾到一半被當成躺好() {
        for degrees in [2.0, 3, 5] {
            XCTAssertFalse(settles(onFloor(degrees: degrees), seconds: 4), "\(degrees) 度")
        }
    }

    func test還有要掉的就不算躺好() {
        var quiet = JarQuiet()
        let world = onFloor(degrees: 0)
        for _ in 0 ..< 240 {
            XCTAssertFalse(quiet.settled(world.bodies, isBusy: true))
        }
    }

    // MARK: 掉幀的退路

    private func runSlow(_ hertz: Double, seconds: Double) -> Bool {
        var watch = SlowWatch()
        for frame in 0 ..< Int(seconds * hertz) {
            watch.count(now: 100 + Double(frame) / hertz)
        }
        return watch.tooSlow
    }

    func test一百二十與六十赫茲都不算慢三十才算() {
        XCTAssertFalse(runSlow(120, seconds: 20))
        XCTAssertFalse(runSlow(60, seconds: 20))
        XCTAssertTrue(runSlow(30, seconds: 6))
    }

    func test一百二十赫茲掉到一半也不算慢() {
        var watch = SlowWatch()
        var now = 100.0
        for frame in 0 ..< 2000 {
            now += frame.isMultiple(of: 3) ? 1.0 / 60 : 1.0 / 120
            watch.count(now: now)
        }
        XCTAssertFalse(watch.tooSlow)
    }

    /// 開機安置要多久：回待機那一下在主執行緒上做的。一週一堆最多 120 顆（縮小到放得下）。
    /// 這裡是除錯版，比上架版慢很多倍，只拿來跟自己比；量上架版要用 Release 跑。
    func test一百二十顆開機安置的時間() {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(options: options) {
            var world = JarLab.world(width: 402)
            world.height = 874
            world.seed((0 ..< 120).map { [9.0, 12, 14, 18, 20][$0 % 5] })
        }
    }
}
