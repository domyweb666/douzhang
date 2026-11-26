@testable import Douzhang
import XCTest

/// 測試用的番茄堆：寬 300、高 400。
enum JarLab {
    static func world(width: Double = 300) -> JarWorld {
        var world = JarWorld(tuning: .standard)
        world.width = width
        world.height = 400
        return world
    }

    static func body(
        _ radius: Double,
        _ x: Double,
        _ y: Double,
        velX: Double = 0,
        velY: Double = 0,
        fresh: Bool = false
    ) -> JarBody {
        JarBody(id: 0, x: x, y: y, radius: radius, velX: velX, velY: velY, fresh: fresh)
    }

    /// 照畫面那樣每幀清空再走一步，走這麼多秒。
    static func run(_ world: inout JarWorld, seconds: Int) {
        for _ in 0 ..< seconds * 60 {
            world.impact = 0
            world.landed = []
            world.step(JarWorld.frame)
        }
    }

    /// 把現場一幀一幀走這麼多秒（hertz＝螢幕一秒畫幾次），從足夠晚的時刻開始：等著掉的都到點了。
    @MainActor
    static func play(_ scene: JarScene, seconds: Double, hertz: Double = 120) {
        clock = max(clock, Date().timeIntervalSinceReferenceDate + 1)
        for _ in 0 ..< Int((seconds * hertz).rounded(.up)) {
            frame(scene, 1 / hertz)
        }
    }

    /// 隔這麼久畫一格。
    @MainActor
    static func frame(_ scene: JarScene, _ gap: Double) {
        clock += gap
        scene.advance(now: clock)
    }

    /// 這麼久一格都沒畫。
    @MainActor
    static func pass(seconds: Double) {
        clock += seconds
    }

    /// 上一格的時刻：同一個現場分幾段走，時刻不能倒退、中間也不能空一段（會被當成掉幀）
    @MainActor private static var clock: TimeInterval = 0

    /// 唯一的那顆畫在哪裡（還掛著的、或已經掉下來的）。
    @MainActor
    static func shown(_ scene: JarScene) -> CGPoint? {
        if let vine = scene.vines.holding.first {
            let pose = vine.pose(at: vine.age - (1 - scene.blend) * JarTuning.tick)
            return CGPoint(x: pose.x, y: pose.y)
        }
        let body = scene.world.bodies.first?.between(scene.blend)
        return body.map { CGPoint(x: $0.x, y: $0.y) }
    }

    /// 每次回報落地的那一幀、是哪一顆、當時多高。
    struct Landing {
        var frame: Int
        var id: Int
        var y: Double
    }

    static func landings(_ world: inout JarWorld, frames: Int) -> [Landing] {
        var seen: [Landing] = []
        for frame in 0 ..< frames {
            world.impact = 0
            world.landed = []
            world.step(JarWorld.frame)
            for id in world.landed {
                let height = world.bodies.first { $0.id == id }?.y ?? 0
                seen.append(Landing(frame: frame, id: id, y: height))
            }
        }
        return seen
    }

    /// 底排滿五顆（寬 300、半徑 28 或 30）。
    static func fillRow(_ world: inout JarWorld, radius: Double, y: Double) {
        for index in 0 ..< 5 {
            world.addBody(body(radius, 30 + Double(index) * 60, y))
        }
    }
}

/// 番茄堆物理：不穿牆、落地會回報、大小跟分鐘走、點一下會動。手感本身要真機。
/// 翻自 Expo 版 jarPhysics.test.js。
final class JarPhysicsTests: XCTestCase {
    private let tuning = JarTuning.standard

    func test重力基準半徑顆數上限與參數表同值() {
        XCTAssertEqual(tuning.gravity, 1100)
        XCTAssertEqual(tuning.radius, 28)
        XCTAssertEqual(tuning.maxBeans, 40)
    }

    func test番茄大小跟分鐘走太小太大夾住() {
        let world = JarLab.world()
        let base = tuning.radius
        XCTAssertEqual(world.radiusFor(minutes: 25), base, accuracy: 1e-9)
        let sixty = base * (60.0 / 25.0).squareRoot()
        XCTAssertEqual(world.radiusFor(minutes: 60), sixty, accuracy: 1e-9)
        XCTAssertGreaterThan(world.radiusFor(minutes: 60), world.radiusFor(minutes: 15))
        // 5 分與測試顆都不會小到看不見
        XCTAssertEqual(world.radiusFor(minutes: 5), base * 0.5, accuracy: 1e-9)
        // 刻度最長的 90 分還沒碰到上限
        let ninety = base * (90.0 / 25.0).squareRoot()
        XCTAssertEqual(world.radiusFor(minutes: 90), ninety, accuracy: 1e-9)
        // 匯入的舊檔再長也不會撐爆
        XCTAssertEqual(world.radiusFor(minutes: 200), base * 1.9, accuracy: 1e-9)
    }

