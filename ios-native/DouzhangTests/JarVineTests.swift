@testable import Douzhang
import XCTest

/// 掉下來之前那一段：從上緣垂下來、越晃越大、藤斷了帶著當下的速度掉。
@MainActor
final class JarVineTests: XCTestCase {
    private let one = [JarBean(len: 5, color: .yellow)]
    private let red = JarBean(len: 25, color: .red)
    private let vine = JarVine(
        bean: JarBean(len: 25, color: .red),
        radius: 28,
        pivotX: 200,
        side: 1
    )

    /// 一進畫面就有一顆掛著（還沒斷）。
    private func hanging() -> JarScene {
        let scene = JarScene()
        scene.layout(width: 393, height: 852, beans: one, seen: 0)
        JarLab.play(scene, seconds: 0.1)
        return scene
    }

    // MARK: 一截藤

    func test一開始藏在螢幕頂上面垂下來之後停在定點() {
        let start = vine.pose(at: 0)
        XCTAssertLessThan(start.y + vine.radius, 0)
        let down = vine.pose(at: JarHang.growTime)
        XCTAssertEqual(down.x, 200, accuracy: 0.001)
        XCTAssertEqual(down.y, JarHang.reach, accuracy: 0.001)
    }

    func test晃的時候左右輪流而且越晃越大() {
        var peaks: [Double] = []
        var before = 0.0
        var now = 0.0
        for step in 1 ... 1000 {
            let time = JarHang.growTime + JarHang.swayTime * Double(step) / 1000
            let next = vine.pose(at: time).angle
            if abs(now) > abs(before), abs(now) > abs(next) {
                peaks.append(now)
            }
            before = now
            now = next
        }
        // 晃到一邊、再往另一邊，還沒到頂就斷了（照擺長的自然頻率晃，只晃一個來回不到）
        peaks.append(now)
        XCTAssertEqual(peaks.count, 2)
        for (last, next) in zip(peaks, peaks.dropFirst()) {
            XCTAssertLessThan(last * next, 0)
            XCTAssertGreaterThan(abs(next), abs(last))
        }
    }

    func test斷的那一刻帶著切線速度與轉速蒂頭還朝著支點() {
        let body = vine.fallen()
        let slice = 1e-5
        let last = vine.pose(at: JarHang.cutAt)
        let before = vine.pose(at: JarHang.cutAt - slice)
        XCTAssertEqual(body.velX, (last.x - before.x) / slice, accuracy: 0.5)
        XCTAssertEqual(body.velY, (last.y - before.y) / slice, accuracy: 0.5)
        XCTAssertEqual(body.spin, -(last.angle - before.angle) / slice, accuracy: 0.01)
        // 蒂頭的方向：角度 0 朝正上方，順時針為正
        let toPivot = atan2(vine.pivotX - body.x, body.y)
        XCTAssertEqual(body.angle, toPivot, accuracy: 0.001)
        XCTAssertTrue(body.fresh)
    }

    func test斷了之後藤縮回去縮完就沒了() {
        var vines = JarVines()
        vines.hang(red, radius: 28, width: 393)
        var cut = 0
        for _ in 0 ..< Int((JarHang.cutAt + 0.05) / JarTuning.tick) {
            cut += vines.step(JarTuning.tick).count
        }
        XCTAssertEqual(cut, 1)
        XCTAssertTrue(vines.holding.isEmpty)
        XCTAssertFalse(vines.isEmpty)
        for _ in 0 ..< Int((JarHang.retractTime + 0.05) / JarTuning.tick) {
            XCTAssertTrue(vines.step(JarTuning.tick).isEmpty)
        }
        XCTAssertTrue(vines.isEmpty)
        XCTAssertEqual(vine.rest(at: JarHang.cutAt), 1)
        XCTAssertEqual(vine.rest(at: JarHang.cutAt + JarHang.retractTime), 0)
    }

    // MARK: 番茄堆裡

    func test新的一顆先掛著還沒進物理世界() {
        let scene = hanging()
        XCTAssertEqual(scene.vines.holding.count, 1)
        XCTAssertTrue(scene.world.bodies.isEmpty)
    }

    func test斷開那一格畫面接得起來不會跳() throws {
        let scene = hanging()
        JarLab.play(scene, seconds: JarHang.growTime)
        var spots: [CGPoint] = []
        for _ in 0 ..< 144 {
            JarLab.frame(scene, 1 / 120)
            try spots.append(XCTUnwrap(JarLab.shown(scene)))
        }
        XCTAssertEqual(scene.world.bodies.count, 1)
        // 這一格走的跟上一格走的差多少：停一格或跳一格會差到 0.6 以上
        for index in 2 ..< spots.count {
            let (first, middle, last) = (spots[index - 2], spots[index - 1], spots[index])
            let jerkX = (last.x - middle.x) - (middle.x - first.x)
            let jerkY = (last.y - middle.y) - (middle.y - first.y)
            XCTAssertLessThan(hypot(jerkX, jerkY), 0.4, "第 \(index) 格")
        }
    }

