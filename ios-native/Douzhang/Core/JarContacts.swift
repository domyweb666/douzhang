import Foundation

/// 這一步可能碰到的一對（bodies 的位置，first 比 second 小）。
struct JarPair: Equatable {
    var first: Int
    var second: Int
}

/// 這一步裡一顆碰到了什麼：摩擦等迭代走完才扣，一步只扣一次。
struct JarTouch {
    var floor = false
    var wall = false
    /// 貼著擋路的東西：從它指向這顆的方向
    var surface: (x: Double, y: Double)?
}

extension JarWorld {
    /// 這一步可能碰到的那幾對：照左緣排好往右掃，左右離太遠的就不再往下看。
    /// 不這樣的話一百顆一步要看將近五千對，乘上迭代次數與一秒 120 步，開機安置會卡在主執行緒上。
    /// 排回原本「前面那顆先」的順序：一對一對推開的先後會改變堆的樣子，跟原本一樣比較好預料。
    static func nearPairs(_ bodies: [JarBody], slack: Double) -> [JarPair] {
        let order = bodies.indices.sorted { left, right in
            bodies[left].x - bodies[left].radius < bodies[right].x - bodies[right].radius
        }
        var pairs: [JarPair] = []
        for (rank, first) in order.enumerated() {
            let one = bodies[first]
            let rightEdge = one.x + one.radius + slack
            for second in order[(rank + 1)...] {
                let two = bodies[second]
                if two.x - two.radius > rightEdge {
                    break
                }
                if abs(two.y - one.y) < one.radius + two.radius + slack {
                    pairs.append(JarPair(first: min(first, second), second: max(first, second)))
                }
            }
        }
        return pairs.sorted { ($0.first, $0.second) < ($1.first, $1.second) }
    }

    /// 迭代走完才扣摩擦：放在迭代裡的話，堆在底下被上面壓著的番茄一步會被扣好幾次，
    /// 貼牆的一步乘好幾次 0.97 像黏在牆上。底、牆、擋路的東西都用同一種（照比例＋固定扣）。
    mutating func rub(_ touches: [JarTouch], seconds: Double) {
        for index in bodies.indices {
            let touch = touches[index]
            var body = bodies[index]
            if touch.floor {
                body.velX = tuning.rolled(body.velX, seconds: seconds)
            }
            if touch.wall {
                body.velY = tuning.rolled(body.velY, seconds: seconds)
            }
            if let normal = touch.surface {
                let along = body.velY * normal.x - body.velX * normal.y
                let slowed = tuning.rolled(along, seconds: seconds) - along
                body.velX -= slowed * normal.y
                body.velY += slowed * normal.x
            }
            bodies[index] = body
        }
    }
}
