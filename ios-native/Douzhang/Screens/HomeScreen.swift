import SwiftUI

/// 主畫面現在開著哪張半頁。end 帶著打開那一刻固定的判斷：那時開始不到五分鐘嗎。
enum HomeSheet: Identifiable, Hashable {
    case more, note, end(early: Bool), voidReason, tag, sound

    var id: Self {
        self
    }
}

/// 主畫面。三態：待機、計時中、休息（鈴響是另一頁 BellScreen）。
/// 待機：標籤膠囊、大時間、背景音、開始鈕、番茄堆。
/// 計時中與休息是「番茄就是時鐘」：左上標籤、右上「⋯」，中間一圈進度環圍著那顆番茄，時間在環下面。
/// 計時中點畫面空白處就記一筆；其他動作收在「⋯」裡。
struct HomeScreen: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: HomeSheet?

    var body: some View {
        content
            .sheet(item: $sheet) { which in sheetBody(which) }
            // 換態（響了、作廢、休息到點）時，開著的半頁跟著收掉
            .onChange(of: model.phase) { _, _ in sheet = nil }
            // 從聚焦模式按「記一筆」「結束這顆」回來：直接開那張，開了就清掉，下一顆不會自己跳出來
            .onChange(of: model.homeSheetRequest, initial: true) { _, request in
                guard let request else { return }
                sheet = request
                model.homeSheetRequest = nil
            }
    }

    @ViewBuilder private var content: some View {
        let state = model.state
        if let run = state.focusRun {
            VStack(spacing: .zero) {
                topBar(Machine.typeOf(state, run.typeId), more: true)
                FocusRing(run: run, type: Machine.typeOf(state, run.typeId), now: model.now) {
                    sheet = .note
                }
                bottomRoom
            }
        } else if let run = state.restRun, model.phase == .rest {
            VStack(spacing: .zero) {
                topBar(Machine.typeOf(state, run.typeId), more: false)
                RestRing(run: run, now: model.now)
                BigButton(label: Words.backFromRest) { model.backFromRest() }
                bottomRoom
            }
        } else {
            let type = Machine.typeOf(state, state.settings.typeId)
            HomeIdle(type: type, onTag: { sheet = .tag }, onSound: { sheet = .sound })
                .background { jar }
        }
    }

    /// 番茄在整個畫面後面掉、滾、堆在最下面（頁面左右有內距，這層往外撐到螢幕邊），停在分頁列上面。
    /// 只在待機掛上：剛收的那顆休息完回到待機才從上面掉進去。空白處的點擊會穿過前景落到這裡。
    private var jar: some View {
        @Bindable var model = model
        let state = model.state
        let today = state.days[model.todayKey]?.beans ?? []
        let beans = today.stableSorted { $0.keptAt }.map { bean in
            JarBean(len: bean.len, color: Machine.typeOf(state, bean.typeId).color)
        }
        return JarView(
            beans: beans,
            sound: state.settings.sound,
            tilt: state.settings.tilt,
            seen: $model.jarSeen
        )
        .padding(.horizontal, -Tokens.Space.screen)
        .padding(.bottom, Tokens.Shape.tabClearance - Tokens.Space.card)
    }

    /// 計時中與休息最上面那條：左邊標籤，右邊「⋯」（只有計時中有；休息時沒有半頁）。
    private func topBar(_ type: TagType, more: Bool) -> some View {
        HStack {
            TagChip(type: type)
            Spacer()
            if more {
                RoundButton(label: Words.more, a11yLabel: Words.moreA11y) { sheet = .more }
            }
        }
        .padding(.top, Tokens.Space.m)
    }

    private var bottomRoom: some View {
        Spacer().frame(height: Tokens.Shape.tabClearance + Tokens.Space.m)
    }

    @ViewBuilder
    private func sheetBody(_ which: HomeSheet) -> some View {
        switch which {
        case .more: moreSheet
        case .note: noteSheet
        case let .end(early): endSheet(early: early)
        case .voidReason: VoidSheet { reason, text in model.voidBean(reason: reason, text: text) }
        case .tag: TagPickSheet()
        case .sound: SoundSheet()
        }
    }

    private var noteSheet: some View {
        NoteSheet(
            onJot: { model.jot($0) },
            onAmend: { from, into, text in model.amendJot(from: from, into: into, text: text) }
        )
    }

    private var moreSheet: some View {
        let run = model.state.focusRun
        let count = (run?.notes.count ?? 0) + (run?.pings.count ?? 0)
        return MoreSheet(
            noteCount: count,
            soundValue: Words.ambienceKind(model.state.settings.ambience)
        ) { pick in
            switch pick {
            case .note: sheet = .note
            case .sound: sheet = .sound
            case .zen:
                sheet = nil
                model.enterZen()
            case .end: openEnd()
            }
        }
    }

    /// 打開「結束這顆」那一刻固定判斷：4:59 看到「停下來」，按下去就照停下來辦，不會變成記一筆作廢。
    private func openEnd() {
        guard let run = model.state.focusRun else { return }
        sheet = .end(early: Machine.stoppedEarly(run, now: TimeText.nowMillis()))
    }

    private func endSheet(early: Bool) -> some View {
        EndSheet(
            isDone: model.state.focusRun?.done ?? false,
            early: early,
            onDoneEarly: { model.markDone() },
            onVoid: {
                if early {
                    sheet = nil
                    model.stopEarly()
                } else {
                    sheet = .voidReason
                }
            }
        )
    }
}