    func test同時兩顆錯開掛兩顆都會掉到底() {
        let scene = hanging()
        scene.follow(one + [red])
        JarLab.play(scene, seconds: 0.1)
        let holding = scene.vines.holding
        XCTAssertEqual(holding.count, 2)
        let apart = abs(holding[0].pivotX - holding[1].pivotX)
        XCTAssertGreaterThan(apart, holding[0].radius + holding[1].radius)
        JarLab.play(scene, seconds: 5)
        XCTAssertEqual(scene.world.bodies.count, 2)
        XCTAssertFalse(scene.world.bodies.contains(where: \.fresh))
    }

    func test凍住再久也不偷跑() throws {
        let scene = hanging()
        let before = try XCTUnwrap(scene.vines.all.first).age
        // 滑走五秒才停回來：凍著的時候一格都沒畫，停回來那一格只算一格
        scene.setFrozen(true)
        JarLab.pass(seconds: 5)
        scene.setFrozen(false)
        JarLab.frame(scene, 1 / 120)
        let after = try XCTUnwrap(scene.vines.all.first).age
        XCTAssertGreaterThan(after, before)
        XCTAssertLessThanOrEqual(after - before, Tokens.Motion.frameMax / 2 + JarTuning.tick)
        XCTAssertFalse(scene.isStill)
    }

    func test掛著的時候別台來的躺好它照樣掛著晃完掉下來() throws {
        let scene = hanging()
        let before = scene.vines.holding
        scene.follow([red] + one, drops: false)
        XCTAssertEqual(scene.vines.holding, before)
        XCTAssertEqual(scene.world.bodies.count, 1)
        JarLab.play(scene, seconds: JarHang.cutAt)
        XCTAssertEqual(scene.world.bodies.count, 2)
        let mine = try XCTUnwrap(scene.world.bodies.last)
        XCTAssertEqual(scene.color(of: mine), .yellow)
    }

    func test掛著的那顆清空後就沒有了() {
        let scene = hanging()
        scene.follow([], drops: false)
        XCTAssertTrue(scene.vines.isEmpty)
        JarLab.play(scene, seconds: JarHang.cutAt)
        XCTAssertTrue(scene.world.bodies.isEmpty)
    }

    func test掛著的那顆匯入換掉後躺好的是匯入那份() throws {
        let scene = hanging()
        let next = [red, JarBean(len: 25, color: .purple)]
        scene.follow(next, drops: false)
        XCTAssertTrue(scene.vines.isEmpty)
        XCTAssertEqual(scene.world.bodies.count, 2)
        XCTAssertFalse(scene.world.bodies.contains(where: \.fresh))
        let last = try XCTUnwrap(scene.world.bodies.last)
        XCTAssertEqual(scene.color(of: last), .purple)
    }

    func test掛著時換日數目對不上就整份重新躺好() {
        let scene = hanging()
        scene.follow([])
        XCTAssertTrue(scene.vines.isEmpty)
        XCTAssertTrue(scene.world.bodies.isEmpty)
    }

    func test掛著時又收一顆再合進來別台的只有最新那顆還沒掉() throws {
        let scene = hanging()
        scene.follow(one + [red])
        scene.follow([JarBean(len: 25, color: .pink)] + one + [red], drops: false)
        // 先收的那顆已經躺好，不會再掉一次
        XCTAssertTrue(scene.vines.isEmpty)
        XCTAssertEqual(scene.world.bodies.count, 2)
        JarLab.play(scene, seconds: JarHang.cutAt + 0.1)
        XCTAssertEqual(scene.world.bodies.count, 3)
        let last = try XCTUnwrap(scene.world.bodies.last)
        XCTAssertEqual(scene.color(of: last), .red)
    }

    func test掛著時轉成減少動態就直接到底() throws {
        let scene = hanging()
        scene.reduceMotion = true
        JarLab.play(scene, seconds: 0.1)
        XCTAssertTrue(scene.vines.isEmpty)
        let body = try XCTUnwrap(scene.world.bodies.first)
        XCTAssertFalse(body.fresh)
        XCTAssertEqual(body.y, 852 - body.radius, accuracy: 1)
        XCTAssertEqual(scene.world.bodies.count, 1)
    }

    func test藤還在縮的時候果子已經落定了也不睡() async {
        // 矮到掛著就快碰到底：一斷就落地，藤還在縮
        let scene = JarScene()
        scene.layout(width: 393, height: 160, beans: [red], seen: 0)
        var landed = 0
        for _ in 0 ..< 200 {
            JarLab.play(scene, seconds: JarTuning.tick)
            await Task.yield()
            let down = scene.world.bodies.first.map { !$0.fresh } ?? false
            if down, !scene.vines.isEmpty {
                landed += 1
                XCTAssertTrue(scene.vines.holding.isEmpty)
                XCTAssertFalse(scene.asleep)
            }
        }
        XCTAssertGreaterThan(landed, 10)
    }

    func test掛著與藤還在縮的時候不睡落定了才睡() async {
        let scene = hanging()
        for _ in 0 ..< 15 {
            JarLab.play(scene, seconds: 0.1)
            await Task.yield()
            XCTAssertFalse(scene.asleep)
        }
        for _ in 0 ..< 100 where !scene.asleep {
            JarLab.play(scene, seconds: 0.1)
            await Task.yield()
        }
        XCTAssertTrue(scene.asleep)
    }
}
