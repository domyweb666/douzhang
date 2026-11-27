import Foundation

/// 番茄堆的傾斜：什麼時候接感測器、讀數怎麼變成重力方向、斜多少才醒來。
extension JarScene {
    /// 傾斜：感測器的重力換成番茄堆重力的目標值；關掉時回到靜置重力。沒有感測器（模擬器）就什麼都不做。
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
        let pull = JarPull.gravity(x: x, y: y)
        targetX = pull.x
        targetY = pull.y
        sensor.pace(for: self)
        guard asleep else {
            sensor.calm.forget()
            return
        }
        // 跟睡著時的重力比（睡著時它停著不動）：慢慢傾斜也會累積到門檻；
        // 放在桌上不動、手拿著小抖動時，平滑過的讀數到不了門檻，畫面不會一直重畫
        let shift = sensor.calm.shift(
            x: targetX,
            y: targetY,
            gravityX: world.gravityX,
            gravityY: world.gravityY
        )
        if shift > Tokens.Motion.tiltWake {
            wake()
        }
    }

    /// 感測器多久讀一次：睡著時讀慢一點省電，醒著每秒 tiltRate 次
    var sensorInterval: TimeInterval {
        1 / (asleep ? Tokens.Motion.restRate : JarTuning.tiltRate)
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
