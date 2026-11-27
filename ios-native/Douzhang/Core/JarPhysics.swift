import Foundation

/// 番茄堆物理：只算，不畫、不碰資料。翻自 Expo 版 core/jarPhysics.js。
/// 輸入只有三種：加一顆（帶自己的半徑）、重力向量（傾斜）、點一下；
/// 輸出是每顆的位置與角度，以及「這一幀落地了哪幾顆、最大撞擊速度」。
/// 呼叫端每幀先把 impact 歸零、把 landed 清空，再分子步呼叫 step。
struct JarWorld {
    /// 開機安置一步走多久、感測器多久讀一次、多久看一次躺好沒。畫面上的一步是 JarTuning.tick。
    static let frame = 1.0 / 60.0
    private static let minGapSquared = 1e-4
    static let minTouchGap = 1e-2

    let tuning: JarTuning
    var bodies: [JarBody] = []
    var width = 0.0
    var height = 0.0
    var gravityX = 0.0
    var gravityY: Double
    var impact = 0.0
    /// 這一幀落地的那幾顆的 id
    var landed: [Int] = []
    /// 開始鈕、分頁列：番茄撞到會被擋，可以停在上面。換的時候走 setObstacles，壓在裡面的才會搬出來
    var obstacles: [JarObstacle] = []
    /// 這一步可能碰到的那幾對：推開與互相帶著轉都只看這些
    private(set) var pairs: [JarPair] = []
    private var nextId = 0

    init(tuning: JarTuning) {
        self.tuning = tuning
        gravityY = tuning.gravity
    }

    /// 這顆多長（分鐘）→ 半徑：面積跟分鐘成正比，所以半徑跟√分鐘走，夾在 sizeMin–sizeMax 倍。
    /// 這是放得下時的大小；一週的番茄放不下時，現場再照 JarFit 全部等比縮小。
    func radiusFor(minutes: Double) -> Double {
        let ratio = (minutes / tuning.sizeRefMinutes).squareRoot()
        return tuning.radius * min(tuning.sizeMax, max(tuning.sizeMin, ratio))
    }

    /// 一開始歪多少：正負 lean 之間隨機。
    func randomLean() -> Double {
        Double.random(in: -1 ... 1) * tuning.spin.lean
    }

    /// 加一顆。fresh＝從上面掉進來的；落地＝第一次碰到底，或撞到下面已經落定的番茄。
    mutating func addBody(_ body: JarBody) {
        var added = body
        nextId += 1
        added.id = nextId
        added.markStep()
        bodies.append(added)
    }

    /// 全部等比縮放（多一顆放不下了）：只改大小不搬位置，縮出來的空隙讓重力自己補上。
    mutating func rescale(by ratio: Double) {
        for index in bodies.indices {
            bodies[index].radius *= ratio
        }
    }

    private mutating func integrate(_ step: Double) {
        for index in bodies.indices {
            var body = bodies[index]
            body.velX = (body.velX + gravityX * step) * tuning.airDamp
            body.velY = (body.velY + gravityY * step) * tuning.airDamp
            body.x += body.velX * step
            body.y += body.velY * step
            bodies[index] = body
        }
    }

    /// 還在掉的那顆撞到下面已經落定的番茄，也算落地。
    /// 兩顆都還在掉的互撞不算；落定的那顆要在下面（點一下彈上來撞到的不算）。
    private mutating func landOnPile(_ one: inout JarBody, _ two: inout JarBody) {
        if one.fresh == two.fresh {
            return
        }
        if one.fresh {
            if two.y <= one.y {
                return
            }
            one.fresh = false
            landed.append(one.id)
        } else {
            if one.y <= two.y {
                return
            }
            two.fresh = false
            landed.append(two.id)
        }
    }

    /// 大的比較重：反彈的衝量照質量（半徑平方）分，小的撞大的會被彈開、大的幾乎不動。
    /// 推開的距離只照半徑分：照半徑平方的話，夾在兩顆大的中間的小顆每次都被推回去，會被壓進去十幾點。
    private mutating func collide(_ pair: JarPair) {
        var one = bodies[pair.first]
        var two = bodies[pair.second]
        let reach = one.radius + two.radius
        let deltaX = two.x - one.x
        let deltaY = two.y - one.y
        let squared = deltaX * deltaX + deltaY * deltaY
        if squared >= reach * reach || squared <= JarWorld.minGapSquared {
            return
        }
        let distance = squared.squareRoot()
        let normalX = deltaX / distance
        let normalY = deltaY / distance
        let overlap = reach - distance
        let pushOne = overlap * two.radius / reach
        let pushTwo = overlap - pushOne
        one.x -= normalX * pushOne
        one.y -= normalY * pushOne
        two.x += normalX * pushTwo
        two.y += normalY * pushTwo
        let closing = (two.velX - one.velX) * normalX + (two.velY - one.velY) * normalY
        if closing < 0 {
            landOnPile(&one, &two)
            let massOne = one.radius * one.radius
            let massTwo = two.radius * two.radius
            let impulse = -tuning.beanRest * closing / (massOne + massTwo)
            one.velX -= impulse * massTwo * normalX
            one.velY -= impulse * massTwo * normalY
            two.velX += impulse * massOne * normalX
            two.velY += impulse * massOne * normalY
            impact = max(impact, -closing)
        }
        bodies[pair.first] = one
        bodies[pair.second] = two
    }

