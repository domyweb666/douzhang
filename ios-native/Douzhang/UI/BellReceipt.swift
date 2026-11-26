import SwiftUI

/// 鈴響頁那張收據：番茄壓在上緣、一半在外面。由上到下：標題、這顆做了什麼與今天那排小番茄、
/// 寫給自己的那句、計時中記的念頭與有人找；下緣是撕下來的鋸齒。
struct BellReceipt: View {
    var state: AppState
    var run: FocusRun
    var type: TagType
    /// 響了幾分鐘才回來；不算久是 0
    var late: Int
    var draft: String
    var onNote: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: Tokens.Layout.section) {
                title
                lines
                VStack(alignment: .leading, spacing: Tokens.Layout.group) {
                    NoteLines(draft: draft, action: onNote)
                    Jotted(run: run)
                }
            }
            .padding(.horizontal, Tokens.Layout.section)
            .padding(.top, Tokens.Bell.tomato / 2 + Tokens.Layout.section)
            .padding(.bottom, Tokens.Layout.section + Tokens.Bell.tooth)
            .background(Tokens.Colors.card, in: ReceiptPaper())
            .padding(.top, Tokens.Bell.tomato / 2)
            RipeTomato(color: type.color)
        }
        .frame(maxWidth: Tokens.Bell.receiptWidth)
    }

    private var title: some View {
        VStack(spacing: .zero) {
            Text(Words.ripeTitle)
                .font(Tokens.Fonts.title)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if late > 0 {
                HomeCaption(text: Words.rangAgo(late))
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 有寫在做什麼：第一列是那句與長度，第二列是標籤與起訖。沒寫：標籤升到第一列，起訖靠右排在長度下面。
    private var lines: some View {
        let hasDoing = !run.doing.isEmpty
        return VStack(spacing: Tokens.Layout.group) {
            ReceiptLine(
                label: hasDoing ? run.doing : type.name,
                value: Words.lenWithFlow(run.len, flow: run.flowMin)
            )
            ReceiptLine(
                label: hasDoing ? type.name : "",
                value: Words.clockRange(run.startedAt, run.endAt)
            )
            TodayRow(state: state, run: run, type: type)
        }
        .padding(.vertical, Tokens.Layout.rowPadV)
        .overlay(alignment: .top) { dash }
        .overlay(alignment: .bottom) { dash }
    }

    private var dash: some View {
        DashLine()
            .stroke(Tokens.Colors.fieldBorder, style: Tokens.Bell.dash)
            .frame(height: Tokens.Shape.hairline)
    }
}

/// 熟了的那顆：畫面出現的那一瞬間彈出來一下，只這一次，不擋操作。減少動態時只淡入。
struct RipeTomato: View {
    var color: TomatoColor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        TomatoView(color: color, size: Tokens.Bell.tomato)
            .scaleEffect(shown || reduceMotion ? 1 : Tokens.Motion.celebrateFrom)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(Tokens.Motion.celebrate) { shown = true }
            }
    }
}

/// 收據的一列：左邊名字（可以沒有）、右邊值。字放到很大時一排放不下，改成上下兩行。
struct ReceiptLine: View {
    var label: String
    var value: String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stacked = VStackLayout(alignment: .leading, spacing: Tokens.Layout.tight)
        let wide = HStackLayout(alignment: .firstTextBaseline, spacing: Tokens.Layout.group)
        let arrange = typeSize.isAccessibilitySize ? AnyLayout(stacked) : AnyLayout(wide)
        arrange {
            if !label.isEmpty {
                Text(label)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 只准因為寬度放不下而縮。收據比畫面矮時，外層排版有一輪會給這列比一行還矮的高度，
            // 名字不理它、值卻跟著縮，同一列就一大一小（QC-0008 #60 第二張收據）
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Tokens.Bell.shrink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: label.isEmpty ? .infinity : nil, alignment: .trailing)
                .layoutPriority(1)
        }
        .font(Tokens.Fonts.body)
        .foregroundStyle(Tokens.Colors.textPrimary)
        .accessibilityElement(children: .combine)
    }
}

/// 收據的「今天」那列：開始那天已經收下的，加上這一顆排在最後，每顆一樣大。看得到累積，不跟昨天比。
/// 番茄排到第二行起，「今天」下面寫出總數；太多顆時只畫最後幾顆。讀屏念的數字照實。
/// 有開始番茄的日子夠多之後，下面多一行「你平常 4 到 6 顆」；斷了一陣子回來的第一天不放。
struct TodayRow: View {
    var state: AppState
    var run: FocusRun
    var type: TagType

