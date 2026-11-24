import os
import UIKit

/// 一次滑動的幀數：畫了幾格、最長一格多久、掉了幾格。
struct FrameTally: Equatable {
    private(set) var frames = 0
    private(set) var longest = 0.0
    private(set) var dropped = 0

    /// 記一格：跟上一格隔多久（秒）、那一格原本該多久。
    mutating func add(gap: Double, expected: Double) {
        guard gap > 0, expected > 0 else { return }
        frames += 1
        longest = max(longest, gap)
        dropped += max(0, Int((gap / expected).rounded()) - 1)
    }
}

/// 卡格計：左右滑的期間數格子，停下來寫一行 log。只在開發版與 TestFlight 開，畫面上什麼都沒有。
/// 不指定格率：指定了會把螢幕一起拉快，量到的就不是使用者看到的。
@MainActor
final class FrameMeter: NSObject {
    private static let log = Logger(subsystem: "org.domyweb.douzhang", category: "pager")

    private var link: CADisplayLink?
    private var tally = FrameTally()
    private var lastAt = 0.0
    private var lastTarget = 0.0

    private static var isOn: Bool {
        #if DEBUG
            return true
        #else
            // TestFlight 的收據檔名跟 App Store 的不一樣
            return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    func start() {
        guard FrameMeter.isOn, link == nil else { return }
        tally = FrameTally()
        lastAt = 0
        let next = CADisplayLink(target: self, selector: #selector(count))
        next.add(to: .main, forMode: .common)
        link = next
    }

    func stop() {
        guard let running = link else { return }
        running.invalidate()
        link = nil
        let frames = tally.frames
        let dropped = tally.dropped
        let longest = Int((tally.longest * Params.msPerSecond).rounded())
        FrameMeter.log.notice("滑動 \(frames) 格，最長 \(longest) 毫秒，掉 \(dropped) 格")
    }

    @objc private func count(_ running: CADisplayLink) {
        if lastAt > 0 {
            tally.add(gap: running.timestamp - lastAt, expected: lastTarget - lastAt)
        }
        lastAt = running.timestamp
        lastTarget = running.targetTimestamp
    }
}
