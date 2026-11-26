import Foundation

/// 番茄堆的傾斜：什麼時候接感測器、讀數怎麼變成重力方向、斜多少才醒來。
extension JarScene {
    /// 傾斜：加速度計換成重力向量的目標值；關掉時回到靜置重力。沒有加速度計（模擬器）就什麼都不做。
    /// 只是滑走的話留著原本的方向：滑回來還沒接上感測器的那一下，番茄不會自己滾。
    func setTilt(_ isOn: Bool) {
        sensor.stop(for: self)
        guard isOn, !isStill else {
            targetX = 0
            targetY = world.tuning.gravity
            return
        }
        guard active else { return }
        sensor.start(for: self) { [weak self] x, y in
            self?.tilt(x: x, y: y)
        }
    }

    private func tilt(x: Double, y: Double) {
        if frozen {
            return
        }
        targetX = x * Tokens.Motion.tiltPerG
        targetY = -y * Tokens.Motion.tiltPerG
        // 跟睡著時的重力比（睡著時它停著不動）：慢慢傾斜也會累積到門檻；
        // 放在桌上不動時，感測器的小雜訊不會讓畫面一直重畫
        let shift = abs(targetX - world.gravityX) + abs(targetY - world.gravityY)
        if asleep, shift > Tokens.Motion.tiltWake {
            wake()
        }
    }

    /// 停穩在別頁才關感測器，停穩回這一頁才接上。滑到一半又滑回來的不動它。
    func setActive(_ isOn: Bool, tilt isTiltOn: Bool) {
        if active == isOn {
            return
        }
        active = isOn
        setTilt(isTiltOn)
    }

    func stop() {
        sensor.stop(for: self)
    }
}
