import Foundation

/// 顏色的三個分量（各 0–1）。這裡只做混色；色碼在設計代號那邊。
struct RGB: Equatable {
    var red: Double
    var green: Double
    var blue: Double
}

/// 計時中變熟的番茄：這顆走了幾成、什麼顏色。大小固定，只變色。純函式，只看這顆與時鐘。
enum Grow {
    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    /// 這顆走了幾成（0–1）。再做一下的那段番茄已經熟了，維持 1，不倒回去變青。
    static func progress(_ current: Current?, now: Millis) -> Double {
        guard case let .focus(run)? = current else { return 0 }
        if run.flowed {
            return 1
        }
        let span = run.endAt - run.startedAt
        return span > 0 ? clamp((now - run.startedAt) / span) : 1
    }

    /// 什麼顏色：青一路變成這個標籤的番茄色，中間不經過黃。
    static func ripeColor(_ progress: Double, unripe: RGB, ripe: RGB) -> RGB {
        let mix = clamp(progress)
        return RGB(
            red: unripe.red + (ripe.red - unripe.red) * mix,
            green: unripe.green + (ripe.green - unripe.green) * mix,
            blue: unripe.blue + (ripe.blue - unripe.blue) * mix
        )
    }
}
