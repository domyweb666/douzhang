@testable import Douzhang
import XCTest

/// 番茄撞開始鈕與分頁列的測試共用：位置照 iPhone 402×874 的主畫面，開始鈕直徑 180，分頁列 300×64、底下留 46。
enum JarBlocks {
    static let start = JarObstacle(minX: 111, minY: 484, maxX: 291, maxY: 664)
    static let tabBar = JarObstacle(minX: 51, minY: 764, maxX: 351, maxY: 828)
    static let both = [start, tabBar]
    /// 每一步走完壓進去不到這麼多（pt）就算在外面：分頁列畫在番茄上面，壓進去一點看不到
    static let slack = 0.5

    static func blocked() -> JarWorld {
        var world = JarWorld(tuning: .standard)
        world.width = 402
        world.height = 874
        world.setObstacles(both)
        return world
    }

    /// 番茄的邊離擋路的東西多遠：負的是壓進去了。
    static func gap(_ body: JarBody, _ obstacle: JarObstacle) -> Double {
        let core = obstacle.core(x: body.x, y: body.y)
        return hypot(body.x - core.x, body.y - core.y) - obstacle.corner - body.radius
    }

    /// 開始鈕與分頁列中間只有 100pt：比這個大的（80 分以上）被堆擠到開始鈕底下時上下都推不出去，
    /// 分頁列最後推、贏，開始鈕最多蓋掉這麼多（開始鈕畫在番茄上面）
    static func squeeze(_ body: JarBody) -> Double {
        max(0, 2 * body.radius - (tabBar.minY - start.maxY))
    }

    static func deepest(_ world: JarWorld) -> Double {
        let gaps = world.bodies.flatMap { body in
            both.map { gap(body, $0) + ($0 == start ? squeeze(body) : 0) }
        }
        return gaps.min() ?? 0
    }

    /// 壓最深的那顆在哪、多大：失敗時看得出是哪一種
    static func worst(_ world: JarWorld) -> String {
        let body = world.bodies.min { one, two in
            both.map { gap(one, $0) }.min() ?? 0 < both.map { gap(two, $0) }.min() ?? 0
        }
        guard let body else { return "" }
        return "半徑 \(body.radius) 在 \(body.x), \(body.y)"
    }
}

/// 番茄撞開始鈕與分頁列：擋得住、停得上去、從旁邊滾下去，堆照樣會睡。
@MainActor
final class JarObstacleTests: XCTestCase {
    private let start = JarBlocks.start
    private let tabBar = JarBlocks.tabBar
    private let slack = JarBlocks.slack
    private let both = JarBlocks.both

    /// 照開機安置那樣撒（擋路的東西先擺好、壓在裡面的搬出來）、預跑躺好，大小與位置從固定 seed 來。
    private func pile(seed: UInt32, count: Int, mixed: Bool) -> JarWorld {
        var random = JarSeeds(state: seed)
        var world = JarBlocks.blocked()
        for _ in 0 ..< count {
            let minutes = mixed ? Double(1 + Int(random.next() * 90)) : 25
            let radius = world.radiusFor(minutes: minutes)
            let x = radius + random.next() * (world.width - 2 * radius)
            let y = radius + random.next() * (world.height - 2 * radius)
            world.addBody(JarBody(id: 0, x: x, y: y, radius: radius))
        }
        world.liftOut()
        for _ in 0 ..< world.tuning.settleSteps {
            world.step(JarWorld.frame)
        }
        world.landed = []
        return world
    }

    // MARK: 一顆

    func test從開始鈕正上方掉下來碰到圓頂就落地不會穿過最後滾到圓外() throws {
        var world = JarBlocks.blocked()
        world.addBody(JarLab.body(28, 206, -28, fresh: true))
        var landedAt: Double?
        for _ in 0 ..< JarLab.steps(4) {
            world.landed = []
            world.step(JarTuning.tick)
            let body = world.bodies[0]
            XCTAssertGreaterThan(JarBlocks.gap(body, start), -slack)
            if world.landed == [body.id] {
                landedAt = body.y
            }
        }
        // 啵在碰到圓頂那一幀，不是到底或碰到分頁列
        let landedY = try XCTUnwrap(landedAt)
        XCTAssertLessThan(landedY, start.minY)
        let body = world.bodies[0]
        XCTAssertFalse(body.fresh)
        XCTAssertGreaterThan(JarBlocks.gap(body, start), 1)
        XCTAssertGreaterThan(JarBlocks.gap(body, tabBar), -slack)
    }

