@testable import Douzhang
import XCTest

/// 測試用的亂數：給同一個 seed 每次都一樣（系統的亂數給不了 seed）。照 mulberry32。
struct JarSeeds {
    var state: UInt32

    mutating func next() -> Double {
        state &+= 0x6D2B_79F5
        var mixed = (state ^ (state >> 15)) &* (1 | state)
        mixed = (mixed &+ ((mixed ^ (mixed >> 7)) &* (61 | mixed))) ^ mixed
        return Double(mixed ^ (mixed >> 14)) / 4_294_967_296
    }
}

extension JarLab {
    /// 照開機安置那樣撒、預跑躺好，只是大小、位置、歪度都從固定 seed 來。iPhone 的 402×874。
    /// mixed：每顆 1–90 分隨機；不然都是 25 分。
    static func pile(seed: UInt32, count: Int, mixed: Bool) -> JarWorld {
        var random = JarSeeds(state: seed)
        var world = JarWorld(tuning: .standard)
        world.width = 402
        world.height = 874
        var radii: [Double] = []
        for _ in 0 ..< count {
            let minutes = mixed ? Double(1 + Int(random.next() * 90)) : 25
            radii.append(world.radiusFor(minutes: minutes))
        }
        for radius in radii {
            let x = radius + random.next() * max(0, world.width - 2 * radius)
            let y = radius + random.next() * max(0, world.height - 2 * radius)
            world.addBody(JarBody(id: 0, x: x, y: y, radius: radius))
        }
        for _ in 0 ..< world.tuning.settleSteps {
            world.step(JarWorld.frame)
        }
        world.landed = []
        for index in world.bodies.indices {
            world.bodies[index].angle = (random.next() * 2 - 1) * world.tuning.spin.lean
            world.bodies[index].spin = 0
            world.bodies[index].markStep()
        }
        return world
    }

    /// 這麼多秒是物理的幾步。
    static func steps(_ seconds: Double) -> Int {
        Int((seconds / JarTuning.tick).rounded())
    }

    /// 20 顆：靜置 1 秒 → 往右斜 10 度 1.5 秒 → 放平 → 3 秒點底中間 → 3.5 秒從上面掉一顆 25 分的。
    /// 回掉下來之後第一次判成躺好的那一步（從頭數，沒睡回 nil），與那一步每顆的位置。
    static func dropTiltRoll() -> (tick: Int?, world: JarWorld) {
        var world = pile(seed: 7, count: 20, mixed: true)
        var quiet: JarQuiet?
        for tick in 0 ..< steps(12) {
            if tick == steps(1) {
                world.gravityX = 1100 * sin(10 * .pi / 180)
                world.gravityY = 1100 * cos(10 * .pi / 180)
            }
            if tick == steps(2.5) {
                world.gravityX = 0
                world.gravityY = 1100
            }
            if tick == steps(3) {
                world.tap(x: 201, y: 850)
            }
            if tick == steps(3.5) {
                world.addBody(body(28, 201, -28, fresh: true))
                quiet = JarQuiet()
            }
            world.step(JarTuning.tick)
            if quiet?.settled(world.bodies, isBusy: false) == true {
                return (tick, world)
            }
        }
        return (nil, world)
    }
}

/// 堆會睡：掉、斜、滾、點過之後都會再睡著，以前卡在原地抖的那幾堆也是。
/// 原地抖本身的判斷在 JarQuietTests（不靠物理，直接餵抖的位置）。
final class JarShakeTests: XCTestCase {
    private func step(_ seconds: Double) -> Int {
        JarLab.steps(seconds)
    }

    /// 2026-11-27 物理改過（空氣阻力、摩擦一步一次、八次迭代、照大小分推開），改前逐顆的位置不再適用，
    /// 改成看這一整段走完會睡、每顆都在罐子裡、沒有兩顆疊得太深。
    func test掉落傾斜滾動之後會睡而且每顆都好好的() throws {
        let (tick, world) = JarLab.dropTiltRoll()
        XCTAssertGreaterThan(try XCTUnwrap(tick), step(3.5))
        XCTAssertEqual(world.bodies.count, 21)
        for body in world.bodies {
            XCTAssertGreaterThanOrEqual(body.x, body.radius - 0.5)
            XCTAssertLessThanOrEqual(body.x, 402 - body.radius + 0.5)
            XCTAssertLessThanOrEqual(body.y, 874 - body.radius + 0.5)
        }
        // 夾在大顆中間的小顆還是會被壓進去一點（推開照半徑平方分的話會到十幾點）
        for (index, one) in world.bodies.enumerated() {
            for two in world.bodies.dropFirst(index + 1) {
                let apart = hypot(one.x - two.x, one.y - two.y) - one.radius - two.radius
                XCTAssertGreaterThan(apart, -10)
            }
        }
    }

