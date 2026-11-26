import AVFoundation

/// 白噪音：計時中循環播雨或柴火，響了就停。鎖屏、切到別的 app 也繼續播。
/// 播的時候把音訊模式切成「靜音鍵撥到靜音也播、在背景也播」，停了切回音效那組。
/// 什麼時候該播由 Gates.ambience 算；殼在狀態變了之後叫 apply，這裡自己分辨要不要動。
/// 分辨、讀檔、切模式、播與停整套排到音訊那條佇列照順序做：切模式會卡零點幾秒，
/// 在主執行緒上等的話，開始與結束一顆的那一下畫面會凍住。裡面的東西都只在那條佇列上碰。
final class Soundscape: @unchecked Sendable {
    private(set) var player: AVAudioPlayer?
    private(set) var playing = AmbienceKind.off

    private let lock = NSLock()
    /// 叫到第幾次了。叫的人與佇列都會看，所以要鎖
    private var latest = 0

    /// 播這一種（循環）、換音量，或停掉。叫了就回，不等它做完；同一條佇列，所以順序不會亂。
    /// 預覽時快速點過好幾種，前面那幾種排到時已經不要了就略過，不然要一種一種讀完才輪到最後那種。
    /// 停不略過：到點一定停得下來。
    func apply(_ kind: AmbienceKind, level: AmbienceLevel) {
        let volume = Float(Params.ambienceVolume(level))
        let turn = lock.withLock { () -> Int in
            latest += 1
            return latest
        }
        AudioMode.queue.async {
            let isLatest = self.lock.withLock { turn == self.latest }
            if kind == .off || isLatest {
                self.change(to: kind, volume: volume)
            }
        }
    }

    /// 同一種還在播就只換音量，不從頭播。播不出來不往外丟：沒有聲音照樣計時。
    private func change(to kind: AmbienceKind, volume: Float) {
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
        player?.volume = volume
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
