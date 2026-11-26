import Foundation

/// 一截藤和掛在它下面的那顆：像鐘擺晃，晃夠了藤就斷。只算時間與位置，不畫。
/// 時間由番茄堆一步一步累加：滑頁凍住、睡著時不走，不會偷跑。
struct JarVine: Equatable {
    /// 那一刻果子中心在哪、歪多少（弧度，正的是往右擺）、擺得多快（弧度/秒）。
    struct Pose: Equatable {
        var x: Double
        var y: Double
        var angle: Double
        var turn: Double
    }

    let bean: JarBean
    let radius: Double
    let pivotX: Double
    /// 先往哪邊晃：1 右、-1 左
    let side: Double
    private(set) var age = 0.0

    /// 果子還掛著。時間一步一步加起來會有一點點誤差，讓半步：
    /// 不讓的話有時晚一步才斷，畫面會把最後那一步重畫一次，頓一下。
    var isHolding: Bool {
        age < JarHang.cutAt - JarTuning.tick / 2
    }

    /// 斷了，剩下的藤也縮完了。
    var isGone: Bool {
        age >= JarHang.cutAt + JarHang.retractTime
    }

    mutating func grow(_ seconds: Double) {
        age += seconds
    }

    /// time 是開始垂下來之後多久；斷了之後都是斷的那一刻。
    func pose(at time: Double) -> Pose {
        let held = min(max(0, time), JarHang.cutAt)
        let left = 1 - min(1, held / JarHang.growTime)
        let start = -JarHang.hidden * radius
        let length = JarHang.reach - (JarHang.reach - start) * left * left * left
        let swayed = max(0, held - JarHang.growTime)
        let phase = JarHang.swayEnd * swayed / JarHang.swayTime
        let widen = (JarHang.swayTo - JarHang.swayFrom) / JarHang.swayTime
        let width = JarHang.swayFrom + widen * swayed
        let speed = JarHang.swayEnd / JarHang.swayTime
        let angle = side * width * sin(phase)
        let turn = swayed > 0 ? side * (widen * sin(phase) + width * speed * cos(phase)) : 0
        return Pose(
            x: pivotX + length * sin(angle),
            y: length * cos(angle),
            angle: angle,
            turn: turn
        )
    }

    /// 斷的那一刻掉進物理世界的那顆：帶著切線速度與轉速，蒂頭還朝著支點。
    func fallen() -> JarBody {
        let last = pose(at: JarHang.cutAt)
        var body = JarBody(id: 0, x: last.x, y: last.y, radius: radius)
        body.velX = JarHang.reach * last.turn * cos(last.angle)
        body.velY = -JarHang.reach * last.turn * sin(last.angle)
        body.angle = -last.angle
        body.spin = -last.turn
        body.fresh = true
        return body
    }

    /// 斷了之後剩下的藤縮到幾成：1 剛斷，0 縮完。
    func rest(at time: Double) -> Double {
        let share = min(1, max(0, (time - JarHang.cutAt) / JarHang.retractTime))
        return 1 - share * share * (3 - 2 * share)
    }
}

/// 現在畫面上的藤：還掛著果子的、斷了正在縮回去的。
struct JarVines {
    private(set) var all: [JarVine] = []

    var isEmpty: Bool {
        all.isEmpty
    }

    /// 果子還掛著的
    var holding: [JarVine] {
        all.filter(\.isHolding)
    }

    /// 掛一顆上去，支點在中間附近；已經有一顆掛著就掛到它旁邊比較空的那一側。
    mutating func hang(_ bean: JarBean, radius: Double, width: Double) {
        let middle = width / 2
        var pivotX = middle + Double.random(in: -1 ... 1) * JarHang.spread
        if let other = holding.last {
            let away = other.radius + radius + JarHang.gap
            pivotX = other.pivotX + (other.pivotX > middle ? -away : away)
        }
        pivotX = max(radius, min(width - radius, pivotX))
        let side = Bool.random() ? 1.0 : -1.0
        all.append(JarVine(bean: bean, radius: radius, pivotX: pivotX, side: side))
    }

    /// 走一步，回這一步斷掉的那幾顆。
    mutating func step(_ seconds: Double) -> [JarVine] {
        var cut: [JarVine] = []
        for index in all.indices {
            let held = all[index].isHolding
            all[index].grow(seconds)
            if held, !all[index].isHolding {
                cut.append(all[index])
            }
        }
        all.removeAll(where: \.isGone)
        return cut
    }

    /// 還掛著的都不要了，只留這一顆（沒有就都不留）。斷了正在縮的不管它，讓它縮完。
    mutating func keepOnly(_ kept: JarVine?) {
        all.removeAll { $0.isHolding && $0 != kept }
    }
}
