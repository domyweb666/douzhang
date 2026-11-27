import SwiftUI

/// 番茄串：一天收下的番茄排成一串小圓點，50 分的那顆比較長；作廢是空心圈，不靠顏色。
struct PodRow: View {
    var items: [PodItem]

    var body: some View {
        let dot = Tokens.Shape.podDot
        FlowRow(spacing: Tokens.Layout.tight) {
            ForEach(Array(items.enumerated()), id: \.offset) { entry in
                let item = entry.element
                if item.kind == .voided {
                    Circle()
                        .stroke(Tokens.Tomato.podShade, lineWidth: Tokens.Shape.hairline)
                        .frame(width: dot, height: dot)
                        .accessibilityLabel(Words.voidA11y)
                } else {
                    Capsule()
                        .fill(Tokens.Tomato.pod)
                        .frame(
                            width: item.units > 1 ? dot * 2 + Tokens.Layout.tight : dot,
                            height: dot
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 一天的收據：時間、在做什麼、那句、作廢行、沒留話標記，由早到晚。
/// 收下的那一列可以點，開半頁改在做什麼與那句；作廢那列不能改。
struct DaySheet: View {
    var dayKey: String
    var day: DayRecord?

    @Environment(\.dismiss) private var dismiss
    @State private var editing: ReceiptRow?

    var body: some View {
        let rows = day.map(Receipt.rows) ?? []
        SheetCard(title: Words.dayReceiptTitle(dayKey)) {
            if let day {
                PodRow(items: Receipt.podItems(day))
            }
            VStack(alignment: .leading, spacing: .zero) {
                if rows.isEmpty {
                    line(time: nil, text: Words.leafDay, muted: true)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { entry in
                    row(entry.element)
                }
            }
            .padding(.top, Tokens.Layout.group)
            BigButton(label: Words.confirm, second: true) { dismiss() }
                .padding(.top, Tokens.Layout.section)
        }
        .sheet(item: $editing) { BeanWordsSheet(row: $0) }
    }

    @ViewBuilder
    private func row(_ row: ReceiptRow) -> some View {
        if row.kind == .bean {
            // 主字是在做什麼與標記，專注筆記退到下面一行；只有筆記的那列筆記就是主字
            let head = beanLine(row)
            // 整列是按鈕，右邊的箭頭跟設定頁標籤那列同一個樣子：看得出點得開
            Button { editing = row } label: {
                HStack(spacing: Tokens.Layout.group) {
                    line(
                        time: row.time,
                        text: head.isEmpty ? row.clue : head,
                        sub: head.isEmpty ? "" : row.clue,
                        muted: row.doing.isEmpty && row.clue.isEmpty
                    )
                    Image(systemName: "chevron.right")
                        .font(Tokens.Fonts.caption.weight(.semibold))
                        .foregroundStyle(Tokens.Colors.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(FadeStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint(Words.editWordsHint)
        } else {
            let text = Words.voidLine(
                minute: row.minute,
                reason: row.reason,
                text: row.text,
                doing: row.doing
            )
            line(time: row.time, text: text, muted: true)
        }
    }

    /// 在做什麼（沒寫、也沒筆記就是「沒留話」），後面帶雙番茄、延長、記過幾筆的標記。
    /// 筆記不放這一行：筆記可以很長，接在後面的標記會被「…」切掉。都沒有回空字串。
    private func beanLine(_ row: ReceiptRow) -> String {
        var marks: [String] = []
        if row.isDouble {
            marks.append(Words.doublePea)
        }
        if row.flow > 0 {
            marks.append(Words.flowMark(row.flow))
        }
        if row.notes > 0 || row.pings > 0 {
            marks.append(Words.jotMark(notes: row.notes, pings: row.pings))
        }
        let note = row.clue.isEmpty ? Words.noNoteMark : ""
        let text = row.doing.isEmpty ? note : row.doing
        return ([text] + marks).filter { !$0.isEmpty }.joined(separator: "　")
    }

    private func line(time: Millis?, text: String, sub: String = "", muted: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Layout.group) {
            if let time {
                Text(TimeText.hhmm(time))
                    .font(Tokens.Fonts.sub)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
            // 專注筆記可以很長：每樣最多露 listLines 行，結尾「…」，全文點進去看
            VStack(alignment: .leading, spacing: Tokens.Layout.tight) {
                Text(text)
                    .font(Tokens.Fonts.body)
                    .foregroundStyle(
                        muted ? Tokens.Colors.textSecondary : Tokens.Colors.textPrimary
                    )
                if !sub.isEmpty {
                    Text(sub)
                        .font(Tokens.Fonts.sub)
                        .foregroundStyle(Tokens.Colors.textSecondary)
                }
            }
            .lineLimit(Tokens.Notebook.listLines)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Tokens.Layout.item)
    }
}

/// 改收下的那一顆：在做什麼（一行）、專注筆記（點了開整頁的筆記本，跟鈴響頁同一本）。
/// 按「好」才存；下滑關掉就是不改。筆記本只寫回這裡的草稿，存不存照舊由「好」決定。
struct BeanWordsSheet: View {
    var row: ReceiptRow

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var doing: String
    @State private var clue: String
    @State private var notebookOpen = false

    /// 字在一開始就放好，不在 onAppear 才填：填的那一下會觸發超過上限就切掉，
    /// 兩台合過、超過上限的那句沒動也會被切短。
    init(row: ReceiptRow) {
        self.row = row
        _doing = State(initialValue: row.doing)
        _clue = State(initialValue: row.clue)
    }

    var body: some View {
        SheetCard(title: Words.editWordsTitle) {
            label(Words.doing)
            LineInput(
                placeholder: Words.doingPlaceholder,
                text: $doing,
                maxLength: Params.doingMaxChars
            )
            // 不另外寫欄名：沒寫時橫線上就是「專注筆記」與筆，跟鈴響頁一樣，再寫一次會重複
            NoteLines(draft: clue) { notebookOpen = true }
                .padding(.top, Tokens.Layout.section)
            BigButton(label: Words.confirm) {
                model.editWords(id: row.id, doing: doing, clue: clue)
                dismiss()
            }
            .padding(.top, Tokens.Layout.group)
        }
        .sheet(isPresented: $notebookOpen) { NotebookSheet(text: $clue) }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Fonts.sub)
            .foregroundStyle(Tokens.Colors.textSecondary)
            .padding(.bottom, Tokens.Layout.tight)
    }
}
