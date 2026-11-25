import Foundation

/// 這一刻畫成什麼樣、念成什麼。鎖定畫面與動態島都從這裡拿，兩邊不會說不一樣的話。
struct LiveCardLook: Equatable {
    enum Ring: Equatable {
        case running(ClosedRange<Date>), full, empty
    }

    /// 計時最寬會長到多寬：系統的計時文字會撐滿能用的寬度，靠這串字把它框住
    private static let wideTimer = "00:00"
    private static let slimTimer = "0:00"
    private static let wideFrom = 10 * Params.secondsPerMinute

    var ring: Ring
    var ringColor: RGB
    var fill: RGB
    /// 休息那顆還沒長的小番茄
    var isSmall: Bool
    /// 時間左邊的小標
    var caption: String?
    /// 沒有時間可看時的大字，與鎖定畫面上它下面那行
    var title: String?
    var note: String?
    var timer: ClosedRange<Date>?
    /// 環與番茄念成什麼；後面接著念時間
    var spoken: String

    /// 過了 staleDate 還沒人更新的，跟 app 醒著時換上的畫成同一個樣子。
    init(_ face: LiveCardFace, isStale: Bool) {
        switch face {
        case let .growing(color, from, until, ripe) where !isStale:
            self.init(color: color, from: from, until: until, ripe: ripe)
        case let .growing(color, _, _, _), let .rang(color):
            self.init(rang: color)
        case let .resting(from, until):
            self.init(restFrom: from, until: until, isOver: isStale)
        case .restingOpen:
            self.init(rest: .empty, title: Words.rest)
        }
    }

    var timerTemplate: String {
        guard let timer else { return "" }
        let span = timer.upperBound.timeIntervalSince(timer.lowerBound)
        return span < Self.wideFrom ? Self.slimTimer : Self.wideTimer
    }

    private init(color: TomatoColor, from: Date, until: Date, ripe: Bool) {
        let span = Self.range(from, until)
        // 計時中整段是青的，熟了才換標籤色；再做的那段已經熟過，跟 app 裡一樣環是滿的
        ring = ripe ? .full : .running(span)
        ringColor = Tokens.Tomato.body(color)
        fill = ripe ? Tokens.Tomato.body(color) : Tokens.Tomato.unripe
        isSmall = false
        timer = span
        spoken = Words.leftOfThis
    }

    private init(rang color: TomatoColor) {
        ring = .full
        ringColor = Tokens.Tomato.body(color)
        fill = Tokens.Tomato.body(color)
        isSmall = false
        title = Words.rang
        note = Words.bellSub
        spoken = Words.rang + Words.bellSub
    }

    private init(restFrom from: Date, until: Date, isOver: Bool) {
        if isOver {
            self.init(rest: .full, title: Words.restDone)
            return
        }
        let span = Self.range(from, until)
        self.init(rest: .running(span), title: nil)
        caption = Words.rest
        timer = span
    }

    private init(rest ring: Ring, title: String?) {
        self.ring = ring
        ringColor = Tokens.Tomato.vine
        fill = Tokens.Tomato.unripe
        isSmall = true
        self.title = title
        spoken = title ?? Words.rest
    }

    /// 頭尾顛倒的區間會讓擴充當掉：匯入的檔什麼時刻都可能有。
    private static func range(_ from: Date, _ until: Date) -> ClosedRange<Date> {
        min(from, until) ... until
    }
}
