import Foundation

/// 跟著狀態走的兩個開關：白噪音該播哪一種、其他 app 該不該擋。純函式。
/// 殼只在答案變了的時候才去叫系統。
enum Gates {
    /// 現在該播哪一種：這顆還在跑才播設定選的那種；鈴響、休息、待機都不播。
    static func ambience(_ state: AppState, now: Millis) -> AmbienceKind {
        Machine.phaseOf(state, now: now) == .focus ? state.settings.ambience : .off
    }

    /// 現在該不該擋：開關開著、而且這顆還在跑。鈴響、休息、待機都不擋。
    static func shouldShield(_ state: AppState, now: Millis) -> Bool {
        state.settings.shield && Machine.phaseOf(state, now: now) == .focus
    }

    /// 擋板現在要怎麼動。擋 app 是完整版的功能：確定沒買（退款）就解開，開關與選過的 app 都留著，
    /// 買回來照樣蓋上。剛打開還不知道買了沒時不動：上次蓋著的不拆，沒蓋的不蓋
    /// （買過的人計時到一半重開 app，不會因為 Apple 還沒回就擋不住）。
    static func shield(_ state: AppState, now: Millis, status: FullStatus) -> ShieldMove {
        guard shouldShield(state, now: now) else { return .clear }
        if FullRule.allows(.shield, status: status) {
            return .cover
        }
        return status == .unknown ? .leave : .clear
    }
}

enum ShieldMove {
    case cover, clear
    /// 系統裡現在是什麼樣就什麼樣
    case leave
}
