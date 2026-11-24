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

    func test別台收的那顆直接躺好不掉下來() {
        let scene = mounted(seen: 1)
        var told: [Int] = []
        scene.onKnown = { told.append($0) }
        scene.follow(one + [JarBean(len: 25, color: .red)], drops: false)
        scene.advance(now: Date().timeIntervalSinceReferenceDate + 1)
        XCTAssertEqual(scene.world.bodies.count, 2)
        XCTAssertFalse(scene.world.bodies.contains(where: \.fresh))
        XCTAssertEqual(told, [2])
    }

    func test自己那顆正在掉的時候別台來的躺好它照樣掉() throws {
        let scene = mounted(seen: 0)
        scene.advance(now: Date().timeIntervalSinceReferenceDate + 1)
        let before = try XCTUnwrap(scene.world.bodies.last)
        XCTAssertTrue(before.fresh)
        scene.follow([JarBean(len: 25, color: .red)] + one, drops: false)
        XCTAssertEqual(scene.world.bodies.count, 2)
        let mine = try XCTUnwrap(scene.world.bodies.last)
        XCTAssertTrue(mine.fresh)
        XCTAssertEqual(mine.y, before.y)
        XCTAssertEqual(scene.color(of: mine), .yellow)
        XCTAssertEqual(scene.world.bodies.filter(\.fresh).count, 1)
    }

    func test自己那顆還沒掉的時候別台來的躺好它照樣掉() throws {
        let scene = mounted(seen: 0)
        scene.follow([JarBean(len: 25, color: .red)] + one, drops: false)
        XCTAssertEqual(scene.world.bodies.count, 1)
        scene.advance(now: Date().timeIntervalSinceReferenceDate + 1)
        XCTAssertEqual(scene.world.bodies.count, 2)
        let mine = try XCTUnwrap(scene.world.bodies.last)
        XCTAssertTrue(mine.fresh)
        XCTAssertEqual(scene.color(of: mine), .yellow)
    }

    func test還沒掉的那顆清空後不掉下來() {
        let scene = mounted(seen: 0)
        scene.follow([], drops: false)
        scene.advance(now: Date().timeIntervalSinceReferenceDate + 1)
        XCTAssertTrue(scene.world.bodies.isEmpty)
    }

    func test正在掉的那顆清空後就沒有了() {
        let scene = mounted(seen: 0)
        scene.advance(now: Date().timeIntervalSinceReferenceDate + 1)
        XCTAssertEqual(scene.world.bodies.filter(\.fresh).count, 1)
        scene.follow([], drops: false)
        XCTAssertTrue(scene.world.bodies.isEmpty)
    }

    func test還沒掉的那顆匯入換掉後躺好的是匯入那份() throws {
        let scene = mounted(seen: 0)
        scene.follow([JarBean(len: 25, color: .red)], drops: false)
        scene.advance(now: Date().timeIntervalSinceReferenceDate + 1)
        XCTAssertEqual(scene.world.bodies.count, 1)
        let body = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertFalse(body.fresh)
        XCTAssertEqual(scene.color(of: body), .red)
    }

    func test正在掉的那顆匯入換掉後躺好的是匯入那份() throws {
        let scene = mounted(seen: 0)
        scene.advance(now: Date().timeIntervalSinceReferenceDate + 1)
        let next = [JarBean(len: 25, color: .red), JarBean(len: 25, color: .purple)]
        scene.follow(next, drops: false)
        XCTAssertEqual(scene.world.bodies.count, 2)
        XCTAssertFalse(scene.world.bodies.contains(where: \.fresh))
        let last = try XCTUnwrap(scene.world.bodies.last)
        XCTAssertEqual(scene.color(of: last), .purple)
    }

    func test清空之後收下的那顆照樣掉下來() throws {
        let scene = mounted(seen: 1)
        scene.follow([], drops: false)
        scene.follow(one)
        scene.advance(now: Date().timeIntervalSinceReferenceDate + 1)
        let body = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertTrue(body.fresh)
    }

    func test減少動態時新的一顆直接出現在底() throws {
        let scene = JarScene()
        scene.reduceMotion = true
        scene.layout(width: 393, height: 852, beans: one, seen: 0)
        scene.advance(now: Date().timeIntervalSinceReferenceDate + 1)
        let body = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertEqual(body.y, 852 - body.radius, accuracy: 1)
    }

    func test減少動態時點番茄不動只亮一下再淡回去() throws {
        let scene = JarScene()
        scene.reduceMotion = true
        scene.layout(width: 393, height: 852, beans: one, seen: 1)
        let before = try XCTUnwrap(scene.world.bodies.first)
        scene.tap(x: before.x, y: before.y)
        XCTAssertTrue(scene.glow.isOn)
        var now = Date().timeIntervalSinceReferenceDate
        scene.advance(now: now)
        now += Tokens.Motion.glowRise
        scene.advance(now: now)
        XCTAssertEqual(scene.glow.strength(of: before.id), 1, accuracy: 0.01)
        now += Tokens.Motion.glowFall
        scene.advance(now: now)
        XCTAssertFalse(scene.glow.isOn)
        XCTAssertEqual(scene.world.bodies.first, before)
    }

    func test減少動態時點在空的地方什麼都不亮() throws {
        let scene = JarScene()
        scene.reduceMotion = true
        scene.layout(width: 393, height: 852, beans: one, seen: 1)
        let body = try XCTUnwrap(scene.world.bodies.first)
        scene.tap(x: body.x, y: body.y - scene.world.tuning.tapRadius - 1)
        XCTAssertFalse(scene.glow.isOn)
    }

    func test沒開減少動態時點番茄是彈不是亮() throws {
        let scene = mounted(seen: 1)
        let body = try XCTUnwrap(scene.world.bodies.first)
        scene.tap(x: body.x, y: body.y)
        XCTAssertFalse(scene.glow.isOn)
        XCTAssertLessThan(try XCTUnwrap(scene.world.bodies.first).velY, body.velY)
    }
}
