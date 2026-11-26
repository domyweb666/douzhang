import CoreMotion
import Foundation

/// 番茄堆用的加速度計。番茄堆共用這一個 CMMotionManager：每次回待機重建一個要在主執行緒上等。
/// 認手機橫放的 PoseWatch 另外有一個，只在計時中開，跟番茄堆不會同時在。
/// 換頁時新的番茄堆先出現、舊的後消失：誰開的誰才關得掉，舊的不會把新的關掉。
@MainActor
final class JarTilt {
    static let shared = JarTilt()

    private let motion = CMMotionManager()
    private var owner: ObjectIdentifier?
    /// 睡著時看的平滑讀數：換一個番茄堆接上就從頭算
    var calm = JarCalm()

    /// 沒有加速度計（模擬器）就什麼都不做。讀數的單位是 g。
    func start(for scene: JarScene, onReading: @escaping (Double, Double) -> Void) {
        guard motion.isAccelerometerAvailable else { return }
        motion.stopAccelerometerUpdates()
        owner = ObjectIdentifier(scene)
        calm.forget()
        motion.accelerometerUpdateInterval = scene.sensorInterval
        motion.startAccelerometerUpdates(to: .main) { data, _ in
            guard let reading = data?.acceleration else { return }
            MainActor.assumeIsolated {
                onReading(reading.x, reading.y)
            }
        }
    }

    /// 睡著讀慢省電；醒來馬上讀快，醒著的滾動要每秒 60 次的讀數。開著時直接改間隔，不停掉重開。
    func pace(for scene: JarScene) {
        guard owner == ObjectIdentifier(scene) else { return }
        if motion.accelerometerUpdateInterval != scene.sensorInterval {
            motion.accelerometerUpdateInterval = scene.sensorInterval
        }
    }

    func stop(for scene: JarScene) {
        guard owner == ObjectIdentifier(scene) else { return }
        owner = nil
        motion.stopAccelerometerUpdates()
    }
}
