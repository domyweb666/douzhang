@testable import Douzhang
import FamilyControls
import UIKit
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

    /// 上次蓋著、重開、Apple 還沒回就停下來：這支手機不能一直被擋著。
    func test冷啟動計時中不知道買了沒停下來就解開() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, focusing(at: TimeText.nowMillis()))
        defer { shell.close() }
        XCTAssertEqual(shell.model.phase, .focus)
        XCTAssertEqual(shell.model.shield.applied, .unknown)
        shell.model.stopEarly()
        XCTAssertEqual(shell.model.phase, .idle)
        XCTAssertEqual(shell.model.fullStatus, .unknown)
        XCTAssertEqual(shell.model.shield.applied, .clear)
    }

    func test冷啟動那顆已經響了不知道買了沒也解開() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let start = TimeText.nowMillis() - 60 * Moment.minute
        let shell = try await AppShell.open(stage, focusing(at: start))
        defer { shell.close() }
        XCTAssertEqual(shell.model.phase, .bell)
        XCTAssertEqual(shell.model.fullStatus, .unknown)
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
        // 三頁被聚焦整頁換掉時，捲動位置可能寫回 nil
        model.page = nil
        model.setFull(.notOwned)
        XCTAssertEqual(model.page, Page.home)
        XCTAssertFalse(model.zenOn)
        XCTAssertEqual(ScreenTurn.allowed, .portrait)
        XCTAssertEqual(model.phase, .focus)
        model.setFull(.owned)
        XCTAssertFalse(model.zenOn)
        XCTAssertEqual(ScreenTurn.allowed, .portrait)
    }

    func test沒在聚焦退款不會把人拉回主畫面() async throws {
        let stage = CloudStage()
        defer { stage.clean() }
        let state = focusing(at: TimeText.nowMillis(), shield: false)
        let shell = try await AppShell.open(stage, state)
        defer { shell.close() }
        let model = shell.model
        model.setFull(.owned)
        model.enterZen()
        model.stopEarly()
        // 結束了的那顆，記號還留著
        XCTAssertNotNil(model.zenFor)
        XCTAssertFalse(model.zenOn)
        model.page = .settings
        model.setFull(.notOwned)
        XCTAssertEqual(model.page, Page.settings)
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

    func test計時中清除所有資料擋板解開買了沒不動() async throws {
        let host = HostSettings()
        defer { host.restore() }
        let stage = CloudStage()
        defer { stage.clean() }
        let shell = try await AppShell.open(stage, focusing(at: TimeText.nowMillis()))
        defer { shell.close() }
        let model = shell.model
        model.setFull(.owned)
        XCTAssertEqual(model.shield.applied, .blocked)
        host.markHaptics()
        model.wipeAll()
        XCTAssertEqual(model.phase, .idle)
        XCTAssertEqual(model.shield.applied, .clear)
        XCTAssertEqual(model.fullStatus, .owned)
        await host.waitForWipe()
        // 清完照樣是買了的：再開始一顆、開關打開就蓋
        model.commit(focusing(at: TimeText.nowMillis()))
        XCTAssertEqual(model.shield.applied, .blocked)
        model.stopEarly()
        XCTAssertEqual(model.shield.applied, .clear)
    }
}

/// wipeAll 會動測試宿主的外觀、觸覺、選過要擋的 app：先記著，測完放回去。
@MainActor
private struct HostSettings {
    private static let haptics = "haptics"
    private static let names = ["appearance", haptics, "appShield.selection"]

    private let saved: [String: Any]
    private let style: UIUserInterfaceStyle?

    private static var windows: [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
    }

    init() {
        var found: [String: Any] = [:]
        for name in HostSettings.names {
            found[name] = UserDefaults.standard.object(forKey: name)
        }
        saved = found
        style = HostSettings.windows.first?.overrideUserInterfaceStyle
    }

    /// 觸覺的開關晚一拍才清：先放一個值，才看得出清完了沒。
    func markHaptics() {
        UserDefaults.standard.set(true, forKey: HostSettings.haptics)
    }

    func waitForWipe() async {
        await CloudStage.until("觸覺的開關清完") {
            UserDefaults.standard.object(forKey: HostSettings.haptics) == nil
        }
    }

    func restore() {
        for name in HostSettings.names {
            if let value = saved[name] {
                UserDefaults.standard.set(value, forKey: name)
            } else {
                UserDefaults.standard.removeObject(forKey: name)
            }
        }
        if let style {
            for window in HostSettings.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
