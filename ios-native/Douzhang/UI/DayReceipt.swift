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
struct DaySheet: View {
    var dayKey: String
    var day: DayRecord?

    @Environment(\.dismiss) private var dismiss

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
    }

    @ViewBuilder
    private func row(_ row: ReceiptRow) -> some View {
        if row.kind == .bean {
            // 有寫在做什麼就是主字，那句退到下面一行；沒寫的照舊只有那句
            let hasDoing = !row.doing.isEmpty
            line(
                time: row.time,
                text: beanLine(row),
                sub: hasDoing ? row.clue : "",
                muted: !hasDoing && row.clue.isEmpty
            )
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

    /// 在做什麼（沒寫就是那句，再沒有就是「沒留話」），後面帶雙番茄、延長、記過幾筆的標記。
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
        let note = row.clue.isEmpty ? Words.noNoteMark : row.clue
        let text = row.doing.isEmpty ? note : row.doing
        return ([text] + marks).joined(separator: "　")
    }

    private func line(time: Millis?, text: String, sub: String = "", muted: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Layout.group) {
            if let time {
                Text(TimeText.hhmm(time))
                    .font(Tokens.Fonts.sub)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Tokens.Layout.item)
    }
}
