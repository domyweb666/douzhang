import Foundation

/// 番茄堆的新的一顆：掛上藤、斷了掉進物理世界；一週的番茄放不下時全部一起縮小。
extension JarScene {
    func add(_ body: JarBody, color: TomatoColor) {
        world.addBody(body)
        if let added = world.bodies.last {
            colors[added.id] = color
        }
    }

    /// 新的一顆：掛上藤，晃一晃才掉。靜止版直接出現在底。
    func drop(_ bean: JarBean) {
        makeRoom()
        let radius = fit(bean)
        if isStill {
            lay(bean, radius: radius)
        } else {
            vines.hang(bean, radius: radius, width: world.width)
        }
    }

    func lay(_ bean: JarBean, radius: Double) {
        let x = world.width / 2 + Double.random(in: -1 ... 1) * radius
        var body = JarBody(id: 0, x: x, y: world.height - radius, radius: radius)
        body.angle = world.randomLean()
        add(body, color: bean.color)
        world.liftOut()
        sounds.land(sound: soundOn)
    }

    /// 藤斷了：果子掉進物理世界。上一步還掛著的位置也帶過去，畫面才接得起來。
    func release(_ vine: JarVine) {
        add(vine.fallen(), color: vine.bean.color)
        let before = vine.pose(at: JarHang.cutAt - JarTuning.tick)
        let last = world.bodies.count - 1
        world.bodies[last].prevX = before.x
        world.bodies[last].prevY = before.y
        world.bodies[last].prevAngle = -before.angle
    }

    /// 畫到顆數上限了：拿掉最早的那顆（排最前面），只放最近的。
    private func makeRoom() {
        let count = world.bodies.count + vines.holding.count
        guard count >= world.tuning.maxBeans, let oldest = world.bodies.first else { return }
        world.bodies.removeFirst()
        colors[oldest.id] = nil
    }

    /// 多這一顆之後放不放得下：放不下就把已經在裡面的全部等比縮小（重力會把縮出來的空隙補上），
    /// 回這一顆該多大。只縮不放大：拿掉最早那顆後變得放得下，也等下次重新安置才放大，不然整堆會突然脹一下。
    /// 還掛著的那幾顆快掉下來了，大小不跟著改。
    private func fit(_ bean: JarBean) -> Double {
        let base = world.radiusFor(minutes: bean.len)
        let inside = (world.bodies.map(\.radius) + vines.holding.map(\.radius)).map { $0 / scale }
        let next = JarFit.scale(
            radii: inside + [base],
            width: world.width,
            height: world.height,
            share: world.tuning.fillShare
        )
        if next < scale {
            world.rescale(by: next / scale)
            scale = next
        }
        return base * scale
    }
}
