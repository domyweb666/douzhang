import AVFoundation
import UIKit

/// 音訊模式全 app 只有一份，統一在這裡切。
/// 音效那組：靜音鍵撥到靜音就不響、不在背景播。白噪音那組：靜音也播、在背景也播。
/// 兩組都跟別的 app 的聲音混在一起：使用者自己在放的音樂不會被番茄帳打斷。
enum AudioMode {
    /// 白噪音正在播：這時音效不准把模式切回去
    static var ambiencePlaying = false

    static func useEffects() {
        if ambiencePlaying {
            return
        }
        apply(.ambient)
    }

    static func useBackground() {
        apply(.playback)
    }

    private static func apply(_ category: AVAudioSession.Category) {
        let session = AVAudioSession.sharedInstance()
        // 切不成（別的 app 佔著）就照原本的模式播，不擋計時
        try? session.setCategory(category, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}

/// 番茄堆的入堆音、碰撞音與觸覺。聲音開關關著時只剩觸覺。
@MainActor
final class JarSounds {
    private var pop: AVAudioPlayer?
    private var hits: [AVAudioPlayer] = []
    private let landTap = UIImpactFeedbackGenerator(style: .rigid)
    private let hitTap = UIImpactFeedbackGenerator(style: .light)
    private let hitNames = ["hit260", "hit290", "hit320", "hit350"]

    init() {
        AudioMode.useEffects()
        pop = JarSounds.player("pop")
        hits = hitNames.compactMap { JarSounds.player($0) }
    }

    private static func player(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }

    private func play(_ player: AVAudioPlayer?, volume: Float = 1) {
        guard let player else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    /// 落地那一刻的視聽觸：同一事件同一幀。
    func land(sound: Bool) {
        if sound {
            play(pop)
        }
        landTap.impactOccurred()
    }

    /// 碰撞：一次「嗒」＋輕觸覺；音量隨衝擊。
    func hit(sound: Bool, impact: Double) {
        if sound {
            let volume = min(Tokens.Sound.hitVolMax, impact / Tokens.Sound.hitVolDiv)
            play(hits.randomElement(), volume: Float(volume))
        }
        hitTap.impactOccurred()
    }
}
