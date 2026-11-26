import SwiftUI

/// 主畫面現在開著哪張半頁。end 帶著打開那一刻固定的判斷：那時開始不到五分鐘嗎。
enum HomeSheet: Identifiable, Hashable {
    case note, end(early: Bool), voidReason, tag, sound, doing

    var id: Self {
        self
    }
}

/// 主畫面。三態：待機、計時中、休息（鈴響是另一頁 BellScreen）。
/// 待機：在做什麼、大時間（點了改長度），下面背景音、開始、標籤，最底下番茄堆。
/// 計時中與休息是「番茄就是時鐘」：左上標籤，中間一圈進度環圍著那顆番茄，時間在環下面。
/// 計時中點畫面空白處就記一筆、點左上膠囊改在做什麼、右上結束；下面一排背景音、記一筆、聚焦。
struct HomeScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Purchases.self) private var shop
    @State private var sheet: HomeSheet?
    /// 開著改長度的整頁刻度尺
    @State private var dialing = false

    var body: some View {
        content
            .sheet(item: $sheet) { which in sheetBody(which) }
            .fullScreenCover(isPresented: $dialing) {
                TimeDialScreen(type: idleType)
            }
            // 換態（響了、作廢、休息到點）時，開著的半頁與刻度尺跟著收掉
            .onChange(of: model.phase) { _, _ in
                sheet = nil
                dialing = false
            }
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
                focusBar(run)
                FocusRing(run: run, type: Machine.typeOf(state, run.typeId), now: model.now) {
                    sheet = .note
                }
                focusActions(run)
            }
        } else if let run = state.restRun, model.phase == .rest {
            VStack(spacing: .zero) {
                TagChip(type: Machine.typeOf(state, run.typeId))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Tokens.Space.m)
                RestRing(run: run, now: model.now)
                BigButton(label: Words.backFromRest) { model.backFromRest() }
                bottomRoom
            }
        } else {
            HomeIdle(
                type: idleType,
                onTag: { sheet = .tag },
                onDoing: { sheet = .doing },
                onTime: { dialing = true },
                onSound: { sheet = .sound }
            )
            .background { jar }
        }
    }

    /// 待機選中的標籤：開始鈕開它、刻度尺改它的長度。
    private var idleType: TagType {
        Machine.typeOf(model.state, model.state.settings.typeId)
    }

    /// 番茄在整個畫面後面掉、滾、堆在最下面，沉到螢幕最底部：
    /// 頁面的內距與安全區都往外撐掉，上到狀態列後面、下到螢幕底，分頁列蓋在番茄上面。
    /// 只在待機掛上：剛收的那顆休息完回到待機才從上面掉進去。空白處的點擊會穿過前景落到這裡。
    private var jar: some View {
        @Bindable var model = model
        let state = model.state
        let beans = model.jarBeans.map { bean in
            JarBean(len: bean.len, color: Machine.typeOf(state, bean.typeId).color)
        }
        return JarView(
            beans: beans,
            sound: state.settings.sound,
            tilt: state.settings.tilt,
            seen: $model.jarSeen
        )
        .padding(.horizontal, -Tokens.Layout.screenMargin)
        .ignoresSafeArea(edges: .vertical)
    }

    /// 計時中最上面那條：左邊膠囊（點了改在做什麼），右邊「結束」。休息時只有膠囊，不能點。
    private func focusBar(_ run: FocusRun) -> some View {
        HStack(spacing: Tokens.Layout.group) {
            TagChip(type: Machine.typeOf(model.state, run.typeId), doing: run.doing) {
                sheet = .doing
            }
            Spacer(minLength: .zero)
            SoftPill(label: Words.endShort, a11yLabel: Words.endThis) { openEnd() }
                // 先給它位子：那句再長也只截斷自己
                .layoutPriority(1)
        }
        // 字再放大，兩顆膠囊一排就放不下了
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.top, Tokens.Layout.pageTop)
    }

    private var bottomRoom: some View {
        Spacer().frame(height: Tokens.Shape.tabClearance + Tokens.Space.m)
    }

    /// 計時中拇指下那一排：背景音、記一筆、聚焦（買了完整版才有，沒有就剩兩顆置中）。
    private func focusActions(_ run: FocusRun) -> some View {
        let ambience = model.state.settings.ambience
        let noted = run.notes.count + run.pings.count
        return HStack(spacing: Tokens.Layout.section) {
            RoundIconButton(
                face: .line(.music),
                label: Words.ambienceChip(ambience),
                a11yLabel: Words.ambienceTitle,
                a11yValue: Words.ambienceKind(ambience),
                action: { sheet = .sound }
            )
            .frame(width: Tokens.Home.roundColumn)
            RoundIconButton(
                face: .line(.pencil),
                label: Words.quickNote,
                a11yLabel: Words.quickNote,
                a11yValue: noted > 0 ? Words.jotCount(noted) : "",
                action: { sheet = .note }
            )
            .frame(width: Tokens.Home.roundColumn)
            if shop.allows(.zen) {
                RoundIconButton(
                    face: .line(.focus),
                    label: Words.zenShort,
                    a11yLabel: Words.zenEnter,
                    action: { model.enterZen() }
                )
                .frame(width: Tokens.Home.roundColumn)
            }
        }
        .padding(.bottom, Tokens.Layout.section)
    }

    @ViewBuilder
    private func sheetBody(_ which: HomeSheet) -> some View {
        switch which {
        case .note: noteSheet
        case let .end(early): endSheet(early: early)
        case .voidReason: VoidSheet { reason, text in model.voidBean(reason: reason, text: text) }
        case .tag: TagPickSheet()
        case .sound: SoundSheet()
        case .doing: DoingSheet()
        }
    }

    private var noteSheet: some View {
        NoteSheet(
            onJot: { model.jot($0) },
            onAmend: { from, into, text in model.amendJot(from: from, into: into, text: text) }
        )
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
