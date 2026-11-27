import Foundation
import Observation
import os
import QuartzCore

/// 番茄堆的畫面時鐘：跟著螢幕刷新走（CADisplayLink），每一格給「這一格會出現在螢幕上的時刻」。
/// 原本用 TimelineView 的時刻：那是排程的時刻不是螢幕刷新的時刻，7.5 毫秒排一次對上 8.3 毫秒刷一次，
/// 每七十多毫秒會量到一次 15 毫秒，內插照假的時間畫，一秒頓十幾下。
/// 停著（睡著、滑走、不在畫面上）就把 link 關掉，不每格叫醒主執行緒。
@MainActor
@Observable
final class JarClock {
    /// 這一格的時刻（秒，跟 Date 同一個基準：等著掉的、亮一下都用 Date 算）；停著是 nil
    private(set) var now: TimeInterval?
    @ObservationIgnored private var link: JarFrameLink?
    /// 螢幕時間換成 Date 基準要加多少：開的時候量一次，之後每格間隔就是螢幕刷新的間隔，不混進 Date 的抖動
    @ObservationIgnored private var offset: TimeInterval = 0
    /// 量測：只有開發版的畫面會叫它
    @ObservationIgnored var meter = JarMeter()

    func run(_ isOn: Bool) {
        if isOn {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard link == nil else { return }
        offset = Date().timeIntervalSinceReferenceDate - CACurrentMediaTime()
        // 先給現在的時刻：接著畫的第一格就照它走，不會拿停下來之前的舊時刻
        now = Date().timeIntervalSinceReferenceDate
        let next = JarFrameLink { [weak self] frame in
            guard let self else { return false }
            now = frame.targetTimestamp + offset
            return true
        }
        next.start()
        link = next
    }

    func stop() {
        link?.stop()
        link = nil
        now = nil
    }
}

/// 真的接到螢幕刷新的那一段：CADisplayLink 要 @objc 的 target。時鐘不在了就自己關掉，不空轉。
@MainActor
private final class JarFrameLink: NSObject {
    private var link: CADisplayLink?
    /// 回 false 就是時鐘不在了
    private let onFrame: @MainActor (CADisplayLink) -> Bool

    init(onFrame: @escaping @MainActor (CADisplayLink) -> Bool) {
        self.onFrame = onFrame
    }

    func start() {
        let next = CADisplayLink(target: self, selector: #selector(fire))
        next.preferredFrameRateRange = CAFrameRateRange(
            minimum: JarTuning.framesMin,
            maximum: JarTuning.framesMax,
            preferred: JarTuning.framesMax
        )
        next.add(to: .main, forMode: .common)
        link = next
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func fire(_ running: CADisplayLink) {
        if !onFrame(running) {
            stop()
        }
    }
}

/// 番茄堆的量測（只有開發版的畫面會叫）：每秒寫一行 log，真機用 Console 看 org.domyweb.douzhang 的 jar。
/// 每一格隔多久、一格走幾步物理、算加畫花多久；Instruments 的 os_signpost 也看得到每一格的區間。
struct JarMeter {
    static let log = Logger(subsystem: "org.domyweb.douzhang", category: "jar")
    static let signposter = OSSignposter(logger: log)

    private var since: TimeInterval = 0
    private var last: TimeInterval = 0
    private var frames = 0
    private var steps = 0
    private var longestGap = 0.0
    private var work = 0.0
    private var longestWork = 0.0

    /// 畫完一格叫一次：now 是這一格的時刻，spent 是算加畫花的秒數。
    mutating func frame(now: TimeInterval, steps taken: Int, work spent: TimeInterval) {
        if last > 0 {
            longestGap = max(longestGap, now - last)
        }
        last = now
        if since == 0 {
            since = now
        }
        frames += 1
        steps += taken
        work += spent
        longestWork = max(longestWork, spent)
        guard now - since >= 1 else { return }
        report(seconds: now - since)
        self = JarMeter()
    }

    private func report(seconds: TimeInterval) {
        let numbers: [CVarArg] = [
            Double(frames) / seconds,
            longestGap * Params.msPerSecond,
            Double(steps) / Double(frames),
            work / Double(frames) * Params.msPerSecond,
            longestWork * Params.msPerSecond,
        ]
        let line = String(format: JarMeter.pattern, arguments: numbers)
        JarMeter.log.debug("番茄堆 \(line, privacy: .public)")
    }

    private static let pattern = "每秒 %.1f 格，最長間隔 %.1f 毫秒，每格 %.2f 步，算加畫平均 %.2f、最長 %.2f 毫秒"
}
