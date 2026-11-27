import Foundation
import Observation

/// 番茄堆的現場：物理世界、每顆的顏色、傾斜、音效與觸覺。畫面每一幀叫 advance，再照 bodies 畫。
/// 番茄都躺好之後就睡著（asleep），畫面停止每幀重畫；點一下、掉新的一顆、手機一傾斜就醒來。
/// 新的一顆怎麼掛、怎麼掉、放不下怎麼縮在 JarScene+Drop。
@MainActor
@Observable
final class JarScene {
    /// 都躺好了：畫面不用每幀重畫
    private(set) var asleep = false

    @ObservationIgnored var world = JarWorld(tuning: .standard)
    @ObservationIgnored var colors: [Int: TomatoColor] = [:]
    /// 這週的番茄放不下時，全部的半徑都乘上這個（JarFit）；放得下是 1
    @ObservationIgnored var scale = 1.0
    @ObservationIgnored private var beans: [JarBean] = []
    /// 上次看到幾顆；nil＝還沒量到寬高、還沒安置
    @ObservationIgnored private(set) var known: Int?
    @ObservationIgnored private var pending: [(dueAt: TimeInterval, bean: JarBean)] = []
    /// 還掛在藤上、沒掉進物理世界的
    @ObservationIgnored var vines = JarVines()
    @ObservationIgnored private var lastFrame: TimeInterval = 0
    /// 走過了但還不夠一步的時間
    @ObservationIgnored private var leftover: TimeInterval = 0
    @ObservationIgnored private var beat = JarBeat()
    @ObservationIgnored private(set) var glow = JarGlow()
    @ObservationIgnored private var quiet = JarQuiet()
    @ObservationIgnored private var slow = SlowWatch()
    @ObservationIgnored let sounds = JarSounds.shared
    @ObservationIgnored let sensor = JarTilt.shared
    /// 重力要往哪個方向去（傾斜），每一步靠過去一點
    @ObservationIgnored var targetX = 0.0
    @ObservationIgnored var targetY = JarTuning.standard.gravity

    /// 靜止版（減少動態、或連續掉幀）：不傾斜、不彈，新的一顆直接出現在底，啵與觸覺照樣。
    @ObservationIgnored var reduceMotion = false
    @ObservationIgnored var soundOn = true
    /// 停在這一頁嗎：停在別頁就關感測器
    @ObservationIgnored var active = true
    /// 三頁正在滑、或停在別頁：感測器的讀數不理，不醒來
    @ObservationIgnored private(set) var frozen = false
    @ObservationIgnored var onKnown: (Int) -> Void = { _ in }
    /// 上一幀走了幾步（量測用）
    @ObservationIgnored private(set) var lastSteps = 0

    var isStill: Bool {
        reduceMotion || slow.tooSlow
    }

    /// 畫面落在前後兩步之間的幾成：物理的步長固定，螢幕多快都從這裡內插。
    var blend: Double {
        leftover / JarTuning.tick
    }

    func color(of body: JarBody) -> TomatoColor {
        colors[body.id] ?? .red
    }

    // MARK: 跟上這週的番茄

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

    /// 回到待機接著用上次的現場：上次那些原樣在前面就只掉多的；殼記的顆數對不上（那時合進別台的）、
    /// 前面換了顏色或大小（改標籤、換週）就照第一次擺。殼說整份換過了照同步躺好；還沒量過寬高的由 layout 擺。
    /// 掉幀重新數：以前每次回來都新建一個，退成靜止版的也重新給一次機會。
    func resume(_ next: [JarBean], seen: Int?) {
        guard let known else { return }
        slow = SlowWatch()
        guard let seen else { return follow(next, drops: false) }
        if seen != known || !next.starts(with: beans) {
            pending = []
            seed(Array(next.prefix(min(seen, next.count))))
        }
        follow(next)
    }

    /// 多一顆就掉一顆；數目對不上（換週、匯入、清空）就重新安置。同一週換日清單不變，這裡不會被叫。
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

    /// 照這份重新安置。超過顆數上限只擺最近的那些；放不下就全部等比縮小。
    private func seed(_ list: [JarBean]) {
        vines.keepOnly(nil)
        let shown = Array(list.suffix(world.tuning.maxBeans))
        let sizes = shown.map { world.radiusFor(minutes: $0.len) }
        scale = JarFit.scale(
            radii: sizes,
            width: world.width,
            height: world.height,
            share: world.tuning.fillShare
        )
        world.seed(sizes.map { $0 * scale })
        colors = [:]
        for (body, bean) in zip(world.bodies, shown) {
            colors[body.id] = bean.color
        }
        known = list.count
    }

