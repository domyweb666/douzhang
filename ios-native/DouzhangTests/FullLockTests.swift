@testable import Douzhang
import FamilyControls
import XCTest

/// 擋 app 與聚焦的鎖：規則（純函式），還有買了沒變了的時候殼怎麼動。
/// 擋板看的是殼叫了系統做什麼，真的擋不擋得住要真機。
@MainActor
final class FullLockTests: XCTestCase {
    private let base = Moment.local(2026, 11, 1, 9)

    private func focusing(at start: Millis, shield: Bool = true) -> AppState {
        var state = Store.blank()
        state.settings.shield = shield
        return Machine.start(state, now: start)
    }

    private func move(_ state: AppState, _ status: FullStatus, after: Double = 1) -> ShieldMove {
        Gates.shield(state, now: base + after * Moment.minute, status: status)
    }

    // MARK: 擋板的規則

    func test計時中買了才蓋確定沒買就拆不知道不動() {
        let state = focusing(at: base)
        XCTAssertEqual(move(state, .owned), .cover)
        XCTAssertEqual(move(state, .notOwned), .clear)
        XCTAssertEqual(move(state, .unknown), .leave)
    }

    func test不該擋的時候不管買了沒都拆() {
        let idle = Store.blank()
        let off = focusing(at: base, shield: false)
        let running = focusing(at: base)
        for status in [FullStatus.unknown, .owned, .notOwned] {
            XCTAssertEqual(move(idle, status), .clear)
            XCTAssertEqual(move(off, status), .clear)
            // 響了：不知道買了沒也要解開，不能一直擋著
            XCTAssertEqual(move(running, status, after: 25), .clear)
        }
    }

    // MARK: 設定頁列不列、聚焦鈕出不出現

    func test沒確定買了擋app那一區與聚焦鈕都不列() {
        for feature in [FullFeature.shield, .zen] {
            XCTAssertTrue(FullRule.allows(feature, status: .owned))
            XCTAssertFalse(FullRule.allows(feature, status: .notOwned))
            XCTAssertFalse(FullRule.allows(feature, status: .unknown))
        }
    }

    // MARK: 殼

    func test冷啟動計時中不動擋板問到買了才蓋退款拆買回來又蓋() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let state = focusing(at: TimeText.nowMillis())
        let shell = try await AppShell.open(stage, state)
        defer { shell.close() }
        let model = shell.model
        XCTAssertEqual(model.phase, .focus)
        XCTAssertEqual(model.shield.applied, .unknown)
        model.setFull(.owned)
        XCTAssertEqual(model.shield.applied, .blocked)
        model.setFull(.notOwned)
        XCTAssertEqual(model.shield.applied, .clear)
        // 只停功能：開關留著，買回來照樣蓋上
        XCTAssertTrue(model.state.settings.shield)
        model.setFull(.owned)
        XCTAssertEqual(model.shield.applied, .blocked)
        model.setFull(.notOwned)
    }

    func test冷啟動問到沒買就拆() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, focusing(at: TimeText.nowMillis()))
        defer { shell.close() }
        XCTAssertEqual(shell.model.shield.applied, .unknown)
        shell.model.setFull(.notOwned)
        XCTAssertEqual(shell.model.shield.applied, .clear)
    }

    func test冷啟動沒在計時不知道買了沒也先解開() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, Store.blank())
        defer { shell.close() }
        XCTAssertEqual(shell.model.shield.applied, .clear)
    }

    func test退款不忘記選過要擋的app() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, focusing(at: TimeText.nowMillis()))
        defer { shell.close() }
        let model = shell.model
        model.setFull(.owned)
        model.shield.saveSelection(FamilyActivitySelection())
        defer { model.shield.forget() }
        model.setFull(.notOwned)
        XCTAssertNotNil(UserDefaults.standard.data(forKey: "appShield.selection"))
    }

    func test正在聚焦退款就回直向買回來不自己轉橫() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let state = focusing(at: TimeText.nowMillis(), shield: false)
        let shell = try await AppShell.open(stage, state)
        defer { shell.close() }
        let model = shell.model
        model.setFull(.owned)
        model.enterZen()
        XCTAssertTrue(model.zenOn)
        XCTAssertEqual(ScreenTurn.allowed, .landscape)
        model.setFull(.notOwned)
        XCTAssertFalse(model.zenOn)
        XCTAssertEqual(ScreenTurn.allowed, .portrait)
        XCTAssertEqual(model.phase, .focus)
        model.setFull(.owned)
        XCTAssertFalse(model.zenOn)
        XCTAssertEqual(ScreenTurn.allowed, .portrait)
    }

    func test沒買與不知道進不了聚焦() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let state = focusing(at: TimeText.nowMillis(), shield: false)
        let shell = try await AppShell.open(stage, state)
        defer { shell.close() }
        for status in [FullStatus.unknown, .notOwned] {
            shell.model.setFull(status)
            shell.model.enterZen()
            XCTAssertFalse(shell.model.zenOn)
            XCTAssertNil(shell.model.zenFor)
        }
    }

    func test清除所有資料不動買了沒() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, Store.blank())
        defer { shell.close() }
        shell.model.setFull(.owned)
        shell.model.wipeAll()
        XCTAssertEqual(shell.model.fullStatus, .owned)
    }
}
