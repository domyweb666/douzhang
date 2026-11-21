import SwiftUI

/// 響了之後的慶祝畫面：先恭喜、再收下，寫一句是選填，不寫可以直接收下。
/// 由上到下：這顆熟了的番茄、標題、今天收了幾顆那排、選填的一句、計時中記的念頭與有人找、收下、再做 15／30 分。
struct BellScreen: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @State private var noteOpen = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        if let run = model.state.focusRun {
            let type = Machine.typeOf(model.state, run.typeId)
            let late = lateMinutes(run)
            VStack(spacing: .zero) {
                ScrollView {
                    VStack(spacing: .zero) {
                        header(type, late: late)
                        TodayRow(state: model.state, run: run, type: type)
                        noteField
                        Jotted(run: run)
                    }
                    .padding(.bottom, Tokens.Space.l)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                BigButton(label: late > 0 ? Words.keepThis : Words.keepAndRest) {
                    model.keep(text: draft)
                }
                flowRow(run)
            }
            .padding(.bottom, Tokens.Space.m)
            .onAppear {
                draft = run.draft
                noteOpen = !run.draft.isEmpty
            }
            // 每個字都存：切走或殺掉再開，打到一半的字還在
            .onChange(of: draft) { _, next in model.setDraft(next) }
        }
    }

    /// 很久才回來（超過這顆的休息長度）：多一行「響了 N 分鐘前。收下後直接回待機。」
    private func lateMinutes(_ run: FocusRun) -> Int {
        let ago = model.now - run.endAt
        let limit = Double(Store.restMinutes(run.len)) * Params.msPerMinute
        return ago >= limit ? Int(ago / Params.msPerMinute) : 0
    }

    private func header(_ type: TagType, late: Int) -> some View {
        VStack(spacing: Tokens.Space.xs) {
            TomatoView(color: type.color, size: Tokens.Shape.celebrateTomato)
            Text(Words.ripeTitle)
                .font(Tokens.Fonts.title)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            HomeCaption(text: Words.tagLabel(type))
            if late > 0 { HomeCaption(text: Words.rangAgo(late)) }
        }
        .padding(.top, Tokens.Space.l)
    }

    /// 選填的一句：先是一列可點的字，點了才變成輸入框（不然一進來鍵盤就蓋住番茄）。打過字的回來直接是輸入框。
    @ViewBuilder private var noteField: some View {
        if noteOpen {
            TextField(Words.notePlaceholder, text: $draft, axis: .vertical)
                .focused($noteFocused)
                .modifier(FieldChrome(focused: noteFocused))
                .onChange(of: draft) { _, next in
                    if next.count > Params.noteMaxChars {
                        draft = String(next.prefix(Params.noteMaxChars))
                    }
                }
                .padding(.top, Tokens.Space.m)
        } else {
            TextButton(label: Words.noteOptional, tone: .secondary) {
                noteOpen = true
                noteFocused = true
            }
            .padding(.top, Tokens.Space.m)
        }
    }

    /// 「再做 15 分」「再做 30 分」並排的文字鈕；一顆只准延一次，延過就不畫。
    @ViewBuilder
    private func flowRow(_ run: FocusRun) -> some View {
        if !run.flowed {
            HStack {
                ForEach(Params.flowMinutes, id: \.self) { minutes in
                    TextButton(label: Words.flowMore(minutes)) { model.flow(minutes: minutes) }
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, Tokens.Space.xs)
        }
    }
}

/// 「今天收了 N 顆」：開始那天已經收下的，加上這一顆排在最後、比較大。看得到累積，不跟昨天比。
/// 太多顆時只畫最後幾顆，數字照實寫。
struct TodayRow: View {
    var state: AppState
    var run: FocusRun
    var type: TagType

    var body: some View {
        let kept = state.days[Store.dayKey(run.startedAt)]?.beans ?? []
        let shown = kept.stableSorted { $0.keptAt }.suffix(Params.celebrateTomatoes - 1)
        VStack(spacing: Tokens.Space.s) {
            Text(Words.todayKept(kept.count + 1))
                .font(Tokens.Fonts.sub)
                .foregroundStyle(Tokens.Colors.textSecondary)
            FlowRow(spacing: Tokens.Space.xs, centered: true) {
                ForEach(Array(shown.enumerated()), id: \.offset) { item in
                    TomatoView(
                        color: Machine.typeOf(state, item.element.typeId).color,
                        size: Tokens.Shape.celebrateDot
                    )
                }
                TomatoView(color: type.color, size: Tokens.Shape.celebrateDotNew)
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(Tokens.Space.card)
        .background(Tokens.Colors.card, in: RoundedRectangle(cornerRadius: Tokens.Shape.radiusCard))
        .padding(.top, Tokens.Space.l)
    }
}

/// 計時中記的念頭與有人找。清單空就什麼都不畫，不寫「沒有紀錄」。
struct Jotted: View {
    var run: FocusRun

    var body: some View {
        let rows = run.notes.map { (Words.noteThought, $0) } + run.pings.map { (Words.notePing, $0) }
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            ForEach(Array(rows.enumerated()), id: \.offset) { row in
                HStack(alignment: .top, spacing: Tokens.Space.m) {
                    Text(row.element.0)
                    Text(row.element.1).frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(Tokens.Fonts.sub)
                .foregroundStyle(Tokens.Colors.textSecondary)
            }
        }
        .padding(.top, rows.isEmpty ? .zero : Tokens.Space.m)
    }
}
