import Foundation

/// 番茄堆這一幀要不要「嗒」一下、震多大力。
struct JarBeat {
    private var last: TimeInterval = 0

    /// 落地那一幀已經「啵」過、震過了：同一撞不再嗒，接著的間隔也從這裡算。
    mutating func landed(now: TimeInterval) {
        last = now
    }

    /// 撞得夠快、離上一下夠久才算一下。
    mutating func hits(impact: Double, now: TimeInterval) -> Bool {
        guard impact > Tokens.Sound.hitThreshold, now - last > Tokens.Sound.hitGap else {
            return false
        }
        last = now
        return true
    }

    /// 「嗒」排到的時候是不是已經晚太多、不該播了。
    static func isLate(asked: TimeInterval, now: TimeInterval) -> Bool {
        now - asked > Tokens.Sound.hitLate
    }

    /// 震多大力（0–1）：剛過門檻最輕，撞得越快越重。
    static func strength(_ impact: Double) -> Double {
        let span = Tokens.Sound.hitTapFull - Tokens.Sound.hitThreshold
        let share = min(1, max(0, (impact - Tokens.Sound.hitThreshold) / span))
        return Tokens.Sound.hitTapMin + (1 - Tokens.Sound.hitTapMin) * share
    }
}
