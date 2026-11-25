@testable import Douzhang
import XCTest

/// 那一張什麼時候要去動系統、沒有掛著的那張時要不要開。叫系統的在 App/LiveCards，這裡不碰。
final class LiveCardGateTests: XCTestCase {
    func test相同內容不送換了才送() {
        var gate = LiveCardGate()
        XCTAssertEqual(gate.cue(.rang(.red), isBack: false), .changed)
        XCTAssertNil(gate.cue(.rang(.red), isBack: false))
        XCTAssertEqual(gate.cue(.restingOpen, isBack: false), .changed)
        XCTAssertEqual(gate.cue(nil, isBack: false), .changed)
        XCTAssertNil(gate.cue(nil, isBack: false))
    }

    func test剛開機待機也送一次好收掉留著的() {
        var gate = LiveCardGate()
        XCTAssertEqual(gate.cue(nil, isBack: false), .changed)
    }

    /// 不管上次開不開得成，同一個內容都只有回前景才再試；手上沒有那張（nil）就准開。
    func test同一個內容只有回前景才再試() {
        var gate = LiveCardGate()
        XCTAssertEqual(gate.cue(.rang(.red), isBack: false), .changed)
        for _ in 0 ..< 2 {
            XCTAssertNil(gate.cue(.rang(.red), isBack: false))
            XCTAssertEqual(gate.cue(.rang(.red), isBack: true), .back)
            XCTAssertTrue(LiveCard.opens(.back, after: nil))
            XCTAssertNil(gate.cue(.rang(.red), isBack: false))
        }
    }

    func test回前景時內容也換了算換了() {
        var gate = LiveCardGate()
        XCTAssertEqual(gate.cue(.rang(.red), isBack: false), .changed)
        XCTAssertEqual(gate.cue(.restingOpen, isBack: true), .changed)
    }

    func test系統結束的回前景補開使用者滑掉的不補() {
        XCTAssertTrue(LiveCard.opens(.back, after: .ended))
        XCTAssertFalse(LiveCard.opens(.back, after: .dismissed))
    }

    func test滑掉之後換了內容就再開() {
        XCTAssertTrue(LiveCard.opens(.changed, after: .dismissed))
        XCTAssertTrue(LiveCard.opens(.changed, after: .ended))
    }

    func test還掛著的只有進行中與過時() {
        XCTAssertTrue(LiveCard.isUp(.active))
        XCTAssertTrue(LiveCard.isUp(.stale))
        XCTAssertFalse(LiveCard.isUp(.ended))
        XCTAssertFalse(LiveCard.isUp(.dismissed))
        XCTAssertFalse(LiveCard.isUp(nil))
    }

    /// 匯入、清空走的那條路：換上的那份真的送到這裡。
    @MainActor
    func test整份換掉就照換上的那份() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let now = TimeText.nowMillis()
        let shell = try await AppShell.open(stage, Machine.start(Store.blank(), now: now))
        defer { shell.close() }
        XCTAssertNotNil(shell.model.liveCards.gate.face)
        let other = Machine.start(Store.blank(), now: now - Moment.minute, typeId: "t3")
        shell.model.replaceAll(other)
        XCTAssertEqual(shell.model.liveCards.gate.face, LiveCard.face(other, now: now))
        shell.model.replaceAll(Store.blank())
        XCTAssertNil(shell.model.liveCards.gate.face)
    }
}
