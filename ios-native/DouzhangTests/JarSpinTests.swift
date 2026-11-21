@testable import Douzhang
import XCTest

/// 會滾的番茄：角度只給畫用。滾多遠轉多少、躺好不會自己轉、不影響位置。
/// 翻自 Expo 版 jarPhysics.test.js 的轉動那幾條。
final class JarSpinTests: XCTestCase {
    func test底上往右滾的那顆順時針轉弧長跟滾過的距離差不多() throws {
        var world = JarLab.world(width: 2000)
        world.addBody(JarLab.body(28, 100, 400 - 28, velX: 300))
        JarLab.run(&world, seconds: 5)
        let body = try XCTUnwrap(world.bodies.first)
        let travelled = body.x - 100
        XCTAssertGreaterThan(travelled, 30)
        XCTAssertGreaterThan(body.angle * 28, travelled * 0.8)
        XCTAssertLessThan(body.angle * 28, travelled * 1.2)
        // 停下來之後轉速歸零，不會留一點點慢慢轉
        XCTAssertEqual(body.spin, 0)
    }

    func test排滿的一排上面再躺一顆放著不管角度都不再變() {
        var world = JarLab.world()
        for index in 0 ..< 5 {
            var body = JarLab.body(28, 30 + Double(index) * 60, 400 - 28)
            body.angle = Double(index) / 10
            world.addBody(body)
        }
        var top = JarLab.body(28, 150, 400 - 28 - 50)
        top.angle = 0.4
        world.addBody(top)
        // 上面那顆先滾進兩顆中間，等它停
        JarLab.run(&world, seconds: 4)
        let before = world.bodies.map(\.angle)
        JarLab.run(&world, seconds: 5)
        XCTAssertEqual(world.bodies.map(\.spin), Array(repeating: 0, count: 6))
        XCTAssertEqual(world.bodies.map(\.angle), before)
    }

    func test開機安置的每一顆只歪一點不帶轉速() {
        var world = JarLab.world()
        world.seed(Array(repeating: 28, count: 20))
        for body in world.bodies {
            XCTAssertLessThanOrEqual(abs(body.angle), JarTuning.standard.spin.lean)
            XCTAssertEqual(body.spin, 0)
        }
    }

    func test轉動只算角度轉速亂給位置與速度一步都不差() {
        var plain = JarLab.world()
        var spun = JarLab.world()
        for index in [0, 1] {
            var world = JarLab.world()
            JarLab.fillRow(&world, radius: 28, y: 400 - 28)
            world.addBody(JarLab.body(28, 140, -56, velX: 20, velY: -160, fresh: true))
            if index == 0 {
                plain = world
            } else {
                spun = world
            }
        }
        for index in spun.bodies.indices {
            spun.bodies[index].spin = Double(index + 1) * 3
            spun.bodies[index].angle = Double(index)
        }
        JarLab.run(&plain, seconds: 4)
        JarLab.run(&spun, seconds: 4)
        XCTAssertEqual(spun.bodies.map(\.x), plain.bodies.map(\.x))
        XCTAssertEqual(spun.bodies.map(\.y), plain.bodies.map(\.y))
        XCTAssertEqual(spun.bodies.map(\.velX), plain.bodies.map(\.velX))
        XCTAssertEqual(spun.bodies.map(\.velY), plain.bodies.map(\.velY))
    }

    func test掉在第一排上面滾進兩顆中間的那顆有轉到最後停住() throws {
        var world = JarLab.world()
        JarLab.fillRow(&world, radius: 28, y: 400 - 28)
        JarLab.run(&world, seconds: 1)
        world.addBody(JarLab.body(28, 140, -56, velX: 20, velY: -160, fresh: true))
        JarLab.run(&world, seconds: 6)
        let newest = try XCTUnwrap(world.bodies.last)
        XCTAssertGreaterThan(abs(newest.angle), 0.2)
        XCTAssertEqual(newest.spin, 0)
    }

    func test貼著牆往下掉的那顆不會被牆搓著轉整排落地也幾乎不轉() {
        var world = JarLab.world()
        // 寬 300 剛好排滿，左右兩顆貼牆
        JarLab.fillRow(&world, radius: 30, y: 100)
        JarLab.run(&world, seconds: 4)
        for body in world.bodies {
            XCTAssertGreaterThan(body.y, 400 - 30 - 1)
            XCTAssertLessThan(abs(body.angle), 0.1)
        }
    }
}