    func test刻度上每一格長度的番茄都比前一格大最短的幾格一樣小() {
        let world = JarLab.world()
        let sizes = Params.typeLengths.map { world.radiusFor(minutes: $0) }
        let smallest = world.radiusFor(minutes: 1)
        for index in 1 ..< sizes.count {
            if sizes[index] > smallest {
                XCTAssertGreaterThan(sizes[index], sizes[index - 1])
            } else {
                // 太小會看不見：最短的幾格夾在下限
                XCTAssertEqual(sizes[index], smallest)
            }
        }
        XCTAssertGreaterThan(world.radiusFor(minutes: 7), smallest)
    }

    func test從上面掉一顆兩秒內落在底而且落地那一幀有回報() throws {
        var world = JarLab.world()
        world.addBody(JarLab.body(18, 150, -36, velY: -160, fresh: true))
        let seen = JarLab.landings(&world, frames: 120)
        let body = try XCTUnwrap(world.bodies.first)
        XCTAssertGreaterThan(try XCTUnwrap(seen.first).frame, 0)
        XCTAssertLessThanOrEqual(body.y, 400 - 18 + 0.01)
        XCTAssertFalse(body.fresh)
    }

    func test大小不一的四十顆安置後沒有一顆在牆外() {
        var world = JarLab.world()
        world.seed((0 ..< 40).map { $0 % 3 == 0 ? 31.0 : 13.0 })
        XCTAssertEqual(world.bodies.count, 40)
        for body in world.bodies {
            XCTAssertGreaterThanOrEqual(body.x, body.radius - 0.01)
            XCTAssertLessThanOrEqual(body.x, 300 - body.radius + 0.01)
            XCTAssertLessThanOrEqual(body.y, 400 - body.radius + 0.01)
            XCTAssertGreaterThanOrEqual(body.y, body.radius - 0.01)
        }
    }

    func test一大一小靜置後不會疊在一起() {
        var world = JarLab.world()
        world.addBody(JarLab.body(30, 150, 300))
        world.addBody(JarLab.body(12, 152, 200))
        JarLab.run(&world, seconds: 3)
        let one = world.bodies[0]
        let two = world.bodies[1]
        XCTAssertGreaterThanOrEqual(hypot(two.x - one.x, two.y - one.y), 30 + 12 - 1)
    }

    func test超過顆數上限不再撒() {
        var world = JarLab.world()
        world.seed(Array(repeating: 18, count: 100))
        XCTAssertEqual(world.bodies.count, 40)
    }

    func test還沒量到寬高時安置什麼都不撒() {
        var world = JarWorld(tuning: .standard)
        world.seed([18, 18])
        XCTAssertTrue(world.bodies.isEmpty)
    }

    func test點一下底附近落定的番茄會被彈起來() {
        var world = JarLab.world()
        world.addBody(JarLab.body(18, 150, 400 - 18))
        JarLab.run(&world, seconds: 1)
        world.tap(x: 150, y: 400 - 18)
        XCTAssertLessThan(world.bodies[0].velY, 0)
    }

    func test遠離手指的番茄不受影響() {
        var world = JarLab.world()
        world.addBody(JarLab.body(18, 30, 400 - 18))
        JarLab.run(&world, seconds: 1)
        let before = world.bodies[0].velY
        world.tap(x: 280, y: 50)
        XCTAssertEqual(world.bodies[0].velY, before)
    }

    func test手機朝下時斷藤掉下來的那顆不會從螢幕頂飛走() throws {
        var world = JarLab.world()
        world.gravityY = -300
        world.addBody(JarLab.body(28, 150, 120, velX: 60, fresh: true))
        for _ in 0 ..< 600 {
            world.step(JarTuning.tick)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(world.bodies.first).y, 28 - 1e-9)
        }
        // 從上面外面掉進來的照舊可以在上面
        var above = JarLab.world()
        above.addBody(JarLab.body(28, 150, -60, fresh: true))
        above.step(JarTuning.tick)
        XCTAssertLessThan(try XCTUnwrap(above.bodies.first).y, 0)
    }

    func test底排滿了新的一顆落在別顆上面撞到就回報只回報一次() throws {
        var world = JarLab.world()
        JarLab.fillRow(&world, radius: 28, y: 400 - 28)
        JarLab.run(&world, seconds: 1)
        world.addBody(JarLab.body(28, 150, -56, velY: -160, fresh: true))
        let seen = JarLab.landings(&world, frames: 240)
        XCTAssertEqual(seen.count, 1)
        let newest = try XCTUnwrap(world.bodies.last)
        XCTAssertEqual(seen.first?.id, newest.id)
        // 回報時還在第一排上面，不是等它碰到底
        XCTAssertLessThan(try XCTUnwrap(seen.first).y, 400 - 28 - 28)
        XCTAssertFalse(newest.fresh)
    }

    func test兩顆都還在掉半空中互撞不算落地() throws {
        var world = JarLab.world()
        world.addBody(JarLab.body(18, 150, 100, fresh: true))
        // 上面那顆比較快，半空中追撞下面那顆
        world.addBody(JarLab.body(18, 150, 40, velY: 600, fresh: true))
        let seen = JarLab.landings(&world, frames: 240)
        // 第一次回報就是碰到底那顆
        XCTAssertGreaterThan(try XCTUnwrap(seen.first).y, 400 - 18 - 1)
    }
}
