import Foundation

/// 番茄都躺好了沒。每 1/60 秒看一次，跟螢幕畫多快無關：
/// 每顆這一次都走不到門檻、連續這麼多次，而且這一整段加起來也沒走多遠，才算躺好。
/// 後面那條是給慢慢起步的：手機只斜一點點，剛開始滾的每一次都走不到門檻，
/// 只看單次的話滾到一半會被凍住、等再斜一點才又滾，一頓一頓的。
struct JarQuiet {
    private var ticks = 0
    private var calm = 0
    private var last: [JarBody] = []
    private var start: [JarBody] = []

    mutating func restart() {
        self = JarQuiet()
    }

    /// 物理走完一步叫一次；isBusy 是還有沒掉下來的。回是不是躺好夠久了。
    mutating func settled(_ bodies: [JarBody], isBusy: Bool) -> Bool {
        ticks += 1
        guard ticks >= Tokens.Motion.substeps else { return false }
        ticks = 0
        defer { last = bodies }
        if isBusy || bodies.contains(where: \.fresh) || JarQuiet.moved(last, bodies) {
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
}
