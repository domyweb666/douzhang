import CoreMotion
import Foundation
import Observation

/// 番茄堆裡的一顆要畫成什麼樣：多長（決定大小）、哪個標籤色。
struct JarBean: Equatable {
    var len: Double
    var color: TomatoColor
}

/// 番茄堆的現場：物理世界、每顆的顏色、傾斜、音效與觸覺。畫面每一幀叫 advance，再照 bodies 畫。
/// 番茄都躺好之後就睡著（asleep），畫面停止每幀重畫；點一下、掉新的一顆、手機一傾斜就醒來。
@MainActor
@Observable
final class JarScene {
    /// 都躺好了：畫面不用每幀重畫
    private(set) var asleep = false

    @ObservationIgnored private(set) var world = JarWorld(tuning: .standard)
    @ObservationIgnored private var colors: [Int: TomatoColor] = [:]
    @ObservationIgnored private var beans: [JarBean] = []
    /// 上次看到幾顆；nil＝還沒量到寬高、還沒安置
    @ObservationIgnored private(set) var known: Int?
    @ObservationIgnored private var pending: [(dueAt: TimeInterval, bean: JarBean)] = []
    @ObservationIgnored private var lastFrame: TimeInterval = 0
    @ObservationIgnored private var lastHit: TimeInterval = 0
    @ObservationIgnored private var quietFrames = 0
    @ObservationIgnored private var slow = SlowWatch()
    @ObservationIgnored private let sounds = JarSounds()
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var targetX = 0.0
    @ObservationIgnored private var targetY = JarTuning.standard.gravity

    /// 靜止版（減少動態、或連續掉幀）：不傾斜、不彈，新的一顆直接出現在底，啵與觸覺照樣。
    @ObservationIgnored var reduceMotion = false
    @ObservationIgnored var soundOn = true
    /// 停在這一頁嗎：停在別頁就關感測器
    @ObservationIgnored var active = true
    /// 三頁正在滑、或停在別頁：感測器的讀數不理，不醒來
    @ObservationIgnored private var frozen = false
    @ObservationIgnored var onKnown: (Int) -> Void = { _ in }

    var isStill: Bool {
        reduceMotion || slow.tooSlow
    }

    func color(of body: JarBody) -> TomatoColor {
        colors[body.id] ?? .red
    }

    // MARK: 跟上今天的番茄

    /// 第一次量到寬高：先擺上次看到的那些，多出來的（鈴響時收下的）再照常掉進來。
    func layout(width: Double, height: Double, beans: [JarBean], seen: Int?) {
        let isFirst = world.width == 0
        world.width = width
        world.height = height
        guard isFirst, width > 0, height > 0 else { return }
        let start = seen.map { min($0, beans.count) } ?? beans.count
        seed(Array(beans.prefix(start)))
        follow(beans)
    }

    /// 多一顆就掉一顆；數目對不上（換日、匯入、清空）就重新安置。
    /// drops 是 false：整份換過了（同步、匯入、清空），多的是別台收的，直接躺好。
    /// 顆數一樣也可能是別的番茄，所以看內容有沒有變。
    func follow(_ next: [JarBean], drops: Bool = true) {
        let before = beans
        beans = next
        guard let seenCount = known else { return }
        if !drops {
            if next != before {
                join(next)
            }
        } else if next.count == seenCount + 1, let last = next.last {
            let delay = isStill ? 0 : Tokens.Motion.dropDelay
            pending.append((dueAt: Date().timeIntervalSinceReferenceDate + delay, bean: last))
        } else if next.count != seenCount {
            pending = []
            seed(next)
        }
        known = next.count
        onKnown(next.count)
        wake()
    }

    private func seed(_ list: [JarBean]) {
        world.seed(list.map { world.radiusFor(minutes: $0.len) })
        colors = [:]
        for (body, bean) in zip(world.bodies, list) {
            colors[body.id] = bean.color
        }
        known = list.count
    }

    /// 別台的直接躺好。這台剛收的那顆（排最後）還沒掉、正在掉，就讓它照樣掉完。
    /// 新清單的最後一顆不是它（清空、匯入換掉了）就整份躺好：不准掉一顆已經不在的。
    private func join(_ next: [JarBean]) {
        let waiting = pending.last?.bean
        let falling = world.bodies.last(where: \.fresh)
        let color = falling.flatMap { colors[$0.id] }
        guard let mine = next.last,
              waiting == mine || (waiting == nil && color == mine.color)
        else {
            pending = []
            seed(next)
            return
        }
        seed(Array(next.dropLast()))
        guard waiting == nil, let falling else { return }
        world.addBody(falling)
        if let added = world.bodies.last {
            colors[added.id] = mine.color
        }
    }

