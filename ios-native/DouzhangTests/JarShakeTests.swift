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

/// 卡在原地抖的堆也會睡；正常掉、斜、滾的時候，睡著的那一步跟每顆怎麼動都跟改前一樣。
final class JarShakeTests: XCTestCase {
    private func step(_ seconds: Double) -> Int {
        JarLab.steps(seconds)
    }

    func test掉落傾斜滾動時睡著那一步與每顆的位置跟改前一樣() {
        let (tick, world) = JarLab.dropTiltRoll()
        XCTAssertEqual(tick, JarShakeTests.beforeTick)
        XCTAssertEqual(world.bodies.count, JarShakeTests.beforeSpots.count)
        for (body, spot) in zip(world.bodies, JarShakeTests.beforeSpots) {
            XCTAssertEqual(body.x, spot.x, accuracy: 0.01)
            XCTAssertEqual(body.y, spot.y, accuracy: 0.01)
        }
    }

    /// 改前一直抖、不睡的堆（seed 照 seed × 7919 + 顆數；mixed 是大小隨機）。
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

    func test卡在原地抖的堆四秒內會睡停下那一下每顆走不到半點() throws {
        for index in shaking.indices {
            var world = shakingPile(index)
            var quiet = JarQuiet()
            let tick = try XCTUnwrap(untilSettled(&world, &quiet, limit: step(4)), "第 \(index) 堆")
            let lastStep = world.bodies.map { hypot($0.x - $0.prevX, $0.y - $0.prevY) }.max() ?? 0
            XCTAssertLessThan(lastStep, 0.5, "第 \(index) 堆")
            // 真的是抖的那種：放著不管再走 4 秒，之後那 1 秒還是有顆每 1/60 秒走超過門檻
            var going = world
            for _ in 0 ..< step(4) {
                going.step(JarTuning.tick)
            }
            var most = 0.0
            for _ in 0 ..< step(1) / 2 {
                let before = going.bodies
                going.step(JarTuning.tick)
                going.step(JarTuning.tick)
                for (old, new) in zip(before, going.bodies) {
                    most = max(most, abs(new.x - old.x), abs(new.y - old.y))
                }
            }
            XCTAssertGreaterThan(most, Tokens.Motion.quietDistance, "第 \(index) 堆，第 \(tick) 步睡")
        }
    }

    func test抖到睡著後點一下會動起來動完再睡() throws {
        var world = shakingPile(0)
        var quiet = JarQuiet()
        XCTAssertNotNil(untilSettled(&world, &quiet, limit: step(4)))
        let before = world.bodies
        // 醒來：畫面那邊點一下就重新開始看
        quiet.restart()
        world.tap(x: 201, y: 850)
        let again = try XCTUnwrap(untilSettled(&world, &quiet, limit: step(10)))
        XCTAssertGreaterThan(again, step(0.5))
        let moved = zip(before, world.bodies).map { hypot($1.x - $0.x, $1.y - $0.y) }.max() ?? 0
        XCTAssertGreaterThan(moved, 10)
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

/// 改前（2026-11-26，只看每 1/60 秒走不到 0.5 點、半秒淨移動不到 1 點）在模擬器上跑 dropTiltRoll 量到的。
extension JarShakeTests {
    static let beforeTick: Int? = 801
    static let beforeSpots: [(x: Double, y: Double)] = [
        (x: 86.2393, y: 860.0000),
        (x: 124.3959, y: 769.3453),
        (x: 110.5130, y: 642.3556),
        (x: 236.7427, y: 829.5465),
        (x: 38.3917, y: 835.6083),
        (x: 269.9381, y: 758.4612),
        (x: 365.7079, y: 837.6317),
        (x: 304.3268, y: 847.7337),
        (x: 314.6444, y: 699.9157),
        (x: 70.6754, y: 731.8347),
        (x: 271.2212, y: 648.8958),
        (x: 21.6887, y: 777.9098),
        (x: 183.2132, y: 755.8513),
        (x: 154.3931, y: 835.6083),
        (x: 311.4655, y: 798.5300),
        (x: 238.8241, y: 699.4561),
        (x: 29.0985, y: 670.1599),
        (x: 362.8000, y: 762.2085),
        (x: 96.1497, y: 801.6892),
        (x: 349.1697, y: 614.1807),
        (x: 180.9315, y: 681.3654),
    ]
}