    /// 改物理前一直抖、不睡的堆（seed 照 seed × 7919 + 顆數；mixed 是大小隨機）。
    /// 改了之後在模擬裡已經不抖了，留著確認照樣會睡。
    private struct Shaking {
        var seed: UInt32
        var count: Int
        var mixed: Bool
    }

    private let shaking = [
        Shaking(seed: 238, count: 40, mixed: false),
        Shaking(seed: 89, count: 40, mixed: false),
        Shaking(seed: 19, count: 30, mixed: true),
        Shaking(seed: 73, count: 30, mixed: true),
        Shaking(seed: 215, count: 20, mixed: true),
    ]

    private func shakingPile(_ index: Int) -> JarWorld {
        let pile = shaking[index]
        let seed = pile.seed * 7919 + UInt32(pile.count)
        return JarLab.pile(seed: seed, count: pile.count, mixed: pile.mixed)
    }

    /// 一直走到判成躺好，回走了幾步；limit 步內沒睡回 nil。
    private func untilSettled(
        _ world: inout JarWorld,
        _ quiet: inout JarQuiet,
        limit: Int
    ) -> Int? {
        for tick in 1 ... limit {
            world.step(JarTuning.tick)
            if quiet.settled(world.bodies, isBusy: false) {
                return tick
            }
        }
        return nil
    }

    func test以前會抖的堆四秒內會睡停下那一下每顆走不到半點() {
        for index in shaking.indices {
            var world = shakingPile(index)
            var quiet = JarQuiet()
            XCTAssertNotNil(untilSettled(&world, &quiet, limit: step(4)), "第 \(index) 堆")
            let lastStep = world.bodies.map { hypot($0.x - $0.prevX, $0.y - $0.prevY) }.max() ?? 0
            XCTAssertLessThan(lastStep, 0.5, "第 \(index) 堆")
        }
    }

    func test睡著後點一下會動起來動完再睡() throws {
        var world = shakingPile(0)
        var quiet = JarQuiet()
        XCTAssertNotNil(untilSettled(&world, &quiet, limit: step(4)))
        let before = world.bodies
        // 醒來：畫面那邊點一下就重新開始看。看彈起來時最遠離開多遠，落回去可能剛好回到原位附近
        quiet.restart()
        world.tap(x: 201, y: 850)
        var farthest = 0.0
        var again: Int?
        for tick in 1 ... step(10) where again == nil {
            world.step(JarTuning.tick)
            let moved = zip(before, world.bodies).map { hypot($1.x - $0.x, $1.y - $0.y) }.max() ?? 0
            farthest = max(farthest, moved)
            if quiet.settled(world.bodies, isBusy: false) {
                again = tick
            }
        }
        XCTAssertGreaterThan(try XCTUnwrap(again), step(0.5))
        // 點的是被整堆壓著的最底下：八次迭代之後上面壓得比較實，彈不高，最遠約 8.8 點（改前要求 10）
        XCTAssertGreaterThan(farthest, 5)
    }

    @MainActor
    func test睡著之後收下新的一顆會醒來掉完再睡() async {
        let scene = JarScene()
        let beans = Array(repeating: JarBean(len: 25, color: .red), count: 20)
        scene.layout(width: 402, height: 874, beans: beans, seen: beans.count)
        for _ in 0 ..< 100 where !scene.asleep {
            JarLab.play(scene, seconds: 0.1)
            await Task.yield()
        }
        XCTAssertTrue(scene.asleep)
        scene.follow(beans + [JarBean(len: 25, color: .yellow)])
        XCTAssertFalse(scene.asleep)
        for _ in 0 ..< 100 where !scene.asleep {
            JarLab.play(scene, seconds: 0.1)
            await Task.yield()
        }
        XCTAssertTrue(scene.asleep)
        XCTAssertEqual(scene.world.bodies.count, beans.count + 1)
    }
}
