import Foundation

/// 番茄都躺好了沒。每 1/60 秒看一次，跟螢幕畫多快無關：
/// 每顆這一次都走不到門檻、連續這麼多次，而且這一整段加起來也沒走多遠，才算躺好。
/// 後面那條是給慢慢起步的：手機只斜一點點，剛開始滾的每一次都走不到門檻，
/// 只看單次的話滾到一半會被凍住、等再斜一點才又滾，一頓一頓的。
///
/// 另一條給卡在原地抖的：堆裡偶爾有一顆被兩旁擠著懸在半空，往下的速度每步累積、又被推回來，
/// 每 1/60 秒來回走一到三點、永遠過不了上面那條（20 顆以上約 1% 的堆，畫面一直重畫）。
/// 這種看半秒的平均位置：之後每個半秒的平均都沒離開第一個半秒的平均 quietDrift，就是沒在走、只是在抖。
/// 比平均不比頭尾：抖的週期跟半秒對不齊，頭尾剛好一高一低就會超過；比第一個不比上一個：慢慢爬的才擋得住。
/// 還要等每顆都抖回平均位置附近、這一次也走不到門檻才睡，停下來那一下看不出跳。
struct JarQuiet {
    private typealias Spot = (x: Double, y: Double)

    private var ticks = 0
    private var calm = 0
    private var last: [JarBody] = []
    private var start: [JarBody] = []
    /// 這半秒每顆位置的加總、加了幾次
    private var sums: [Spot] = []
    private var counted = 0
    /// 抖之前第一個半秒的平均、最近這半秒的平均、之後連續幾個半秒沒離開第一個
    private var anchor: [Spot] = []
    private var mean: [Spot] = []
    private var steady = 0

    mutating func restart() {
        self = JarQuiet()
    }

    /// 物理走完一步叫一次；isBusy 是還有沒掉下來的。回是不是躺好夠久了。
    mutating func settled(_ bodies: [JarBody], isBusy: Bool) -> Bool {
        ticks += 1
        guard ticks >= Tokens.Motion.substeps else { return false }
        ticks = 0
        defer { last = bodies }
        if isBusy || bodies.contains(where: \.fresh) {
            calm = 0
            forgetShaking()
            return false
        }
        let isMoved = JarQuiet.moved(last, bodies)
        return isCalm(bodies, isMoved: isMoved) || isShakingInPlace(bodies, isMoved: isMoved)
    }

    private mutating func isCalm(_ bodies: [JarBody], isMoved: Bool) -> Bool {
        if isMoved {
            calm = 0
            return false
        }
        if calm == 0 {
            start = last
        }
        calm += 1
        guard calm >= Tokens.Motion.quietFrames else { return false }
        if JarQuiet.drifted(start, bodies, limit: JarTuning.quietDrift) {
            calm = 0
            return false
        }
        return true
    }

    private mutating func isShakingInPlace(_ bodies: [JarBody], isMoved: Bool) -> Bool {
        let spots = bodies.map { Spot(x: $0.x, y: $0.y) }
        if sums.count != spots.count {
            forgetShaking()
            sums = Array(repeating: Spot(x: 0, y: 0), count: spots.count)
        }
        for (index, spot) in spots.enumerated() {
            sums[index].x += spot.x
            sums[index].y += spot.y
        }
        counted += 1
        if counted == Tokens.Motion.quietFrames {
            closeHalfSecond()
        }
        guard steady >= Tokens.Motion.shakeHalves, !isMoved else { return false }
        return !JarQuiet.away(mean, spots, limit: Tokens.Motion.quietDistance)
    }

    private mutating func closeHalfSecond() {
        let average = sums.map { Spot(x: $0.x / Double(counted), y: $0.y / Double(counted)) }
        if !anchor.isEmpty, !JarQuiet.away(anchor, average, limit: JarTuning.quietDrift) {
            steady += 1
        } else {
            anchor = average
            steady = 0
        }
        mean = average
        sums = sums.map { _ in Spot(x: 0, y: 0) }
        counted = 0
    }

    private mutating func forgetShaking() {
        sums = []
        counted = 0
        anchor = []
        mean = []
        steady = 0
    }

    private static func moved(_ before: [JarBody], _ after: [JarBody]) -> Bool {
        drifted(before, after, limit: Tokens.Motion.quietDistance)
            || zip(before, after).contains { old, new in
                abs(new.angle - old.angle) > Tokens.Motion.quietAngle
            }
    }

    /// 有哪一顆走得比 limit 遠；顆數不一樣也算。
    private static func drifted(_ before: [JarBody], _ after: [JarBody], limit: Double) -> Bool {
        before.count != after.count || zip(before, after).contains { old, new in
            abs(new.x - old.x) > limit || abs(new.y - old.y) > limit
        }
    }

    private static func away(_ before: [Spot], _ after: [Spot], limit: Double) -> Bool {
        before.count != after.count || zip(before, after).contains { old, new in
            abs(new.x - old.x) > limit || abs(new.y - old.y) > limit
        }
    }
}
