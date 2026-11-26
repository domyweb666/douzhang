@testable import Douzhang
import XCTest

/// 番茄堆的現場由殼保管：主畫面在鈴響、聚焦模式時拆掉，回到待機接著用同一個，不重新安置。
/// 不在畫面上時收下的照樣掛藤掉下來；換日、清空、匯入、同步的對法跟第一次擺的時候一樣。
@MainActor
final class JarResumeTests: XCTestCase {
    private let one = [JarBean(len: 5, color: .yellow)]

    private func mounted(seen: Int?) -> JarScene {
        let scene = JarScene()
        scene.layout(width: 393, height: 852, beans: one, seen: seen)
        return scene
    }

    /// 走到那顆剛從藤上斷下來。
    private func cutLoose(_ scene: JarScene) {
        JarLab.play(scene, seconds: JarHang.cutAt + JarWorld.frame)
    }

    /// 躺好、然後離開待機（主畫面拆掉，現場留在殼裡）。
    private func leftIdle(seen: Int) -> JarScene {
        let scene = mounted(seen: seen)
        JarLab.play(scene, seconds: 3)
        scene.stop()
        return scene
    }

    func test接回來多一顆時舊的不重新安置新的那顆掛藤掉下來() throws {
        let scene = leftIdle(seen: 1)
        let before = try XCTUnwrap(scene.world.bodies.first)
        scene.resume(one + [JarBean(len: 25, color: .red)], seen: 1)
        XCTAssertEqual(scene.world.bodies, [before])
        cutLoose(scene)
        XCTAssertEqual(scene.world.bodies.count, 2)
        let old = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertEqual(old.x, before.x, accuracy: 0.5)
        XCTAssertEqual(old.y, before.y, accuracy: 0.5)
        let mine = try XCTUnwrap(scene.world.bodies.last)
        XCTAssertTrue(mine.fresh)
        XCTAssertEqual(scene.color(of: mine), .red)
    }

    func test接回來數目對不上就重新安置不掉() {
        let scene = leftIdle(seen: 1)
        let three = one + [JarBean(len: 25, color: .red), JarBean(len: 10, color: .pink)]
        var told: [Int] = []
        scene.onKnown = { told.append($0) }
        scene.resume(three, seen: 1)
        XCTAssertEqual(scene.world.bodies.count, 3)
        XCTAssertTrue(scene.vines.isEmpty)
        XCTAssertFalse(scene.world.bodies.contains(where: \.fresh))
        XCTAssertEqual(told, [3])
    }

    func test接回來時殼記的顆數變了照第一次那樣看過的躺好多的掉() throws {
        let scene = leftIdle(seen: 1)
        let three = one + [JarBean(len: 25, color: .red), JarBean(len: 10, color: .pink)]
        scene.resume(three, seen: 2)
        XCTAssertEqual(scene.world.bodies.count, 2)
        cutLoose(scene)
        XCTAssertEqual(scene.world.bodies.count, 3)
        let mine = try XCTUnwrap(scene.world.bodies.last)
        XCTAssertTrue(mine.fresh)
        XCTAssertEqual(scene.color(of: mine), .pink)
    }

    func test接回來時殼說整份換過了就直接躺好() {
        let scene = leftIdle(seen: 1)
        scene.resume(one + [JarBean(len: 25, color: .red)], seen: nil)
        XCTAssertEqual(scene.world.bodies.count, 2)
        cutLoose(scene)
        XCTAssertFalse(scene.world.bodies.contains(where: \.fresh))
    }

    func test還沒量過寬高就接回來等第一次畫才安置() {
        let scene = JarScene()
        scene.resume(one, seen: 0)
        XCTAssertNil(scene.known)
        scene.layout(width: 393, height: 852, beans: one, seen: 0)
        XCTAssertTrue(scene.world.bodies.isEmpty)
        cutLoose(scene)
        XCTAssertEqual(scene.world.bodies.count, 1)
    }

    func test同顆數換了顏色接回來照新的顏色躺好() throws {
        let scene = leftIdle(seen: 1)
        scene.resume([JarBean(len: 5, color: .red)], seen: 1)
        let body = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertEqual(scene.world.bodies.count, 1)
        XCTAssertEqual(scene.color(of: body), .red)
        XCTAssertFalse(body.fresh)
    }

    func test多一顆但前面換了顏色前面照新的躺好多的那顆照樣掉() throws {
        let scene = leftIdle(seen: 1)
        scene.resume([JarBean(len: 5, color: .red), JarBean(len: 25, color: .pink)], seen: 1)
        let first = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertEqual(scene.world.bodies.count, 1)
        XCTAssertEqual(scene.color(of: first), .red)
        cutLoose(scene)
        XCTAssertEqual(scene.world.bodies.count, 2)
        let mine = try XCTUnwrap(scene.world.bodies.last)
        XCTAssertTrue(mine.fresh)
        XCTAssertEqual(scene.color(of: mine), .pink)
    }

    /// 傾斜感測器在接回之後才看要不要開（JarView.start）：這裡驗接回之後已經不是靜止版。
    /// 模擬器沒有加速度計，感測器本身開了沒有只能真機看。
    func test退成靜止版之後接回來又會動() {
        let scene = mounted(seen: 1)
        JarLab.play(scene, seconds: 5, hertz: 10)
        XCTAssertTrue(scene.isStill)
        scene.stop()
        scene.resume(one, seen: 1)
        XCTAssertFalse(scene.isStill)
    }
}
