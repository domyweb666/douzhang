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
    private var nextId = 0

    init(tuning: JarTuning) {
        self.tuning = tuning
        gravityY = tuning.gravity
    }

    /// 這顆多長（分鐘）→ 半徑：面積跟分鐘成正比，所以半徑跟√分鐘走，夾在 sizeMin–sizeMax 倍。
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

    private mutating func collide(_ first: Int, _ second: Int) {
        let reach = bodies[first].radius + bodies[second].radius
        // 左右就離得夠遠的先跳過：四十顆一步要看三千多對，整顆抄出來再看，開機安置會拖到兩倍久
        if abs(bodies[second].x - bodies[first].x) >= reach {
            return
        }
        var one = bodies[first]
        var two = bodies[second]
        let deltaX = two.x - one.x
        let deltaY = two.y - one.y
        let squared = deltaX * deltaX + deltaY * deltaY
        if squared >= reach * reach || squared <= JarWorld.minGapSquared {
            return
        }
        let distance = squared.squareRoot()
        let normalX = deltaX / distance
        let normalY = deltaY / distance
        let overlap = (reach - distance) / 2
        one.x -= normalX * overlap
        one.y -= normalY * overlap
        two.x += normalX * overlap
        two.y += normalY * overlap
        let closing = (two.velX - one.velX) * normalX + (two.velY - one.velY) * normalY
        if closing < 0 {
            landOnPile(&one, &two)
            let impulse = (-tuning.beanRest * closing) / 2
            one.velX -= impulse * normalX
            one.velY -= impulse * normalY
            two.velX += impulse * normalX
            two.velY += impulse * normalY
            impact = max(impact, -closing)
        }
        bodies[first] = one
        bodies[second] = two
    }

    private mutating func solvePairs() {
        for first in bodies.indices {
            for second in bodies.indices where second > first {
                collide(first, second)
            }
        }
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

    private mutating func solveWalls(_ seconds: Double) {
        for index in bodies.indices {
            var body = bodies[index]
            let radius = body.radius
            if body.x < radius {
                body.x = radius
                bounce(&body.velX, sign: -1)
                body.velY *= tuning.wallFric
            }
            if body.x > width - radius {
                body.x = width - radius
                bounce(&body.velX, sign: 1)
                body.velY *= tuning.wallFric
            }
            if body.y > height - radius {
                body.y = height - radius
                // 落地那一幀：從上面掉進來的要回報（啵＋觸覺在這一幀，不是按鈕那一幀）
                if bounce(&body.velY, sign: 1), body.fresh {
                    body.fresh = false
                    landed.append(body.id)
                }
                body.velX = tuning.rolled(body.velX, seconds: seconds)
            }
            // 上緣：從上面外面掉進來的可以在上面；落定的、已經整顆進來過的（斷藤那顆）不准飛出去
            if body.y < radius, !body.fresh || body.prevY >= radius {
                body.y = radius
                bounce(&body.velY, sign: -1)
            }
            // 牆之後才擋路的東西：牆把被擠出去的壓回來時會壓進分頁列的圓頭，最後一步要是推出來（推的時候不出牆）
            for obstacle in obstacles {
                push(&body, from: obstacle, seconds: seconds)
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
        for _ in 0 ..< tuning.iterations {
            solvePairs()
            solveWalls(seconds)
        }
        roll(seconds)
    }

    /// 開機安置：照每顆的半徑隨機撒，靜置重力預跑 settleSteps 步，進畫面時番茄已經落定。
    mutating func seed(_ radii: [Double]) {
        bodies = []
        landed = []
        guard width > 0, height > 0 else { return }
        for radius in radii.prefix(tuning.maxBeans) {
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

extension JarWorld {
    /// 轉動：只算每顆的角度，不回頭動位置與速度，所以原本怎麼掉、怎麼堆都不變。
    /// 用「這一步實際移動了多少」算，不用速度：躺好的番茄速度每步都在抖，位置才是真的沒動。
    /// 實際移動還要再平滑過：擠在堆裡的番茄會原地來回抖，不濾掉的話位置沒動、臉卻慢慢轉走。
    /// 貼著底的往「滾動不打滑」靠；兩顆貼在一起的互相帶（像齒輪）；半空中的照原本的轉速慢慢停。
    /// 牆不帶轉：整排落回底時，貼著左右牆的那兩顆會被牆搓到每秒轉好幾圈，再一顆帶一顆。
    private mutating func roll(_ seconds: Double) {
        let spin = tuning.spin
        for index in bodies.indices {
            var body = bodies[index]
            body.easedX += ((body.x - body.prevX) / seconds - body.easedX) * spin.smooth
            body.easedY += ((body.y - body.prevY) / seconds - body.easedY) * spin.smooth
            if body.y >= height - body.radius - spin.touch {
                body.spin += (moved(body.easedX) / body.radius - body.spin) * spin.grip
            } else if let normal = touching(body) {
                // 貼著開始鈕、分頁列：跟在底上一樣沿著表面滾不打滑，不然從圓頂滑下去像冰塊
                let along = body.easedY * normal.x - body.easedX * normal.y
                body.spin += (moved(along) / body.radius - body.spin) * spin.grip
            }
            bodies[index] = body
        }
        for first in bodies.indices {
            for second in bodies.indices where second > first {
                gear(first, second)
            }
        }
        for index in bodies.indices {
            var turning = bodies[index].spin * spin.air
            if abs(turning) < spin.sleep {
                turning = 0
            }
            bodies[index].spin = turning
            bodies[index].angle += turning * seconds
        }
    }

    /// 不到 still 的移動當作沒動。
    private func moved(_ speed: Double) -> Double {
        abs(speed) > tuning.spin.still ? speed : 0
    }

    /// 兩顆貼在一起：沿著接觸面，兩顆實際的相對移動；扣掉各自轉動帶的，
    /// 剩下的是接觸點互搓多少，兩顆各分一半。
    private mutating func gear(_ first: Int, _ second: Int) {
        let reach = bodies[first].radius + bodies[second].radius + tuning.spin.touch
        if abs(bodies[second].x - bodies[first].x) > reach {
            return
        }
        let one = bodies[first]
        let two = bodies[second]
        let deltaX = two.x - one.x
        let deltaY = two.y - one.y
        let distance = hypot(deltaX, deltaY)
        if distance > reach || distance <= JarWorld.minTouchGap {
            return
        }
        let relative = (two.easedX - one.easedX) * -deltaY + (two.easedY - one.easedY) * deltaX
        let along = relative / distance
        let carried = one.spin * one.radius + two.spin * two.radius
        let slip = (moved(along) - carried) * tuning.spin.grip / 2
        bodies[first].spin += slip / one.radius
        bodies[second].spin += slip / two.radius
    }
}
