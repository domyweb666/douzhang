import SwiftUI

/// 響了之後的慶祝畫面：先恭喜、再收下，寫一句是選填，不寫可以直接收下。
/// 由上到下：這顆熟了的番茄、標題、今天收了幾顆那排、選填的一句、計時中記的念頭與有人找、收下、再做 15／30 分。
struct BellScreen: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    /// 開著筆記本那張半頁
    @State private var noteOpen = false

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
                BigButton(label: late > 0 ? Words.keepThis : Words.keepAndRest) {
                    model.keep(text: draft)
                }
                flowRow(run)
            }
            .padding(.bottom, Tokens.Space.m)
            .sheet(isPresented: $noteOpen) { NotebookSheet(text: $draft) }
            .onAppear { draft = run.draft }
            // 每個字都存：切走或殺掉再開，打到一半的字還在
            .onChange(of: draft) { _, next in model.setDraft(next) }
        }
    }

    /// 很久才回來（超過這顆的休息長度）：多一行「響了 N 分鐘前。收下後直接回待機。」
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

    private func header(_ type: TagType, late: Int) -> some View {
        VStack(spacing: Tokens.Space.xs) {
            RipeTomato(color: type.color)
            Text(Words.ripeTitle)
                .font(Tokens.Fonts.title)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            HomeCaption(text: Words.tagLabel(type))
            if late > 0 {
                HomeCaption(text: Words.rangAgo(late))
            }
        }
        .padding(.top, Tokens.Space.l)
    }

    /// 選填的一句：點了開筆記本，不在這一頁打字（鍵盤會蓋住番茄）。寫過就顯示那句，點了再開。
    @ViewBuilder private var noteField: some View {
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            TextButton(label: Words.noteOptional, tone: .secondary) { noteOpen = true }
                .padding(.top, Tokens.Layout.group)
        } else {
            Button {
                noteOpen = true
            } label: {
                Text(draft)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(FieldChrome(focused: false))
            }
            .buttonStyle(FadeStyle())
            .accessibilityHint(Words.noteTitle)
            .padding(.top, Tokens.Layout.group)
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

/// 熟了的那顆：畫面出現的那一瞬間彈出來一下，只這一次，不擋操作。減少動態時只淡入。
struct RipeTomato: View {
    var color: TomatoColor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        TomatoView(color: color, size: Tokens.Shape.celebrateTomato)
            .scaleEffect(shown || reduceMotion ? 1 : Tokens.Motion.celebrateFrom)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(Tokens.Motion.celebrate) { shown = true }
            }
    }
}

/// 「今天收了 N 顆」：開始那天已經收下的，加上這一顆排在最後、比較大。看得到累積，不跟昨天比。
/// 有開始番茄的日子夠多之後，下面多一行「你平常 4 到 6 顆」；斷了一陣子回來的第一天不放。
/// 太多顆時只畫最後幾顆，數字照實寫。
struct TodayRow: View {
    var state: AppState
    var run: FocusRun
    var type: TagType

    var body: some View {
        let kept = state.days[Machine.dayKey(of: run)]?.beans ?? []
        let shown = kept.stableSorted { $0.keptAt }.suffix(Params.celebrateTomatoes - 1)
        VStack(spacing: Tokens.Space.s) {
            Text(Words.todayKept(kept.count + 1))
                .font(Tokens.Fonts.sub)
                .foregroundStyle(Tokens.Colors.textSecondary)
            // 第二行比較小：她自己平常的範圍。只給範圍，不寫今天多了還是少了
            if let usual = Insights.usualShown(state, todayKey: Machine.dayKey(of: run)) {
                Text(Words.usual(usual))
                    .font(Tokens.Fonts.caption)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
            FlowRow(spacing: Tokens.Space.xs, centered: true) {
                ForEach(Array(shown.enumerated()), id: \.offset) { item in
                    TomatoView(
                        color: Machine.typeOf(state, item.element.typeId).color,
                        size: Tokens.Shape.celebrateDot
                    )
                }
                TomatoView(color: type.color, size: Tokens.Shape.celebrateDotNew)
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(Tokens.Space.card)
        .background(Tokens.Colors.card, in: cardShape)
        .padding(.top, Tokens.Space.l)
    }
}

private let cardShape = RoundedRectangle(cornerRadius: Tokens.Shape.radiusCard)

/// 計時中記的念頭與有人找。清單空就什麼都不畫，不寫「沒有紀錄」。沒寫字的不列空行。
struct Jotted: View {
    var run: FocusRun

    var body: some View {
        let rows = Self.rows(.notes, run.notes) + Self.rows(.pings, run.pings)
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

    /// 有寫字的一筆一列（左邊種類、右邊那一行）；沒寫字的那幾筆合成最後一列「有人找 2 次」。
    private static func rows(_ kind: JotKind, _ all: [String]) -> [(String, String)] {
        let label = kind == .notes ? Words.noteThought : Words.notePing
        let written = all.filter { !$0.isEmpty }.map { (label, $0) }
        let blank = all.count - written.count
        return blank > 0 ? written + [(Words.jotTimes(kind, blank), "")] : written
    }
}
