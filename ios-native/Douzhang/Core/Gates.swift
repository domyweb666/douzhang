import Foundation

/// 跟著狀態走的兩個開關：白噪音該播哪一種、其他 app 該不該擋。純函式。
/// 殼只在答案變了的時候才去叫系統；播放與擋板本身等殼搬過來那一片再加。
enum Gates {
    /// 現在該播哪一種：這顆還在跑才播設定選的那種；鈴響、休息、待機都不播。
    static func ambience(_ state: AppState, now: Millis) -> AmbienceKind {
        Machine.phaseOf(state, now: now) == .focus ? state.settings.ambience : .off
    }

    /// 現在該不該擋：開關開著、而且這顆還在跑。鈴響、休息、待機都不擋。
    static func shouldShield(_ state: AppState, now: Millis) -> Bool {
        state.settings.shield && Machine.phaseOf(state, now: now) == .focus
    }
}
