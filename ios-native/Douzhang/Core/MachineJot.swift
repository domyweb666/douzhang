import Foundation

// MARK: 計時中記一筆

extension Machine {
    /// 計時中記一筆。倒數不停，只是往這顆裡推一行。
    /// 字是選填的：點了種類就算一筆，沒寫字的存成空字串（分析照樣算一次）。
    static func jot(_ state: AppState, kind: JotKind, text: String = "") -> AppState {
        guard var run = state.focusRun else { return state }
        push(&run, kind: kind, text: text)
        return focusing(state, run)
    }

    /// 剛記的那一筆改種類，或補上那一行：拿掉 from 最後那一筆，在 into 補一筆。
    /// 所以點了「冒出念頭」又改點「有人找」只會有一筆。from 那邊沒有東西可拿就什麼都不變。
    static func amendJot(
        _ state: AppState,
        from: JotKind,
        into: JotKind,
        text: String
    ) -> AppState {
        guard var run = state.focusRun else { return state }
        switch from {
        case .notes:
            guard !run.notes.isEmpty else { return state }
            run.notes.removeLast()
        case .pings:
            guard !run.pings.isEmpty else { return state }
            run.pings.removeLast()
        }
        push(&run, kind: into, text: text)
        return focusing(state, run)
    }

    private static func push(_ run: inout FocusRun, kind: JotKind, text: String) {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .notes: run.notes.append(line)
        case .pings: run.pings.append(line)
        }
    }

    private static func focusing(_ state: AppState, _ run: FocusRun) -> AppState {
        var next = state
        next.current = .focus(run)
        return next
    }
}
