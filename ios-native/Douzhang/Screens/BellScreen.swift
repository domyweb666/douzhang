import SwiftUI

/// 響了之後的慶祝畫面：一張收據在中間，番茄壓在上緣；寫一句是選填，不寫可以直接收下。
/// 收下、再做 15／30 分固定在底部；收據太長時只有收據那塊捲動。
struct BellScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = ""
    /// 開著筆記本那張半頁
    @State private var noteOpen = false
    /// 打了字、還沒存的那次：停手 draftSaveMs 才存
    @State private var draftWait: Task<Void, Never>?

    var body: some View {
        if let run = model.state.focusRun {
            // 「響了 N 分鐘前」一分鐘才變一次：從響的那一刻起每整分鐘重算，不跟著每一拍的時鐘
            let everyMinute = PeriodicTimelineSchedule(
                from: Store.date(run.endAt),
                by: Params.secondsPerMinute
            )
            TimelineView(everyMinute) { context in
                // 整分鐘那格可能比那一刻早一點點畫；打字等別的原因重畫時排程時刻是舊的：取晚的那個
                let shown = context.date.timeIntervalSince1970 * Params.msPerSecond
                let late = Machine.lateMinutes(
                    model.state,
                    run: run,
                    now: max(shown, TimeText.nowMillis())
                )
                VStack(spacing: .zero) {
                    receipt(run, late: late)
                    buttons(run, late: late)
                }
            }
            .sheet(isPresented: $noteOpen) { NotebookSheet(text: $draft) }
            .onAppear { draft = run.draft }
            // 切走或殺掉再開，打到一半的字還在：停手就存，切走、離開這頁時等不及的那次當場存
            .onChange(of: draft) { _, next in saveLater(next) }
            .onChange(of: scenePhase) { _, next in
                if next != .active {
                    saveNow()
                }
            }
            .onDisappear(perform: saveNow)
        }
    }

    private func saveLater(_ text: String) {
        draftWait?.cancel()
        draftWait = nil
        // 跟存著的一樣（剛打開帶回舊的那句、刪回原樣）：不用再寫一次
        guard text != model.state.focusRun?.draft else { return }
        draftWait = Task {
            try? await Task.sleep(for: .milliseconds(Params.draftSaveMs))
            guard !Task.isCancelled else { return }
            draftWait = nil
            model.setDraft(text)
        }
    }

    /// 還在等的那次當場存；沒有在等就什麼都不寫。
    private func saveNow() {
        guard let waiting = draftWait else { return }
        waiting.cancel()
        draftWait = nil
        model.setDraft(draft)
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
                // 收下帶著字走，收完這顆就沒了：等著的那次不用再存
                draftWait?.cancel()
                draftWait = nil
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
            // 再做一下不帶字，用的是存著的那句：先把等著的存進去
            saveNow()
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
