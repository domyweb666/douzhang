import Foundation

/// 番茄堆裡擋路的東西（開始鈕、分頁列），用番茄堆自己的座標。四角圓到最圓：正方形是圓，長條是膠囊。
struct JarObstacle: Equatable {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    var corner: Double {
        min(maxX - minX, maxY - minY) / 2
    }

    /// 框往內縮一個圓角剩下的那一段（圓是一點、膠囊是一條線）上，離這一點最近的地方。
    /// 番茄中心離它不到「圓角＋番茄半徑」就是碰到了。
    func core(x: Double, y: Double) -> (x: Double, y: Double) {
        let corner = corner
        return (
            x: min(max(x, minX + corner), maxX - corner),
            y: min(max(y, minY + corner), maxY - corner)
        )
    }
}

/// 番茄撞開始鈕、分頁列：擋住、停在上面、從旁邊滾下去。
extension JarWorld {
    /// 開始鈕、分頁列換了地方（第一次量到、字級變了）：壓在裡面的番茄搬出來。
    mutating func setObstacles(_ next: [JarObstacle]) {
        obstacles = next
        liftOut()
    }

    /// 壓在擋路的東西裡面的（剛撒好、剛擺上來、靜止版直接放在底）搬到外面貼著。
    /// 往最近的那邊出去；那邊朝下就改朝上（分頁列底下太窄，會跟底互相推著卡在裡面），出了牆就從正上面出去。
    /// 速度歸零：是搬出來的不是撞出來的，不准彈飛。
    /// 從一個搬出來可能壓進另一個（分頁列上面就是開始鈕）：有幾個就看幾輪。
    mutating func liftOut() {
        for _ in obstacles.indices {
            for index in bodies.indices {
                liftOut(index)
            }
        }
    }

    private mutating func liftOut(_ index: Int) {
        for obstacle in obstacles {
            var body = bodies[index]
            let core = obstacle.core(x: body.x, y: body.y)
            let reach = obstacle.corner + body.radius
            let deltaX = body.x - core.x
            let deltaY = body.y - core.y
            let distance = hypot(deltaX, deltaY)
            if distance >= reach {
                continue
            }
            let isCentered = distance <= JarWorld.minTouchGap
            let normalX = isCentered ? 0 : deltaX / distance
            let normalY = isCentered ? -1 : -abs(deltaY / distance)
            body.x = core.x + normalX * reach
            body.y = core.y + normalY * reach
            if body.x < body.radius || body.x > width - body.radius {
                body.x = core.x
                body.y = core.y - reach
            }
            body.velX = 0
            body.velY = 0
            bodies[index] = body
        }
    }

    /// 撞到了：跟撞牆一樣壓出來、沿法線反彈留 wallRest；貼著表面滑跟在底上滾一樣慢下來。
    /// 從上面掉進來第一次碰到它也算落地。
    mutating func push(_ body: inout JarBody, from obstacle: JarObstacle, seconds: Double) {
        let core = obstacle.core(x: body.x, y: body.y)
        let reach = obstacle.corner + body.radius
        let deltaX = body.x - core.x
        let deltaY = body.y - core.y
        let squared = deltaX * deltaX + deltaY * deltaY
        if squared >= reach * reach {
            return
        }
        let distance = squared.squareRoot()
        // 中心剛好在中線上分不出方向：往上推
        let isCentered = distance <= JarWorld.minTouchGap
        let normalX = isCentered ? 0 : deltaX / distance
        let normalY = isCentered ? -1 : deltaY / distance
        body.x = core.x + normalX * reach
        body.y = core.y + normalY * reach
        // 夾在牆與圓頭之間：照法線推會出牆、被牆壓回來，被上面的堆一步一步壓著沿牆滑過圓頭，
        // 卡進分頁列底下（底下只剩 46pt 放不下）。貼著牆的改成沿著牆推出去
        let wall = min(max(body.x, body.radius), width - body.radius)
        if wall != body.x {
            let side = wall - core.x
            let rise = max(0, reach * reach - side * side).squareRoot()
            body.x = wall
            body.y = core.y + (normalY > 0 ? rise : -rise)
        }
        var outward = body.velX * normalX + body.velY * normalY
        var along = body.velY * normalX - body.velX * normalY
        if bounce(&outward, sign: -1), body.fresh {
            body.fresh = false
            landed.append(body.id)
        }
        along = tuning.rolled(along, seconds: seconds)
        body.velX = outward * normalX - along * normalY
        body.velY = outward * normalY + along * normalX
    }

    /// 貼著哪個擋路的東西：回從它指向這顆的方向；都沒貼著回 nil。
    func touching(_ body: JarBody) -> (x: Double, y: Double)? {
        for obstacle in obstacles {
            let core = obstacle.core(x: body.x, y: body.y)
            let deltaX = body.x - core.x
            let deltaY = body.y - core.y
            let distance = hypot(deltaX, deltaY)
            let reach = obstacle.corner + body.radius + tuning.spin.touch
            if distance > JarWorld.minTouchGap, distance <= reach {
                return (x: deltaX / distance, y: deltaY / distance)
            }
        }
        return nil
    }
}