    /// 別台的直接躺好。這台剛收的那顆（排最後）還沒掉、還掛著、正在掉，就讓它照樣掉完。
    /// 新清單的最後一顆不是它（清空、匯入換掉了）就整份躺好：不准掉一顆已經不在的。
    private func join(_ next: [JarBean]) {
        let waiting = pending.last?.bean
        let hung = vines.holding.last
        let falling = world.bodies.last(where: \.fresh)
        let color = falling.flatMap { colors[$0.id] }
        // 越後收的在越前面那一段：還在等的是最新的，再來是掛著的，再來才是正在掉的
        let latest = waiting ?? hung?.bean
        guard let mine = next.last,
              latest == mine || (latest == nil && color == mine.color)
        else {
            pending = []
            seed(next)
            return
        }
        let flying = vines
        seed(Array(next.dropLast()))
        if waiting != nil {
            return
        }
        if let hung {
            vines = flying
            vines.keepOnly(hung)
        } else if let falling {
            add(falling, color: mine.color)
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
        glow.advance(now: now)
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
        lastSteps = stepWorld(min(Tokens.Motion.frameMax, elapsed))
        if !world.landed.isEmpty {
            beat.landed(now: now)
            sounds.land(sound: soundOn)
        } else if beat.hits(impact: world.impact, now: now) {
            sounds.hit(sound: soundOn, impact: world.impact)
        }
        slow.count(now: now)
    }

    /// 這一幀的時間切成固定的步走，不夠一步的留到下一幀：120Hz 一幀一步、60Hz 一幀兩步，手感一樣。
    /// 回這一幀走了幾步。
    private func stepWorld(_ seconds: Double) -> Int {
        world.impact = 0
        world.landed = []
        leftover += seconds
        var steps = 0
        while leftover >= JarTuning.tick {
            steps += 1
            leftover -= JarTuning.tick
            world.gravityX += (targetX - world.gravityX) * JarTuning.tiltPull
            world.gravityY += (targetY - world.gravityY) * JarTuning.tiltPull
            world.step(JarTuning.tick)
            for vine in vines.step(JarTuning.tick) {
                release(vine)
            }
            if quiet.settled(world.bodies, isBusy: hasMore) {
                sleepSoon()
            }
        }
        return steps
    }

    /// 還有要掉的，或藤還沒縮完：不准睡
    private var hasMore: Bool {
        !pending.isEmpty || !vines.isEmpty
    }

    /// 靜止版沒有東西在動：感測器關掉，還掛著的直接到底，畫完這一幀就睡（有一顆還在亮就等它淡回去）。
    private func settleQuietly() {
        sensor.stop(for: self)
        for vine in vines.holding {
            lay(vine.bean, radius: vine.radius)
        }
        vines = JarVines()
        if pending.isEmpty, !glow.isOn {
            sleepSoon()
        }
    }
}

// MARK: 睡著、醒來

extension JarScene {
    /// 現在正在畫，不能當場改畫面會讀的狀態：排到這一幀之後。
    private func sleepSoon() {
        Task { @MainActor in
            if !self.hasMore, !self.glow.isOn {
                self.asleep = true
            }
        }
    }

    func wake() {
        sounds.ready()
        quiet.restart()
        restartClock()
        if asleep {
            asleep = false
            sensor.pace(for: self)
        }
    }

    /// 停過一陣子再接著畫：停著的那段不算時間，也不算掉幀，不然停停醒醒幾次就會退成靜止版。
    private func restartClock() {
        lastFrame = 0
        slow.restart()
    }

    // MARK: 滑頁時凍結

    /// 滑動一開始就凍住，停回這一頁才接著走。睡著的照樣睡著，不因為滑走再滑回來就重畫。
    func setFrozen(_ isOn: Bool) {
        frozen = isOn
        if !isOn {
            restartClock()
        }
    }

    // MARK: 點一下

    /// 點一下：附近的番茄往上彈。靜止版不彈，最近那顆亮一下。
    func tap(x: Double, y: Double) {
        if !isStill {
            world.tap(x: x, y: y)
        } else if let near = world.nearest(x: x, y: y) {
            glow.light(near)
        }
        wake()
    }
}
