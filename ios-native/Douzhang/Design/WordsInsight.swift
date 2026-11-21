import Foundation

/// 分析相關的字。照 .analytics/07-圖表與文案.md 的字串表，每句前面寫它的編號。
/// 只給計數與範圍：不寫多了少了、不用百分比、計數是 0 的項目不寫出來。
extension Words {
    /// 作廢原因第二個以前叫「訊息」，現在叫「有人找」。舊資料不改，讀的時候當同一種。
    static let legacyPingReason = "訊息"
    /// 句子裡的簡稱；按鈕上的全名是 noteThought「冒出念頭」
    static let thoughtShort = "念頭"
    static let thisMonth = "這個月"
    /// D-5
    static let jotTitle = "這兩週記了什麼、作廢的原因"
    /// D-8
    static let jotNothing = "這兩週沒有記一筆，也沒有作廢。"
    private static let unfilledReason = "沒選"

    /// 存著的作廢原因 → 畫面上的名字。
    static func voidReason(_ stored: String) -> String {
        stored == legacyPingReason ? notePing : stored
    }

    /// G-2：鈴響頁第二行。兩個數字一樣就只寫一個。
    static func usual(_ range: ClosedRange<Int>) -> String {
        range.lowerBound == range.upperBound
            ? "你平常 \(range.lowerBound) 顆"
            : "你平常 \(range.lowerBound) 到 \(range.upperBound) 顆"
    }

    /// O-1：標籤編輯半頁，這個長度最近怎麼結束的。不到門檻就說還差幾顆。
    static func lengthLine(_ outcome: LengthOutcome, len: Double) -> String {
        let total = outcome.total
        if total < Params.Insight.lengthMin {
            return "這個長度再 \(Params.Insight.lengthMin - total) 顆，這裡會列出它們怎麼結束的"
        }
        let head = "\(number(len)) 分鐘，最近 \(total) 顆"
        if outcome.onBell == total {
            return head + "都是響了就收"
        }
        let parts = [
            ("響了就收", outcome.onBell),
            ("延長", outcome.flowed),
            ("提早做完", outcome.doneEarly),
            ("作廢", outcome.voidMinutes.count),
        ]
        return head + "：" + listed(parts) + voidTail(outcome.voidMinutes)
    }

    /// O-1c、O-1d：作廢的停在第幾分鐘。少的一個個列，多了寫範圍。
    private static func voidTail(_ minutes: [Int]) -> String {
        guard let first = minutes.first, let last = minutes.last else { return "" }
        if minutes.count <= Params.Insight.lengthListMax {
            let each = minutes.map { String($0) }.joined(separator: "、")
            return "。作廢的停在第 \(each) 分鐘"
        }
        return "。作廢的停在第 \(first) 到 \(last) 分鐘"
    }

    /// 「名字 幾」用頓號接起來；幾是 0 的不寫。
    private static func listed(_ parts: [(String, Int)]) -> String {
        parts.filter { $0.1 > 0 }.map { "\($0.0) \($0.1)" }.joined(separator: "、")
    }

    /// O-2 到 O-5：作廢答完回待機那一行。
    static func voidedThisWeek(_ nth: Int, reason: String) -> String {
        let shown = voidReason(reason)
        return shown == voidReasons.last
            ? "這週第 \(nth) 顆選「\(shown)」作廢。"
            : "這週第 \(nth) 顆因為\(shown)作廢。"
    }

    /// 記一筆的種類在句子裡怎麼叫。
    static func jotName(_ kind: JotKind) -> String {
        kind == .notes ? thoughtShort : notePing
    }

    /// J-2、J-3：沒寫字的那幾筆合成一行。
    static func jotTimes(_ kind: JotKind, _ times: Int) -> String {
        "\(jotName(kind)) \(times) 次"
    }

    /// 有寫字的一筆。
    static func jotLine(_ kind: JotKind, _ text: String) -> String {
        "\(jotName(kind))：\(text)"
    }

    /// 一顆記的東西列成幾行：有寫字的一筆一行，沒寫字的那幾筆合成最後一行。
    static func jotLines(_ kind: JotKind, _ all: [String]) -> [String] {
        let written = all.filter { !$0.isEmpty }
        let blank = all.count - written.count
        let lines = written.map { jotLine(kind, $0) }
        return blank > 0 ? lines + [jotTimes(kind, blank)] : lines
    }

    /// D-1：分析第一張的標題。period 是「這週」「這個月」或某一段的名字。
    static func whereTitle(_ period: String) -> String {
        "\(period)時間花在哪"
    }

    /// D-2：每個標籤一列右邊的字。
    static func tagAmount(_ minutes: Double, beans: Int) -> String {
        "\(duration(minutes))・\(beans) 顆"
    }

    /// D-3：第一張最下面那一行事實。
    static func focusFact(_ period: String, minutes: Double, beans: Int) -> String {
        "\(period)專注 \(duration(minutes))，收了 \(beans) 顆"
    }

    /// D-6：記一筆的計數。不到門檻不分種類。
    static func jotSum(_ tally: JotTally) -> String {
        let head = "這兩週記了 \(tally.jots) 筆"
        if tally.jots < Params.Insight.splitMin {
            return head + "。"
        }
        let parts = [(thoughtShort, tally.notes), (notePing, tally.pings)]
        return head + "：" + listed(parts) + "。"
    }

    /// D-7：作廢的計數。有選原因的不到門檻就不分原因；沒選的照實寫，不分攤給別的原因。
    static func voidSum(_ tally: JotTally) -> String {
        let head = "作廢 \(tally.voids) 顆"
        if tally.reasoned < Params.Insight.splitMin {
            return head + "。"
        }
        var parts = tally.reasons.map { ($0.reason, $0.count) }
        parts.append((unfilledReason, tally.unfilled))
        return head + "：" + listed(parts) + "。"
    }

    /// D-9：清單上每一顆的標題。
    static func jotItemTitle(dayKey: String, start: Millis, name: String) -> String {
        "\(weekday(dayKey)) \(TimeText.hhmm(start))・\(name)"
    }
}