    func test開始鈕下面掉的停在分頁列上面() {
        // 開始鈕與分頁列之間只有 100pt，比這個大的塞不進去
        for radius in [14.0, 28, 40] {
            var world = JarBlocks.blocked()
            world.addBody(JarLab.body(radius, 201, start.maxY + radius + 1, fresh: true))
            for _ in 0 ..< JarLab.steps(3) {
                world.step(JarTuning.tick)
            }
            let body = world.bodies[0]
            XCTAssertEqual(body.y, tabBar.minY - radius, accuracy: 0.5, "半徑 \(radius)")
            XCTAssertEqual(body.x, 201, accuracy: 1, "半徑 \(radius)")
            XCTAssertEqual(hypot(body.velX, body.velY), 0, accuracy: 20, "半徑 \(radius)")
        }
    }

    func test分頁列兩側滾下去的照樣堆到螢幕最底() {
        var world = JarBlocks.blocked()
        // 小顆的從左邊縫掉下去；大的卡在牆與膠囊圓頭之間，不會壓進去
        world.addBody(JarLab.body(14, 20, 400))
        world.addBody(JarLab.body(28, 380, 400))
        for _ in 0 ..< JarLab.steps(3) {
            world.step(JarTuning.tick)
        }
        XCTAssertEqual(world.bodies[0].y, 874 - 14, accuracy: 0.5)
        XCTAssertGreaterThan(JarBlocks.deepest(world), -slack)
        XCTAssertLessThan(world.bodies[1].y, tabBar.maxY)
    }

    func test貼著分頁列斜著會滾而且邊滾邊轉() {
        var world = JarBlocks.blocked()
        world.addBody(JarLab.body(28, 201, 736))
        for _ in 0 ..< JarLab.steps(0.25) {
            world.step(JarTuning.tick)
        }
        world.gravityX = 1100 * sin(10 * .pi / 180)
        world.gravityY = 1100 * cos(10 * .pi / 180)
        for _ in 0 ..< JarLab.steps(1) {
            world.step(JarTuning.tick)
        }
        let body = world.bodies[0]
        XCTAssertGreaterThan(body.x, 230)
        XCTAssertEqual(body.y, tabBar.minY - 28, accuracy: 0.5)
        // 往右滾是順時針
        XCTAssertGreaterThan(body.spin, 0)
    }

    // MARK: 一整堆

    func test多組隨機撒的堆沒有一顆最後壓在開始鈕或分頁列裡() {
        for seed in UInt32(1) ... 12 {
            let count = [20, 30, 40][Int(seed) % 3]
            var world = pile(seed: seed * 7919 + UInt32(count), count: count, mixed: seed % 2 == 0)
            XCTAssertGreaterThan(
                JarBlocks.deepest(world),
                -slack,
                "seed \(seed) 安置完 \(JarBlocks.worst(world))"
            )
            for _ in 0 ..< JarLab.steps(2) {
                world.step(JarTuning.tick)
            }
            XCTAssertGreaterThan(
                JarBlocks.deepest(world),
                -slack,
                "seed \(seed) 再走兩秒 \(JarBlocks.worst(world))"
            )
            for body in world.bodies {
                XCTAssertGreaterThanOrEqual(body.x, body.radius - slack, "seed \(seed)")
                XCTAssertLessThanOrEqual(body.x, 402 - body.radius + slack, "seed \(seed)")
                XCTAssertLessThanOrEqual(body.y, 874 - body.radius + slack, "seed \(seed)")
            }
        }
    }

    func test開機安置也會避開() {
        for count in [20, 40] {
            var world = JarBlocks.blocked()
            world.seed((0 ..< count).map { [14.0, 18, 22, 28, 31, 53][$0 % 6] })
            XCTAssertGreaterThan(
                JarBlocks.deepest(world),
                -slack,
                "\(count) 顆 \(JarBlocks.worst(world))"
            )
        }
    }

    func test停在分頁列上的堆會睡著() async {
        let scene = JarScene()
        scene.setObstacles(both)
        let beans = Array(repeating: JarBean(len: 25, color: .red), count: 20)
        scene.layout(width: 402, height: 874, beans: beans, seen: beans.count)
        for _ in 0 ..< 100 where !scene.asleep {
            JarLab.play(scene, seconds: 0.1)
            await Task.yield()
        }
        XCTAssertTrue(scene.asleep)
        let onBar = scene.world.bodies
            .filter { $0.y < tabBar.minY && JarBlocks.gap($0, tabBar) < 1 }
        XCTAssertFalse(onBar.isEmpty)
    }

