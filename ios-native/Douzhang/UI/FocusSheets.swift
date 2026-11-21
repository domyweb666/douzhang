import SwiftUI

/// 記一筆：上面分段選念頭或有人找（預設念頭），寫一行按記下（或鍵盤的完成），倒數不停。
struct NoteSheet: View {
    var onJot: (JotKind, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind = JotKind.notes
    @State private var text = ""

    private let kinds = [
        SegmentOption(value: JotKind.notes, label: Words.noteThought),
        SegmentOption(value: JotKind.pings, label: Words.notePing),
    ]

    private var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SheetCard(title: Words.quickNote, sub: Words.noteSub) {
            Segmented(options: kinds, value: kind) { kind = $0 }
            LineInput(
                placeholder: kind == .pings ? Words.noteTitlePing : Words.noteTitleThought,
                text: $text,
                maxLength: Params.jotMaxChars,
                onSubmit: submit
            )
            .padding(.top, Tokens.Space.m)
            BigButton(label: Words.jotDown, disabled: isBlank, action: submit)
                .padding(.top, Tokens.Space.m)
        }
    }

    private func submit() {
        if !isBlank {
            onJot(kind, text)
        }
        dismiss()
    }
}

/// 結束這顆？三選一：提早做完（還沒標過才有）、作廢（不到五分鐘叫停下來）、繼續做。
/// early 由打開半頁那一刻決定，呼叫端固定住。
struct EndSheet: View {
    var isDone: Bool
    var early: Bool
    var onDoneEarly: () -> Void
    var onVoid: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetCard(title: Words.endTitle, sub: early ? Words.endSubEarly : Words.endSub) {
            if !isDone {
                SheetRow(title: Words.doneEarly, sub: Words.doneEarlySub) {
                    dismiss()
                    onDoneEarly()
                }
            }
            SheetRow(title: early ? Words.stopNow : Words.voidThis, action: onVoid)
            BigButton(label: Words.keepGoing, second: true) { dismiss() }
                .padding(.top, Tokens.Space.l)
        }
    }
}

/// 「⋯」半頁裡點了哪一列。
enum MorePick {
    case note, sound, zen, end
}

/// 計時中右上「⋯」開的半頁：記一筆、背景音、聚焦模式、結束這顆。點一列就交給呼叫端開下一張。
struct MoreSheet: View {
    /// 這顆記過幾筆
    var noteCount: Int
    /// 現在選的背景音（關、雨、柴火）
    var soundValue: String
    var onPick: (MorePick) -> Void

    var body: some View {
        SheetCard(title: Words.moreTitle) {
            SheetRow(title: Words.quickNote, value: noteCount > 0 ? String(noteCount) : nil) {
                onPick(.note)
            }
            SheetRow(title: Words.ambienceTitle, value: soundValue) { onPick(.sound) }
            SheetRow(title: Words.zenEnter) { onPick(.zen) }
            SheetRow(title: Words.endThis) { onPick(.end) }
        }
    }
}

/// 作廢原因：四個分段＋一行選填 → 記一筆。
struct VoidSheet: View {
    var onVoid: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: String?
    @State private var text = ""

    private let reasons = Words.voidReasons.map { SegmentOption(value: $0, label: $0) }

    var body: some View {
        SheetCard(title: Words.voidThis, sub: Words.voidSub) {
            Segmented(options: reasons, value: reason) { reason = $0 }
            LineInput(
                placeholder: Words.voidTextPlaceholder,
                text: $text,
                maxLength: Params.voidTextMaxChars
            )
            .padding(.top, Tokens.Space.m)
            HStack(spacing: Tokens.Space.m) {
                BigButton(label: Words.keepGoing, second: true) { dismiss() }
                BigButton(label: Words.quickNote) {
                    dismiss()
                    onVoid(reason ?? "", text)
                }
            }
            .padding(.top, Tokens.Space.m)
        }
    }
}
