import UIKit

/// 進背景時跟系統要的一點時間。時間到了系統會叫、做完自己還，兩邊都會走到 end，只算一次。
@MainActor
final class BackgroundGrace {
    private var id = UIBackgroundTaskIdentifier.invalid

    init() {
        id = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard id != .invalid else { return }
        let mine = id
        id = .invalid
        UIApplication.shared.endBackgroundTask(mine)
    }
}
