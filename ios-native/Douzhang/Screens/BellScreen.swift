import SwiftUI

/// 響了之後的慶祝畫面：一張收據在中間，番茄壓在上緣；寫一句是選填，不寫可以直接收下。
/// 收下、再做 15／30 分固定在底部；收據太長時只有收據那塊捲動。
struct BellScreen: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    /// 開著筆記本那張半頁
    @State private var noteOpen = false

    var body: some View {
        if let run = model.state.focusRun {
            let late = lateMinutes(run)
            VStack(spacing: .zero) {
                receipt(run, late: late)
                buttons(run, late: late)
            }
            .sheet(isPresented: $noteOpen) { NotebookSheet(text: $draft) }
            .onAppear { draft = run.draft }
            // 每個字都存：切走或殺掉再開，打到一半的字還在
            .onChange(of: draft) { _, next in model.setDraft(next) }
        }
    }

    /// 很久才回來（超過這顆的休息長度）：多一行「響了 N 分鐘前」
    /// 智能調節的休息跟著今天的累計走，跟收下時用同一個算法；其他模式照舊用番茄長度。
    private func lateMinutes(_ run: FocusRun) -> Int {
        let ago = model.now - run.endAt
        let isSmart = model.state.settings.restMode == .smart
        let rest = isSmart
            ? Machine.restPlan(model.state, run: run).minutes
            : Store.restMinutes(run.len)
        let limit = Double(rest) * Params.msPerMinute
        return ago >= limit ? Int(ago / Params.msPerMinute) : 0
    }

    /// 放得下就上下置中，放不下才捲。
    private func receipt(_ run: FocusRun, late: Int) -> some View {
        GeometryReader { proxy in
            ScrollView {
                BellReceipt(
                    state: model.state,
                    run: run,
                    type: Machine.typeOf(model.state, run.typeId),
                    late: late,
                    draft: draft
                ) {
                    noteOpen = true
                }
                .padding(.vertical, Tokens.Layout.group)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// 一顆只准延一次，延過就不畫「再做」那兩顆。
    private func buttons(_ run: FocusRun, late: Int) -> some View {
        VStack(spacing: Tokens.Layout.group) {
            BigButton(label: late > 0 ? Words.keepThis : Words.keepAndRest) {
                model.keep(text: draft)
            }
            if !run.flowed {
                HStack(spacing: Tokens.Layout.group) {
                    ForEach(Params.flowMinutes, id: \.self) { minutes in
                        flowButton(minutes)
                    }
                }
            }
        }
        .minimumScaleFactor(Tokens.Bell.shrink)
        .frame(width: Tokens.Bell.buttonWidth)
        .padding(.top, Tokens.Layout.group)
        .padding(.bottom, Tokens.Layout.footerTop)
    }

    private func flowButton(_ minutes: Int) -> some View {
        Button {
            model.flow(minutes: minutes)
        } label: {
            Text(Words.flowMore(minutes))
                .font(Tokens.Fonts.chip)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, Tokens.Layout.tight)
                .frame(maxWidth: .infinity, minHeight: Tokens.Shape.tapMin)
                .background(Tokens.Colors.fillButton, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
    }
}
