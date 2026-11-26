import SwiftUI

/// 開始鈕的框，從待機那頁往上送到番茄堆，番茄堆再換成自己的座標（同一頁，滑頁也不變）。
struct JarStartKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

/// 量到的開始鈕、分頁列、番茄堆的框，換成番茄堆座標的擋路的東西。
/// 是盒子不是狀態：滑頁時番茄堆在螢幕上的框每一格都在變，存進來不該讓這頁重算。
@MainActor
final class JarPlace {
    /// 開始鈕，已經是番茄堆的座標
    var start: CGRect?
    /// 分頁列與番茄堆在螢幕上的框
    private var tabBar: CGRect?
    private var screen: CGRect?
    /// 分頁列換成番茄堆的座標：最後一次停好時算的
    private var tabInJar: CGRect?

    var obstacles: [JarObstacle] {
        [start, tabInJar].compactMap { frame in frame.map(JarObstacle.init) }
    }

    /// 回分頁列在番茄堆裡的位置有沒有變。
    func setScreen(_ frame: CGRect) -> Bool {
        screen = frame
        return follow()
    }

    func setTabBar(_ frame: CGRect?) -> Bool {
        tabBar = frame
        return follow()
    }

    /// 分頁列不在這一頁裡，只量得到螢幕上的框。番茄堆跟著頁面滑，跟分頁列置中對齊時才是停好在這一頁，
    /// 那時才換算；滑到一半的不算，沿用上次停好的（不看 PagerMotion：iOS 17 滑過一半才知道在滑）。
    private func follow() -> Bool {
        guard let screen, let tabBar,
              abs(screen.midX - tabBar.midX) <= JarTuning.restAlign
        else { return false }
        let next = tabBar.offsetBy(dx: -screen.minX, dy: -screen.minY)
        if next == tabInJar {
            return false
        }
        tabInJar = next
        return true
    }
}

extension JarObstacle {
    init(_ frame: CGRect) {
        self.init(minX: frame.minX, minY: frame.minY, maxX: frame.maxX, maxY: frame.maxY)
    }
}

extension JarScene {
    /// 開始鈕、分頁列換了地方：擋路的東西跟著換，壓在裡面的搬出來，醒來走到躺好。
    func setObstacles(_ next: [JarObstacle]) {
        guard next != world.obstacles else { return }
        world.setObstacles(next)
        // 靜止版不走物理：搬出來的會疊著懸在上面，當場安置好
        if isStill {
            for _ in 0 ..< world.tuning.settleSteps {
                world.step(JarWorld.frame)
            }
            world.landed = []
        }
        wake()
    }
}
