import Observation
import SwiftUI

/// 左右滑的三頁現在停在哪一頁：滑動一開始就是空的，停下來才有值。番茄堆照這個凍結與恢復。
/// 不看 model.page：它在手指還在動、過半的那一刻就換了，
/// 那時開關感測器、起停動畫會卡在手上（2026-11-24 錄影）。
@MainActor
@Observable
final class PagerMotion {
    private(set) var rest: Page? = .home
    /// 分頁列在螢幕上的框：番茄堆拿來擋番茄。分頁列不在任何一頁裡，三頁與它只有這裡接得上
    var tabBar: CGRect?

    @ObservationIgnored private var scrolling = false
    @ObservationIgnored private var settling: Task<Void, Never>?
    @ObservationIgnored private let meter = FrameMeter()

    /// 捲動真的開始、真的停下（iOS 18 起系統會講）。
    func scroll(isMoving: Bool, page: Page?) {
        guard isMoving != scrolling else { return }
        scrolling = isMoving
        if isMoving {
            begin()
        } else {
            finish(at: page)
        }
    }

    /// 換頁了。捲動中的由 scroll 收尾；沒有捲動通知的（iOS 17、不帶動畫直接跳頁）等一下當作停穩。
    func pageChanged(to page: Page?) {
        if scrolling || rest == page {
            return
        }
        begin()
        settling = Task {
            try? await Task.sleep(for: .seconds(Tokens.Motion.pageSettle))
            if !Task.isCancelled {
                finish(at: page)
            }
        }
    }

    private func begin() {
        settling?.cancel()
        settling = nil
        if rest != nil {
            rest = nil
        }
        meter.start()
    }

    /// 還沒有值就當主畫面：三頁一開始停的那頁，番茄堆才不會一直凍著。
    private func finish(at page: Page?) {
        settling = nil
        meter.stop()
        rest = page ?? .home
    }
}

/// 掛在左右滑的 ScrollView 上：把捲動開始、停下、換頁告訴 PagerMotion。
/// 在這裡讀 model.page：換頁時只重算這一層，三頁不跟著重算。
struct PagerWatch: ViewModifier {
    @Environment(AppModel.self) private var model
    var pager: PagerMotion

    func body(content: Content) -> some View {
        watched(content)
            .onChange(of: model.page) { _, page in pager.pageChanged(to: page) }
            // 滑到一半整頁被換掉（響了）：不會再收到停下的通知，卡格計要在這裡停
            .onDisappear { pager.scroll(isMoving: false, page: model.page) }
    }

    @ViewBuilder
    private func watched(_ content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, phase in
                // 手指只是放著（tracking）還沒滑：不算，點番茄才不會被當成滑動
                let isMoving = phase != .idle && phase != .tracking
                pager.scroll(isMoving: isMoving, page: model.page)
            }
        } else {
            content
        }
    }
}
