import SwiftUI

/// 記一筆：兩個分段鈕，不預選；點哪個就記哪一種，點完才出現選填的那一行。倒數不停。
/// 點另一個是改種類，不會記成兩筆。按「好」、下滑關掉都算記下了。
struct NoteSheet: View {
    /// 點種類那一下：先記一筆沒寫字的
    var onJot: (JotKind) -> Void
    /// 剛記的那一筆改種類（前兩個不一樣），或補上那一行（前兩個一樣）
    var onAmend: (JotKind, JotKind, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: JotKind?
    @State private var text = ""
    @State private var written = false
    @FocusState private var focused: Bool

    private let kinds = [
        SegmentOption(value: JotKind.notes, label: Words.noteThought),
        SegmentOption(value: JotKind.pings, label: Words.notePing),
    ]

    private var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SheetCard(title: Words.quickNote) {
            Segmented(options: kinds, value: kind, onChange: pick)
            if let kind {
                // 不自己拿游標：大多數時候點完種類就走，鍵盤不用跳出來
                let ask = kind == .pings ? Words.noteTitlePing : Words.noteTitleThought
                TextField(ask, text: $text)
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit(close)
                    .onChange(of: text) { _, next in
                        if next.count > Params.jotMaxChars {
                            text = String(next.prefix(Params.jotMaxChars))
                        }
                    }
                    .modifier(FieldChrome(focused: focused))
                    .padding(.top, Tokens.Space.m)
                BigButton(
                    label: isBlank ? Words.confirm : Words.jotDown,
                    second: isBlank,
                    action: close
                )
                .padding(.top, Tokens.Space.m)
            }
        }
        // 下滑關掉、響了自動收起來時，打到一半的那一行也跟著記下
        .onDisappear(perform: write)
    }

    private func pick(_ next: JotKind) {
        if let kind {
            if kind != next {
                onAmend(kind, next, "")
            }
        } else {
            onJot(next)
        }
        kind = next
    }

    /// 把那一行補到剛記的那一筆上。只寫一次。
    private func write() {
        guard let kind, !isBlank, !written else { return }
        written = true
        onAmend(kind, kind, text)
    }

    private func close() {
        write()
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
        SheetCard(title: Words.endTitle) {
            if !isDone {
                SheetRow(title: Words.doneEarly) {
                    dismiss()
                    onDoneEarly()
                }
            }
            SheetRow(title: early ? Words.stopNow : Words.voidThis, action: onVoid)
            BigButton(label: Words.keepGoing, second: true) { dismiss() }
                .padding(.top, Tokens.Layout.section)
        }
    }
}

/// 作廢原因：四個分段（不預選，可以不選）＋一行選填 → 作廢這顆。
struct VoidSheet: View {
    var onVoid: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: String?
    @State private var text = ""

    private let reasons = Words.voidReasons.map { SegmentOption(value: $0, label: $0) }

    var body: some View {
        SheetCard(title: Words.voidThis) {
            Segmented(options: reasons, value: reason) { reason = $0 }
            LineInput(
                placeholder: Words.voidTextPlaceholder,
                text: $text,
                maxLength: Params.voidTextMaxChars
            )
            .padding(.top, Tokens.Layout.group)
            HStack(spacing: Tokens.Layout.group) {
                BigButton(label: Words.keepGoing, second: true) { dismiss() }
                BigButton(label: Words.voidThis) {
                    dismiss()
                    onVoid(reason ?? "", text)
                }
            }
            .padding(.top, Tokens.Layout.group)
        }
    }
}