    /// 撞牆：反彈保留 wallRest；回報最大撞擊速度。位置由呼叫端壓回牆內。回傳有沒有真的撞上去。
    @discardableResult
    mutating func bounce(_ velocity: inout Double, sign: Double) -> Bool {
        let inward = velocity * sign
        guard inward > 0 else { return false }
        impact = max(impact, inward)
        velocity = -inward * sign * tuning.wallRest
        return true
    }

    /// 壓回牆內、反彈；碰到了什麼記在 touches，摩擦等這一步最後再扣。
    private mutating func solveWalls(_ touches: inout [JarTouch]) {
        for index in bodies.indices {
            var body = bodies[index]
            let radius = body.radius
            if body.x < radius {
                body.x = radius
                bounce(&body.velX, sign: -1)
                touches[index].wall = true
            }
            if body.x > width - radius {
                body.x = width - radius
                bounce(&body.velX, sign: 1)
                touches[index].wall = true
            }
            if body.y > height - radius {
                body.y = height - radius
                // 落地那一幀：從上面掉進來的要回報（啵＋觸覺在這一幀，不是按鈕那一幀）
                if bounce(&body.velY, sign: 1), body.fresh {
                    body.fresh = false
                    landed.append(body.id)
                }
                touches[index].floor = true
            }
            // 上緣：從上面外面掉進來的可以在上面；落定的、已經整顆進來過的（斷藤那顆）不准飛出去
            if body.y < radius, !body.fresh || body.prevY >= radius {
                body.y = radius
                bounce(&body.velY, sign: -1)
            }
            // 牆之後才擋路的東西：牆把被擠出去的壓回來時會壓進分頁列的圓頭，最後一步要是推出來（推的時候不出牆）
            for obstacle in obstacles {
                if let normal = push(&body, from: obstacle) {
                    touches[index].surface = normal
                }
            }
            bodies[index] = body
        }
    }

    /// 走一步（秒）。
    mutating func step(_ seconds: Double) {
        for index in bodies.indices {
            bodies[index].markStep()
        }
        integrate(seconds)
        pairs = JarWorld.nearPairs(bodies, slack: tuning.pairSlack)
        var touches = Array(repeating: JarTouch(), count: bodies.count)
        for _ in 0 ..< tuning.iterations {
            for pair in pairs {
                collide(pair)
            }
            solveWalls(&touches)
        }
        rub(touches, seconds: seconds)
        roll(seconds)
    }

    /// 開機安置：照每顆的半徑隨機撒，靜置重力預跑 settleSteps 步，進畫面時番茄已經落定。
    /// 超過顆數上限只撒最後（最近）的那些。
    mutating func seed(_ radii: [Double]) {
        bodies = []
        landed = []
        guard width > 0, height > 0 else { return }
        for radius in radii.suffix(tuning.maxBeans) {
            let x = radius + Double.random(in: 0 ... 1) * max(0, width - 2 * radius)
            let y = radius + Double.random(in: 0 ... 1) * max(0, height - 2 * radius)
            addBody(JarBody(id: 0, x: x, y: y, radius: radius))
        }
        liftOut()
        let tilted = (gravityX, gravityY)
        gravityX = 0
        gravityY = tuning.gravity
        for _ in 0 ..< tuning.settleSteps {
            step(JarWorld.frame)
        }
        (gravityX, gravityY) = tilted
        landed = []
        // 預跑時是從亂撒的位置互相擠開，轉出來的角度沒有意義：每顆重新給一個小歪度、不帶轉速
        for index in bodies.indices {
            bodies[index].angle = randomLean()
            bodies[index].spin = 0
            bodies[index].markStep()
        }
    }
}

/// 點一下。
extension JarWorld {
    /// 點一下：影響半徑內的番茄往上彈、往離開手指的方向推。
    mutating func tap(x: Double, y: Double) {
        for index in bodies.indices {
            let body = bodies[index]
            let distance = hypot(body.x - x, body.y - y)
            if distance >= tuning.tapRadius {
                continue
            }
            let strength = 1 - distance / tuning.tapRadius
            bodies[index].velY -= tuning.tapUp * strength
            bodies[index].velX += (body.x - x) * tuning.tapSide * strength
        }
    }

    /// 點一下影響得到的範圍裡，離手指最近的那顆的 id；沒有就 nil。
    func nearest(x: Double, y: Double) -> Int? {
        let near = bodies.min { hypot($0.x - x, $0.y - y) < hypot($1.x - x, $1.y - y) }
        guard let near, hypot(near.x - x, near.y - y) < tuning.tapRadius else { return nil }
        return near.id
    }
}