    private func drop(_ bean: JarBean) {
        guard world.bodies.count < world.tuning.maxBeans else { return }
        let radius = world.radiusFor(minutes: bean.len)
        let x = world.width / 2 + Double.random(in: -1 ... 1) * radius
        var body = JarBody(id: 0, x: x, y: world.height - radius, radius: radius)
        body.angle = world.randomLean()
        if isStill {
            world.addBody(body)
            sounds.land(sound: soundOn)
        } else {
            body.y = -radius * 2
            body.velX = Double.random(in: -1 ... 1) * Tokens.Motion.dropVelXSpread
            body.velY = Tokens.Motion.dropVelY
            body.fresh = true
            world.addBody(body)
        }
        if let added = world.bodies.last {
            colors[added.id] = bean.color
        }
    }

    // MARK: 每一幀

    /// 走一幀：先把該掉的掉下來，再走物理、處理落地與碰撞。now 是這一幀的時刻（秒）。
    func advance(now: TimeInterval) {
        guard known != nil else { return }
        let due = pending.filter { $0.dueAt <= now }
        pending.removeAll { $0.dueAt <= now }
        for item in due {
            drop(item.bean)
        }
        if isStill {
            settleQuietly()
            return
        }
        let elapsed = lastFrame > 0 ? now - lastFrame : Tokens.Motion.frameMax / 2
        // 同一個時刻被畫兩次（畫面停著時重畫）：時間沒走就不算，不然會除以零
        if elapsed <= 0 {
            return
        }
        lastFrame = now
        let before = world.bodies
        stepWorld(min(Tokens.Motion.frameMax, elapsed))
        if !world.landed.isEmpty {
            sounds.land(sound: soundOn)
        }
        if world.impact > Tokens.Sound.hitThreshold, now - lastHit > Tokens.Sound.hitGap {
            lastHit = now
            sounds.hit(sound: soundOn, impact: world.impact)
        }
        slow.count(now: now)
        watchQuiet(before: before)
    }

    private func stepWorld(_ seconds: Double) {
        world.gravityX += (targetX - world.gravityX) * Tokens.Motion.tiltSmooth
        world.gravityY += (targetY - world.gravityY) * Tokens.Motion.tiltSmooth
        world.impact = 0
        world.landed = []
        let part = seconds / Double(Tokens.Motion.substeps)
        for _ in 0 ..< Tokens.Motion.substeps {
            world.step(part)
        }
    }

    /// 靜止版沒有東西在動：感測器關掉，畫完這一幀就睡。
    private func settleQuietly() {
        if motion.isAccelerometerActive {
            motion.stopAccelerometerUpdates()
        }
        if pending.isEmpty {
            sleepSoon()
        }
    }

    /// 每顆移動都小於門檻、也沒有還在掉的，連續這麼多幀就睡。
    private func watchQuiet(before: [JarBody]) {
        let moving = zip(before, world.bodies).contains { old, new in
            new.fresh
                || abs(new.x - old.x) > Tokens.Motion.quietDistance
                || abs(new.y - old.y) > Tokens.Motion.quietDistance
                || abs(new.angle - old.angle) > Tokens.Motion.quietAngle
        }
        quietFrames = moving || !pending.isEmpty || before.count != world.bodies.count
            ? 0
            : quietFrames + 1
        if quietFrames >= Tokens.Motion.quietFrames {
            sleepSoon()
        }
    }

    /// 現在正在畫，不能當場改畫面會讀的狀態：排到這一幀之後。
    private func sleepSoon() {
        Task { @MainActor in
            if self.pending.isEmpty {
                self.asleep = true
            }
        }
    }

    private func wake() {
        quietFrames = 0
        restartClock()
        if asleep {
            asleep = false
        }
    }

    /// 停過一陣子再接著畫：停著的那段不算時間，也不算掉幀，不然停停醒醒幾次就會退成靜止版。
    private func restartClock() {
        lastFrame = 0
        slow.restart()
    }
}

// MARK: 滑頁時凍結

extension JarScene {
    /// 滑動一開始就凍住，停回這一頁才接著走。睡著的照樣睡著，不因為滑走再滑回來就重畫。
    func setFrozen(_ isOn: Bool) {
        frozen = isOn
        if !isOn {
            restartClock()
        }
    }

    // MARK: 點一下、傾斜

    /// 點一下：附近的番茄往上彈。靜止版不彈。
    func tap(x: Double, y: Double) {
        if isStill {
            return
        }
        world.tap(x: x, y: y)
        wake()
    }

    /// 傾斜：加速度計換成重力向量的目標值；關掉時回到靜置重力。沒有加速度計（模擬器）就什麼都不做。
    /// 只是滑走的話留著原本的方向：滑回來還沒接上感測器的那一下，番茄不會自己滾。
    func setTilt(_ isOn: Bool) {
        motion.stopAccelerometerUpdates()
        guard isOn, !isStill, motion.isAccelerometerAvailable else {
            targetX = 0
            targetY = world.tuning.gravity
            return
        }
        guard active else { return }
        motion.accelerometerUpdateInterval = JarWorld.frame
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let reading = data?.acceleration else { return }
            MainActor.assumeIsolated {
                self.tilt(x: reading.x, y: reading.y)
            }
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
        motion.stopAccelerometerUpdates()
    }
}
