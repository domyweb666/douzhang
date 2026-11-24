import Foundation

// MARK: 正在做什麼

extension Machine {
    /// 改「正在做什麼」：下一顆的一定改；這顆還沒收下的話，連這顆的一起改。空的就是清掉。
    /// 頭尾空白去掉、最多 doingMaxChars 字。
    static func setDoing(_ state: AppState, text: String) -> AppState {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let line = String(trimmed.prefix(Params.doingMaxChars))
        var next = state
        next.doing = line
        if var run = state.focusRun {
            run.doing = line
            next.current = .focus(run)
        }
        return next
    }
}
