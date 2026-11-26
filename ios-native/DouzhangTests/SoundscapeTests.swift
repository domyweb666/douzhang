import AVFoundation
@testable import Douzhang
import XCTest

/// 白噪音排到音訊那條佇列：叫的人不等，順序不亂。真的有沒有聲音、卡不卡要手機。
final class SoundscapeTests: XCTestCase {
    /// 佇列上排著的都做完。
    private func drain() {
        AudioMode.queue.sync {}
    }

    override func tearDown() {
        drain()
        super.tearDown()
    }

    func test佇列還在忙的時候叫了就回不等它() {
        let gate = DispatchSemaphore(value: 0)
        AudioMode.queue.async { gate.wait() }
        let sound = Soundscape()
        // 會等的話這一行就回不來
        sound.apply(.rain, level: .low)
        XCTAssertEqual(sound.playing, .off)
        gate.signal()
        drain()
        XCTAssertEqual(sound.playing, .rain)
        sound.apply(.off, level: .low)
    }

    func test連著開換停最後停在最後一個() {
        let sound = Soundscape()
        sound.apply(.rain, level: .low)
        sound.apply(.fire, level: .high)
        drain()
        XCTAssertEqual(sound.playing, .fire)
        AudioMode.queue.sync { XCTAssertTrue(AudioMode.ambiencePlaying) }
        sound.apply(.off, level: .high)
        sound.apply(.off, level: .high)
        drain()
        XCTAssertEqual(sound.playing, .off)
        AudioMode.queue.sync { XCTAssertFalse(AudioMode.ambiencePlaying) }
    }

    func test同一種換音量不重來() {
        let sound = Soundscape()
        sound.apply(.rain, level: .low)
        drain()
        let first = sound.player
        XCTAssertEqual(first?.volume ?? 0, Float(Params.ambienceVolume(.low)), accuracy: 1e-6)
        sound.apply(.rain, level: .high)
        drain()
        XCTAssertEqual(sound.playing, .rain)
        // 還是同一個播放器，只是音量變了
        XCTAssertNotNil(first)
        XCTAssertTrue(sound.player === first)
        XCTAssertEqual(first?.volume ?? 0, Float(Params.ambienceVolume(.high)), accuracy: 1e-6)
        sound.apply(.off, level: .low)
        drain()
        XCTAssertEqual(sound.playing, .off)
    }

    func test播的時候模式已經是白噪音那組停了已經切回音效那組() {
        let session = AVAudioSession.sharedInstance()
        let sound = Soundscape()
        sound.apply(.rain, level: .low)
        drain()
        XCTAssertEqual(session.category, .playback)
        // 白噪音在播，音效那組不准把模式切回去
        AudioMode.queue.sync { AudioMode.useEffects() }
        XCTAssertEqual(session.category, .playback)
        sound.apply(.off, level: .low)
        drain()
        XCTAssertNil(sound.player)
        XCTAssertEqual(session.category, .ambient)
    }

    func test快速點過好幾種只做最後那種() {
        let sound = Soundscape()
        let gate = DispatchSemaphore(value: 0)
        AudioMode.queue.async { gate.wait() }
        sound.apply(.rain, level: .low)
        let peek = Peek()
        AudioMode.queue.async { peek.kind = sound.playing }
        sound.apply(.fire, level: .low)
        gate.signal()
        drain()
        // 排到雨的時候已經改要柴火了：雨沒開過
        XCTAssertEqual(peek.kind, .off)
        XCTAssertEqual(sound.playing, .fire)
        sound.apply(.off, level: .low)
    }

    func test到點停就算後面馬上又叫也真的停過() {
        let sound = Soundscape()
        sound.apply(.rain, level: .low)
        drain()
        let gate = DispatchSemaphore(value: 0)
        AudioMode.queue.async { gate.wait() }
        sound.apply(.off, level: .low)
        let peek = Peek()
        AudioMode.queue.async { peek.kind = sound.playing }
        sound.apply(.rain, level: .low)
        gate.signal()
        drain()
        XCTAssertEqual(peek.kind, .off)
        XCTAssertEqual(sound.playing, .rain)
        sound.apply(.off, level: .low)
    }

    /// 佇列做到一半時看一眼在播什麼。
    private final class Peek: @unchecked Sendable {
        var kind: AmbienceKind?
    }
}
