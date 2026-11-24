import SwiftUI

/// 「在做什麼」：一行輸入。計時中改的是這一顆，同時留給下一顆；待機改的是下一顆。
/// 按「好」、下滑關掉、響了自動收起來都算數；清空就是不寫。
struct DoingSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    private var saved: String {
        model.state.focusRun?.doing ?? model.state.doing
    }

    var body: some View {
        SheetCard(title: Words.doing) {
            LineInput(
                placeholder: Words.doingPlaceholder,
                text: $text,
                maxLength: Params.doingMaxChars,
                onSubmit: { dismiss() }
            )
            if !text.isEmpty {
                TextButton(label: Words.clearDoing, tone: .secondary, flush: true) { text = "" }
            }
            BigButton(label: Words.confirm) { dismiss() }
                .padding(.top, Tokens.Layout.group)
        }
        .onAppear { text = saved }
        .onDisappear(perform: write)
    }

    private func write() {
        if text != saved {
            model.setDoing(text)
        }
    }
}
