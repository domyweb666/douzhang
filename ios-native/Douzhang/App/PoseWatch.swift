import CoreMotion
import UIKit

/// 畫面准不准轉向由這裡說了算：平常只有直向，聚焦模式開著時只有橫向。
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _: UIApplication,
        supportedInterfaceOrientationsFor _: UIWindow?
    ) -> UIInterfaceOrientationMask {
        ScreenTurn.allowed
    }
}

/// 鎖方向。鎖不了（裝置不支援）就照原方向畫，不擋計時。
@MainActor
enum ScreenTurn {
    private(set) static var allowed = UIInterfaceOrientationMask.portrait

    static func lock(_ mask: UIInterfaceOrientationMask) {
        if mask == allowed { return }
        allowed = mask
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

/// 計時中看手機是直拿還是橫放（聚焦模式用）。靠加速度計看重力落在哪一軸，開著直向鎖定也有效。
/// 判斷在 Core/Posture.swift；這裡只管開關感測器。沒有加速度計（模擬器）就只剩按鈕。
@MainActor
final class PoseWatch {
    private let motion = CMMotionManager()
    private var watching: String?
    private var tracker = PoseTracker()

    /// 開始看這一顆。同一顆已經在看就不重來（重來會把「已經橫放」忘掉）。
    func start(for key: String, onChange: @escaping (Pose) -> Void) {
        if watching == key { return }
        stop()
        watching = key
        tracker = PoseTracker()
        guard motion.isAccelerometerAvailable else { return }
        motion.accelerometerUpdateInterval = Params.Zen.sampleMs / Params.msPerSecond
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let reading = data?.acceleration else { return }
            MainActor.assumeIsolated {
                self.feed(reading, onChange: onChange)
            }
        }
    }

    private func feed(_ reading: CMAcceleration, onChange: (Pose) -> Void) {
        let sample = Acceleration(x: reading.x, y: reading.y, z: reading.z)
        let step = Posture.track(tracker, sample: sample, now: TimeText.nowMillis())
        tracker = step.tracker
        if let changed = step.changed { onChange(changed) }
    }

    func stop() {
        if watching == nil { return }
        motion.stopAccelerometerUpdates()
        watching = nil
    }
}
