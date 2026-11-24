@testable import Douzhang
import XCTest

/// 三頁停在哪：一開始滑就是空的，停下來才有值；滑動中換頁不算停。
@MainActor
final class PagerMotionTests: XCTestCase {
    private let longEnough = Duration.seconds(Tokens.Motion.pageSettle * 3)

    func test一開始停在主畫面() {
        let pager = PagerMotion()
        XCTAssertEqual(pager.rest, .home)
    }

    func test開始滑就沒有停在哪停下來才換成新的那頁() {
        let pager = PagerMotion()
        pager.scroll(isMoving: true, page: .home)
        XCTAssertNil(pager.rest)
        // 手指還在動，過半就換頁了
        pager.pageChanged(to: .rack)
        XCTAssertNil(pager.rest)
        pager.scroll(isMoving: true, page: .rack)
        XCTAssertNil(pager.rest)
        pager.scroll(isMoving: false, page: .rack)
        XCTAssertEqual(pager.rest, .rack)
    }

    func test滑一半又滑回來還是停在原本那頁() {
        let pager = PagerMotion()
        pager.scroll(isMoving: true, page: .home)
        pager.scroll(isMoving: false, page: .home)
        XCTAssertEqual(pager.rest, .home)
    }

    func test沒有捲動通知的換頁等一下才算停穩() async throws {
        let pager = PagerMotion()
        pager.pageChanged(to: .settings)
        XCTAssertNil(pager.rest)
        try await Task.sleep(for: longEnough)
        XCTAssertEqual(pager.rest, .settings)
    }

    func test點分頁列先換頁才開始捲動以捲動停下為準() async throws {
        let pager = PagerMotion()
        pager.pageChanged(to: .rack)
        pager.scroll(isMoving: true, page: .rack)
        try await Task.sleep(for: longEnough)
        XCTAssertNil(pager.rest)
        pager.scroll(isMoving: false, page: .rack)
        XCTAssertEqual(pager.rest, .rack)
    }

    func test停下來之後才收到同一頁的換頁不會再凍一次() {
        let pager = PagerMotion()
        pager.scroll(isMoving: true, page: .home)
        pager.scroll(isMoving: false, page: .rack)
        pager.pageChanged(to: .rack)
        XCTAssertEqual(pager.rest, .rack)
    }
}
