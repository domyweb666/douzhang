@testable import Douzhang
import Foundation

/// 測試共用：本地時間的某一刻、一分鐘多少毫秒。
enum Moment {
    static let minute = Params.msPerMinute

    /// 本地時間的某年某月某日幾點（毫秒）。日期鍵用本地日期，所以測試也用本地時間造時刻。
    static func local(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ past: Int = 0
    ) -> Millis {
        let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: past)
        let date = Store.localCalendar().date(from: parts) ?? Date(timeIntervalSince1970: 0)
        return date.timeIntervalSince1970 * Params.msPerSecond
    }
}

extension AppState {
    var focusRun: FocusRun? {
        Machine.focusRun(self)
    }

    var restRun: RestRun? {
        if case let .rest(run)? = current { return run }
        return nil
    }
}
