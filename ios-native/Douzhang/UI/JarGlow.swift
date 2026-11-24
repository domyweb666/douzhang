import Foundation

/// 靜止版點番茄：最近那顆亮一下（淡進淡出，不位移）。
struct JarGlow {
    private var lit: Int?
    private var since: TimeInterval?
    private var elapsed: TimeInterval = 0

    var isOn: Bool {
        lit != nil
    }

    /// 從下一幀開始亮；亮到一半點別顆就換那顆。
    mutating func light(_ body: Int) {
        lit = body
        since = nil
        elapsed = 0
    }

    mutating func advance(now: TimeInterval) {
        guard isOn else { return }
        let start = since ?? now
        since = start
        elapsed = now - start
        if elapsed >= Tokens.Motion.glowRise + Tokens.Motion.glowFall {
            lit = nil
        }
    }

    /// 這顆現在多亮（0–1）。
    func strength(of body: Int) -> Double {
        guard lit == body else { return 0 }
        if elapsed < Tokens.Motion.glowRise {
            return elapsed / Tokens.Motion.glowRise
        }
        return max(0, 1 - (elapsed - Tokens.Motion.glowRise) / Tokens.Motion.glowFall)
    }
}
