import SwiftUI
import UIKit

/// iCloud 停下來問的框：換了 Apple 帳號、雲端的不見了、換機還原，問「放進去／先不要」。
/// 它自己冒出來，不是誰按的：畫面上有別的框或半頁時系統會吞掉後來的，
/// 計時中與鈴響也不打斷，所以等到畫面空著才問。沒答之前同步停著，不合也不傳。
struct CloudAsk: ViewModifier {
    @Environment(AppModel.self) private var model
    @State private var isShown = false
    /// 框收掉的那一下 question 已經是 nil：標題另外記著才不會先變空白
    @State private var asked = CloudQuestion.account

    func body(content: Content) -> some View {
        content
            // 看問過幾次，不看問什麼：答完馬上又問同一個，中間的 nil 畫面看不到
            .task(id: model.cloud.question == nil ? 0 : model.cloud.asks) { await follow() }
            .alert(Words.cloudAsk(asked), isPresented: $isShown) {
                Button(Words.cloudAdopt) { model.cloud.adopt() }
                Button(Words.cloudDecline, role: .cancel) { model.cloud.decline() }
            }
    }

    private func follow() async {
        guard let question = model.cloud.question else {
            // 答完了，或退款、關掉同步，不用答了
            isShown = false
            return
        }
        while !isFree {
            try? await Task.sleep(for: .milliseconds(Params.tickMs))
            if Task.isCancelled {
                return
            }
        }
        asked = question
        isShown = true
    }

    private var isFree: Bool {
        switch model.phase {
        case .focus, .bell: false
        case .idle, .rest: model.loaded && !ScreenCover.isOn
        }
    }
}

/// 畫面上現在有沒有蓋著別的：系統的框、半頁、分享選單。
@MainActor
enum ScreenCover {
    static var isOn: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .contains { $0.presentedViewController != nil }
    }
}