    func test從藤上掉下來的那顆照樣落地再睡() async {
        let scene = JarScene()
        scene.setObstacles(both)
        let beans = Array(repeating: JarBean(len: 25, color: .red), count: 10)
        scene.layout(width: 402, height: 874, beans: beans, seen: beans.count - 1)
        for _ in 0 ..< 150 where !scene.asleep {
            JarLab.play(scene, seconds: 0.1)
            await Task.yield()
        }
        let fastest = scene.world.bodies.max { hypot($0.velX, $0.velY) < hypot($1.velX, $1.velY) }
        XCTAssertTrue(scene.asleep, "最快那顆 \(String(describing: fastest)) 藤 \(scene.vines.isEmpty)")
        XCTAssertEqual(scene.world.bodies.count, beans.count)
        XCTAssertFalse(scene.world.bodies.contains(where: \.fresh))
        XCTAssertGreaterThan(JarBlocks.deepest(scene.world), -slack)
    }
}

/// 開始鈕與分頁列後來才擺上來（量框比安置晚、字級變了），與量框本身。
@MainActor
final class JarObstacleLateTests: XCTestCase {
    private let start = JarBlocks.start
    private let tabBar = JarBlocks.tabBar
    private let slack = JarBlocks.slack
    private let both = JarBlocks.both

    func test擋路的東西後來才擺上來壓在裡面的被搬出來速度不爆() {
        var world = JarLab.pile(seed: 7, count: 40, mixed: true)
        XCTAssertLessThan(JarBlocks.deepest(world), -10)
        world.setObstacles(both)
        XCTAssertGreaterThan(JarBlocks.deepest(world), -slack)
        var fastest = 0.0
        for _ in 0 ..< JarLab.steps(3) {
            world.step(JarTuning.tick)
            fastest = max(fastest, world.bodies.map { hypot($0.velX, $0.velY) }.max() ?? 0)
        }
        XCTAssertLessThan(fastest, 800)
        XCTAssertGreaterThan(JarBlocks.deepest(world), -slack, JarBlocks.worst(world))
    }

    func test正中間壓在裡面的往上搬() {
        var world = JarLab.world(width: 402)
        world.height = 874
        world.addBody(JarLab.body(28, 201, 796, velX: 300, velY: -500))
        world.setObstacles(both)
        let body = world.bodies[0]
        XCTAssertEqual(body.y, tabBar.minY - 28, accuracy: 0.01)
        XCTAssertEqual(body.velX, 0)
        XCTAssertEqual(body.velY, 0)
    }

    func test同樣的框再給一次不會吵醒睡著的堆() async {
        let scene = JarScene()
        scene.setObstacles(both)
        let beans = Array(repeating: JarBean(len: 25, color: .red), count: 5)
        scene.layout(width: 402, height: 874, beans: beans, seen: beans.count)
        for _ in 0 ..< 100 where !scene.asleep {
            JarLab.play(scene, seconds: 0.1)
            await Task.yield()
        }
        XCTAssertTrue(scene.asleep)
        scene.setObstacles(both)
        XCTAssertTrue(scene.asleep)
        scene.setObstacles([tabBar])
        XCTAssertFalse(scene.asleep)
    }

    func test減少動態時後來才擺上來也當場躺好() {
        let scene = JarScene()
        scene.reduceMotion = true
        let beans = Array(repeating: JarBean(len: 25, color: .red), count: 20)
        scene.layout(width: 402, height: 874, beans: beans, seen: beans.count)
        scene.setObstacles(both)
        XCTAssertGreaterThan(JarBlocks.deepest(scene.world), -slack, JarBlocks.worst(scene.world))
        let spots = scene.world.bodies
        for (index, one) in spots.enumerated() {
            for two in spots.dropFirst(index + 1) {
                let apart = hypot(one.x - two.x, one.y - two.y) - one.radius - two.radius
                // 堆在底下的本來就會被上面壓進去幾點；搬出來沒安置的會疊成一整顆
                XCTAssertGreaterThan(apart, -10)
            }
        }
    }

    // MARK: 量框

    func test滑到一半量到的框不拿來擺分頁列() {
        let place = JarPlace()
        let bar = CGRect(x: 51, y: 764, width: 300, height: 64)
        XCTAssertFalse(place.setTabBar(bar))
        XCTAssertTrue(place.setScreen(CGRect(x: 0, y: 0, width: 402, height: 874)))
        XCTAssertEqual(place.obstacles, [tabBar])
        // 往左滑了 120pt：番茄堆跟著動，分頁列沒動
        XCTAssertFalse(place.setScreen(CGRect(x: -120, y: 0, width: 402, height: 874)))
        XCTAssertEqual(place.obstacles, [tabBar])
        place.start = CGRect(x: 111, y: 484, width: 180, height: 180)
        XCTAssertEqual(place.obstacles, [start, tabBar])
    }
}
