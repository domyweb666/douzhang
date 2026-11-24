import Foundation

/// 每秒結算一次幀數：連續幾秒低於門檻就退成靜止版（低電量、很舊的手機的退路）。
struct SlowWatch {
    private var frames = 0
    private var since: TimeInterval = 0
    private var lowSeconds = 0
    private(set) var tooSlow = false

    mutating func count(now: TimeInterval) {
        frames += 1
        if since == 0 {
            since = now
        }
        guard now - since > 1 else { return }
        lowSeconds = frames < Params.jarLowFps ? lowSeconds + 1 : 0
        frames = 0
        since = now
        if lowSeconds >= Params.jarLowFpsSeconds {
            tooSlow = true
        }
    }

    /// 停過一陣子再開始畫：從下一幀重新數，停著的時間不算進這一秒
    mutating func restart() {
        frames = 0
        since = 0
    }
}
