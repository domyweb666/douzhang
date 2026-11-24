@testable import Douzhang
import XCTest

/// 番茄堆的現場：回到待機時，上次看過的已經躺好，多出來的那顆從畫布最上緣外面掉進來。
@MainActor
final class JarSceneTests: XCTestCase {
    private let one = [JarBean(len: 5, color: .yellow)]

    private func mounted(seen: Int?) -> JarScene {
        let scene = JarScene()
        scene.layout(width: 393, height: 852, beans: one, seen: seen)
        return scene
    }

    func test第一次量到寬高就回報看到幾顆() {
        let scene = JarScene()
        var told: [Int] = []
        scene.onKnown = { told.append($0) }
        scene.layout(width: 393, height: 852, beans: one, seen: 0)
        XCTAssertEqual(told, [1])
    }

    func test上次看到零顆回來多一顆就從最上緣外面一路掉到底() throws {
        let scene = mounted(seen: 0)
        XCTAssertTrue(scene.world.bodies.isEmpty)
        var now = Date().timeIntervalSinceReferenceDate + 1
        scene.advance(now: now)
        let dropped = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertTrue(dropped.fresh)
        XCTAssertLessThan(dropped.y + dropped.radius, 0)
        for _ in 0 ..< 60 * 4 {
            now += JarWorld.frame
            scene.advance(now: now)
        }
        let landed = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertFalse(landed.fresh)
        // 地板就是畫布底（畫面上是螢幕最底部）
        XCTAssertEqual(landed.y, 852 - landed.radius, accuracy: 1)
    }

    func test已經看過的那顆回來時躺在底不再掉一次() throws {
        let scene = mounted(seen: 1)
        let body = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertFalse(body.fresh)
        XCTAssertEqual(body.y, 852 - body.radius, accuracy: 1)
    }

    func test減少動態時新的一顆直接出現在底() throws {
        let scene = JarScene()
        scene.reduceMotion = true
        scene.layout(width: 393, height: 852, beans: one, seen: 0)
        scene.advance(now: Date().timeIntervalSinceReferenceDate + 1)
        let body = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertEqual(body.y, 852 - body.radius, accuracy: 1)
    }
}
