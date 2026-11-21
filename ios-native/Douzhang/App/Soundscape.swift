import AVFoundation

/// 白噪音：計時中循環播雨或柴火，響了就停。鎖屏、切到別的 app 也繼續播。
/// 播的時候把音訊模式切成「靜音鍵撥到靜音也播、在背景也播」，停了切回音效那組。
/// 什麼時候該播由 Gates.ambience 算；殼在狀態變了之後叫 apply，這裡自己分辨要不要動。
@MainActor
final class Soundscape {
    private var player: AVAudioPlayer?
    private var playing = AmbienceKind.off

    /// 播這一種（循環）、換音量，或停掉。同一種還在播就只換音量，不從頭播。
    /// 播不出來不往外丟：沒有聲音照樣計時。
    func apply(_ kind: AmbienceKind, level: AmbienceLevel) {
        if kind == .off {
            stop()
            return
        }
        if playing != kind {
            stop()
        }
        if player == nil {
            start(kind)
        }
        player?.volume = Float(Params.ambienceVolume(level))
    }

    private func start(_ kind: AmbienceKind) {
        guard let url = Bundle.main.url(forResource: kind.rawValue, withExtension: "m4a"),
              let made = try? AVAudioPlayer(contentsOf: url) else { return }
        AudioMode.ambiencePlaying = true
        AudioMode.useBackground()
        made.numberOfLoops = -1
        made.play()
        player = made
        playing = kind
    }

    private func stop() {
        guard let current = player else { return }
        current.stop()
        player = nil
        playing = .off
        AudioMode.ambiencePlaying = false
        AudioMode.useEffects()
    }
}
