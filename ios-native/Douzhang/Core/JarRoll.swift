import Foundation

extension JarWorld {
    /// 轉動：只算每顆的角度，不回頭動位置與速度，所以原本怎麼掉、怎麼堆都不變。
    /// 貼著底、開始鈕、分頁列的直接照這一步實際移動多少滾（不打滑）：用速度會被堆裡互推的衝量帶著亂轉，
    /// 以前用平滑過的移動、再慢慢靠過去，轉起來比滾慢好幾格，看起來像在滑。
    /// 沒貼著底的靠別顆帶（像齒輪）；碰到貼著底的那顆，一次就帶到不打滑。半空中的照原本的轉速慢慢停。
    /// 牆不帶轉：整排落回底時，貼著左右牆的那兩顆會被牆搓到每秒轉好幾圈，再一顆帶一顆。
    mutating func roll(_ seconds: Double) {
        var rolling = Array(repeating: false, count: bodies.count)
        for index in bodies.indices {
            var body = bodies[index]
            let stepX = (body.x - body.prevX) / seconds
            let stepY = (body.y - body.prevY) / seconds
            body.easedX += (stepX - body.easedX) * tuning.spin.smooth
            body.easedY += (stepY - body.easedY) * tuning.spin.smooth
            if body.y >= height - body.radius - tuning.spin.touch {
                body.spin = moved(stepX) / body.radius
                rolling[index] = true
            } else if let normal = touching(body) {
                // 沿著開始鈕、分頁列的表面滾，不然從圓頂滑下去像冰塊
                body.spin = moved(stepY * normal.x - stepX * normal.y) / body.radius
                rolling[index] = true
            }
            bodies[index] = body
        }
        var touched = rolling
        for pair in pairs {
            gear(pair, rolling: rolling, touched: &touched)
        }
        for index in bodies.indices {
            var turning = bodies[index].spin
            if !touched[index] {
                turning *= tuning.spin.air
            }
            if abs(turning) < tuning.spin.sleep {
                turning = 0
            }
            bodies[index].spin = turning
            bodies[index].angle += turning * seconds
        }
    }

    /// 慢於 still 的移動漸漸當作沒動（照速度的平方淡掉）：躺好的原地抖不會讓臉慢慢轉走，
    /// 快停下來的那一段也是慢慢停，不是一過門檻就突然不轉。
    private func moved(_ speed: Double) -> Double {
        let share = min(1, abs(speed) / tuning.spin.still)
        return speed * share * share
    }

    /// 兩顆貼在一起：沿著接觸面，兩顆實際的相對移動；扣掉各自轉動帶的，剩下的是接觸點互搓多少。
    /// 一顆貼著底的話它的轉動是定的，搓的全部算到另一顆；兩顆都沒貼著底就各分一半、慢慢靠過去。
    private mutating func gear(_ pair: JarPair, rolling: [Bool], touched: inout [Bool]) {
        if rolling[pair.first], rolling[pair.second] {
            return
        }
        let one = bodies[pair.first]
        let two = bodies[pair.second]
        let deltaX = two.x - one.x
        let deltaY = two.y - one.y
        let distance = hypot(deltaX, deltaY)
        let reach = one.radius + two.radius + tuning.spin.touch
        if distance > reach || distance <= JarWorld.minTouchGap {
            return
        }
        touched[pair.first] = true
        touched[pair.second] = true
        let relative = (two.easedX - one.easedX) * -deltaY + (two.easedY - one.easedY) * deltaX
        let carried = one.spin * one.radius + two.spin * two.radius
        let slip = moved(relative / distance) - carried
        if rolling[pair.first] {
            bodies[pair.second].spin += slip / two.radius
        } else if rolling[pair.second] {
            bodies[pair.first].spin += slip / one.radius
        } else {
            let half = slip * tuning.spin.grip / 2
            bodies[pair.first].spin += half / one.radius
            bodies[pair.second].spin += half / two.radius
        }
    }
}
