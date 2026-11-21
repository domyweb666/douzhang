import Foundation

enum Pose {
    case portrait, landscape
}

/// 一筆加速度。單位是 g 或 m/s² 都可以，判斷前會先除以總長。
struct Acceleration {
    var x: Double
    var y: Double
    var z: Double
}

/// 從直拿起算：按開始那一刻畫面是直的。之後第一次橫放就算「換了」。
struct PoseTracker: Equatable {
    var pose = Pose.portrait
    var candidate: Pose?
    var since = 0.0
}

/// 吃一筆加速度的結果。changed 是這一筆剛確定換成的新姿勢，沒換是 nil。
struct PoseStep {
    var tracker: PoseTracker
    var changed: Pose?
}

/// 手機現在是直拿還是橫放（聚焦模式用）。純函式，不碰感測器、不碰畫面。
/// 只看重力落在哪一軸：不管哪一邊朝下，所以開著直向鎖定也判斷得出來。
/// 平放在桌上（重力在 z 軸）兩個都不算，維持上一個姿勢。
enum Posture {
    static func poseOf(_ sample: Acceleration) -> Pose? {
        let squared = sample.x * sample.x + sample.y * sample.y + sample.z * sample.z
        let gravity = squared.squareRoot()
        guard gravity > 0 else { return nil }
        if abs(sample.x) / gravity >= Params.Zen.ratio {
            return .landscape
        }
        if abs(sample.y) / gravity >= Params.Zen.ratio {
            return .portrait
        }
        return nil
    }

    /// 新姿勢要連續維持 dwellMs 才算數：拿起手機晃一下、轉個角度看一眼都不算。
    static func track(_ tracker: PoseTracker, sample: Acceleration, now: Millis) -> PoseStep {
        guard let seen = poseOf(sample), seen != tracker.pose else {
            var cleared = tracker
            cleared.candidate = nil
            return PoseStep(tracker: cleared, changed: nil)
        }
        if seen != tracker.candidate {
            var next = tracker
            next.candidate = seen
            next.since = now
            return PoseStep(tracker: next, changed: nil)
        }
        if now - tracker.since < Params.Zen.dwellMs {
            return PoseStep(tracker: tracker, changed: nil)
        }
        let settled = PoseTracker(pose: seen, candidate: nil, since: now)
        return PoseStep(tracker: settled, changed: seen)
    }
}