    var body: some View {
        let kept = state.days[Machine.dayKey(of: run)]?.beans ?? []
        let total = Words.todayTotal(kept.count + 1)
        VStack(alignment: .leading, spacing: Tokens.Layout.tight) {
            // 只有「今天」時對齊那一行番茄的中線；下面有總數時兩邊都從上面排起
            HStack(alignment: total == nil ? .center : .top, spacing: Tokens.Layout.group) {
                VStack(alignment: .leading, spacing: Tokens.Layout.tight) {
                    Text(Words.today)
                    if let total {
                        Text(total).monospacedDigit()
                    }
                }
                .font(Tokens.Fonts.body)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .fixedSize()
                tomatoes(kept.stableSorted { $0.keptAt }.suffix(Params.celebrateTomatoes - 1))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Words.todayKept(kept.count + 1))
            // 比較小：她自己平常的範圍。只給範圍，不寫今天多了還是少了
            if let usual = Insights.usualShown(state, todayKey: Machine.dayKey(of: run)) {
                Text(Words.usual(usual))
                    .font(Tokens.Fonts.caption)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
        }
    }

    private func tomatoes(_ shown: ArraySlice<Bean>) -> some View {
        FlowRow(spacing: Tokens.Layout.tight) {
            ForEach(Array(shown.enumerated()), id: \.offset) { item in
                TomatoView(
                    color: Machine.typeOf(state, item.element.typeId).color,
                    size: Tokens.Shape.celebrateDot
                )
            }
            TomatoView(color: type.color, size: Tokens.Shape.celebrateDot)
        }
    }
}

/// 寫給自己的那句，寫在橫線上：沒寫是提示與一支筆，寫過就是那句；點了開筆記本。至少兩條線。
/// 不在這一頁打字：鍵盤會蓋住收據。
struct NoteLines: View {
    var draft: String
    var action: () -> Void

    @ScaledMetric(relativeTo: .body) private var pitch = Tokens.Bell.line

    private var isBlank: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Tokens.Layout.item) {
                RuledText(
                    text: isBlank ? Words.noteTitle : draft,
                    color: isBlank ? Tokens.Colors.textSecondary : Tokens.Colors.textPrimary,
                    pitch: pitch
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                // 裡面是 UIKit 的字：點擊交給整塊按鈕，不讓它擋在前面
                .allowsHitTesting(false)
                if isBlank {
                    LineIconView(kind: .pencil, size: Tokens.Home.sideIcon)
                        .foregroundStyle(Tokens.Colors.textSecondary)
                        .padding(.bottom, Tokens.Layout.tight)
                        .frame(height: pitch, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, minHeight: pitch * 2, alignment: .topLeading)
            .background {
                RuledLines(pitch: pitch)
                    .stroke(Tokens.Colors.separator, lineWidth: Tokens.Shape.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(FadeStyle())
        .accessibilityLabel(Words.noteTitle)
        .accessibilityValue(isBlank ? "" : draft)
    }
}

/// 計時中記的念頭與有人找：寫給自己那句的橫線下面，一筆一列，跟那句分得開（QC-0008 第 57 筆，多米選 C）。
/// 左邊淡紫圓裡一個線條圖示（念頭是燈泡、有人找是對話框），右邊上行種類、下行那句。
/// 清單空就什麼都不畫，不寫「沒有紀錄」。沒寫字的不列空行，合成一列「有人找 2 次」。
struct Jotted: View {
    var run: FocusRun

    var body: some View {
        let rows = Self.rows(.notes, run.notes) + Self.rows(.pings, run.pings)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Layout.item) {
                ForEach(Array(rows.enumerated()), id: \.offset) { row in
                    BellJotRow(jot: row.element)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 有寫字的一筆一列；沒寫字的那幾筆合成最後一列「有人找 2 次」（只有種類那行）。
    static func rows(_ kind: JotKind, _ all: [String]) -> [BellJot] {
        let label = kind == .notes ? Words.noteThought : Words.notePing
        let written = all.filter { !$0.isEmpty }.map { BellJot(kind: kind, label: label, text: $0) }
        let blank = all.count - written.count
        let merged = BellJot(kind: kind, label: Words.jotTimes(kind, blank), text: "")
        return blank > 0 ? written + [merged] : written
    }
}

/// 收據上的一列：哪一種、種類那行寫什麼、那句（合成的那列沒有）。
struct BellJot: Equatable {
    var kind: JotKind
    var label: String
    var text: String
}

/// 一筆：圖示圓、種類、那句。讀屏一列念成一句「冒出念頭，很好」。
struct BellJotRow: View {
    var jot: BellJot

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Layout.group) {
            LineIconView(kind: jot.kind == .notes ? .bulb : .bubble, size: Tokens.Bell.jotIcon)
                .foregroundStyle(Tokens.Colors.accentText)
                .frame(width: Tokens.Bell.jotBadge, height: Tokens.Bell.jotBadge)
                .background(Tokens.Colors.soft, in: Circle())
            VStack(alignment: .leading, spacing: .zero) {
                Text(jot.label)
                    .font(Tokens.Fonts.chip)
                    .foregroundStyle(Tokens.Colors.accentText)
                if !jot.text.isEmpty {
                    Text(jot.text)
                        .font(Tokens.Fonts.body)
                        .foregroundStyle(Tokens.Colors.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(jot.text.isEmpty ? jot.label : "\(jot.label)，\(jot.text)")
    }
}
