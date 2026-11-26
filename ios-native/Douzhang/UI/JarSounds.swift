import AVFoundation
import UIKit
import VeggieKit

/// 音訊模式全 app 只有一份，統一在這裡切。
/// 音效那組：靜音鍵撥到靜音就不響、不在背景播。白噪音那組：靜音也播、在背景也播。
/// 兩組都跟別的 app 的聲音混在一起：使用者自己在放的音樂不會被番茄帳打斷。
enum AudioMode {
    /// 切模式、讀音檔、播、停都排在這一條，照叫的順序一件一件做，主執行緒不等。
    /// 切模式要等系統的音訊服務回話，一次可以卡零點幾秒：結束一顆回待機時，
    /// 「結束這顆？」那張半頁就是凍在這裡，收下去的動畫整段沒了（QC-0008 第 61 筆）。
    /// 只排一條是為了順序：先切到白噪音那組才播；先停白噪音才切回音效那組。
    static let queue = DispatchQueue(label: "org.domyweb.douzhang.audio", qos: .userInitiated)

    /// 白噪音正在播：這時音效不准把模式切回去。只在上面那條佇列讀寫
    static var ambiencePlaying = false

    /// 只在佇列上叫。
    static func useEffects() {
        if ambiencePlaying {
            return
        }
        apply(.ambient)
    }

    /// 只在佇列上叫。
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

/// 五個音效檔的播放器。讀檔與播都只在音訊那條佇列上，所以可以跨執行緒拿著。
private final class SoundBank: @unchecked Sendable {
    private var pop: AVAudioPlayer?
    private var hits: [AVAudioPlayer] = []
    private let hitNames = ["hit260", "hit290", "hit320", "hit350"]

    func load() {
        pop = SoundBank.player("pop")
        hits = hitNames.compactMap { SoundBank.player($0) }
    }

    private static func player(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }

    func playPop() {
        play(pop, volume: 1)
    }

    func playHit(volume: Float) {
        play(hits.randomElement(), volume: volume)
    }

    private func play(_ player: AVAudioPlayer?, volume: Float) {
        guard let player else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}

/// 番茄堆的入堆音、碰撞音與觸覺。聲音開關關著時只剩觸覺；觸覺回饋關著就不震。
/// 整個 app 只有一組：每次回待機重讀五個檔、重建觸覺產生器，那一下主執行緒都在等。
@MainActor
final class JarSounds {
    static let shared = JarSounds()

    private let bank = SoundBank()
    /// 音檔讀好了。還沒好就只有觸覺，不排隊補放：晚到的「啵」比沒有更怪
    private var loaded = false
    private let landTap = UIImpactFeedbackGenerator(style: .rigid)
    private let hitTap = UIImpactFeedbackGenerator(style: .light)

    private init() {
        // 系統的音訊服務重開過，模式與播放器全部作廢：重切、重讀一次
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: nil
        ) { [bank] _ in
            AudioMode.queue.async {
                AudioMode.useEffects()
                bank.load()
            }
        }
        AudioMode.queue.async { [bank] in
            AudioMode.useEffects()
            bank.load()
            Task { @MainActor in
                self.loaded = true
            }
        }
    }

    /// 番茄要開始動了：先叫醒觸覺，第一下才不會晚到。
    func ready() {
        if VeggieHaptics.isEnabled {
            landTap.prepare()
            hitTap.prepare()
        }
    }

    /// 落地那一刻的視聽觸：同一事件同一幀。
    func land(sound: Bool) {
        if sound, loaded {
            AudioMode.queue.async { [bank] in bank.playPop() }
        }
        tap(landTap)
    }

    /// 碰撞：一次「嗒」＋輕觸覺；音量與震動都隨衝擊。
    /// 佇列前面在切模式的話輪到時可能晚了，晚太多就不嗒；落地的「啵」只有一次，晚了也播。
    func hit(sound: Bool, impact: Double) {
        if sound, loaded {
            let volume = Float(min(Tokens.Sound.hitVolMax, impact / Tokens.Sound.hitVolDiv))
            let asked = ProcessInfo.processInfo.systemUptime
            AudioMode.queue.async { [bank] in
                if !JarBeat.isLate(asked: asked, now: ProcessInfo.processInfo.systemUptime) {
                    bank.playHit(volume: volume)
                }
            }
        }
        tap(hitTap, strength: JarBeat.strength(impact))
    }

    /// 震的那一刻才看開關：改了立刻生效。
    private func tap(_ generator: UIImpactFeedbackGenerator, strength: Double = 1) {
        if VeggieHaptics.isEnabled {
            generator.impactOccurred(intensity: strength)
        }
    }
}
