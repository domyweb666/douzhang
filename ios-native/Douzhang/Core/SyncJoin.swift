import Foundation

/// 一筆紀錄：收下的或作廢的。同一個編號最後只會是其中一種。
enum SyncRecord: Equatable {
    case kept(Bean)
    case voided(VoidEntry)

    var id: String {
        switch self {
        case let .kept(bean): bean.id
        case let .voided(entry): entry.id
        }
    }

    /// 算得出來的那一天；缺開始時刻或時區認不得是 nil（只能照檔裡的鍵）。
    var home: String? {
        switch self {
        case let .kept(bean): StateUpgrade.home(bean.start, zone: bean.zone)
        case let .voided(entry): StateUpgrade.home(entry.start, zone: entry.zone)
        }
    }

    /// 時刻去掉不到一毫秒的尾巴。本機的時刻帶小數，寫成字再讀回來可能差最後一位；
    /// 寫進雲端的一律整毫秒、比的時候也照整毫秒，兩台才不會為了小數點後面改來改去。
    var whole: SyncRecord {
        switch self {
        case let .kept(bean): .kept(bean.wholeMs)
        case let .voided(entry): .voided(entry.wholeMs)
        }
    }
}

extension Bean {
    var wholeMs: Bean {
        var next = self
        next.keptAt = keptAt.rounded(.down)
        next.start = start.map { $0.rounded(.down) }
        next.doneAt = doneAt.map { $0.rounded(.down) }
        next.wordsEditedAt = wordsEditedAt.map { $0.rounded(.down) }
        return next
    }
}

extension VoidEntry {
    var wholeMs: VoidEntry {
        var next = self
        next.voidedAt = voidedAt.rounded(.down)
        next.start = start.map { $0.rounded(.down) }
        return next
    }
}

/// 同一個編號、內容不同的兩份怎麼合成一份。每條規則都跟先後順序無關：
/// 交換、結合、冪等都成立，幾台照什麼順序合，最後都一樣。
/// （規則先用 Python 隨機跑過幾萬組三份的資料，三個性質都成立才翻成這裡。）
enum SyncJoin {
    static func records(_ left: SyncRecord, _ right: SyncRecord) -> SyncRecord {
        switch (left, right) {
        case let (.kept(one), .kept(two)):
            .kept(beans(one, two))
        case let (.voided(one), .voided(two)):
            .voided(voids(one, two))
        case let (.kept(bean), .voided(entry)), let (.voided(entry), .kept(bean)):
            .kept(absorbed(bean, entry))
        }
    }

    /// 收下贏作廢；作廢那筆記的、寫的都併進來（打過的字不丟），原因與第幾分鐘不留。
    /// 寫的字照 typed 的規則：作廢那筆改不了字，當成沒改過；收下那顆改過字就留它改的。
    private static func absorbed(_ bean: Bean, _ entry: VoidEntry) -> Bean {
        var next = bean
        next.notes = union(bean.notes, entry.notes)
        next.pings = union(bean.pings, entry.pings)
        let words = typed(Typed(bean), Typed(doing: entry.doing, clue: entry.text))
        next.clue = words.clue
        next.doing = words.doing
        return next
    }

    private static func beans(_ left: Bean, _ right: Bean) -> Bean {
        var next = rank(left) < rank(right) ? right : left
        next.notes = union(left.notes, right.notes)
        next.pings = union(left.pings, right.pings)
        let words = typed(Typed(left), Typed(right))
        next.clue = words.clue
        next.doing = words.doing
        next.wordsEditedAt = words.editedAt
        next.done = left.done || right.done
        next.doneAt = later(left.doneAt, right.doneAt)
        return next
    }

    private static func voids(_ left: VoidEntry, _ right: VoidEntry) -> VoidEntry {
        var next = rank(left) < rank(right) ? right : left
        next.notes = union(left.notes, right.notes)
        next.pings = union(left.pings, right.pings)
        next.text = lines(left.text, right.text)
        next.doing = lines(left.doing, right.doing)
        return next
    }

    static func later(_ left: Millis?, _ right: Millis?) -> Millis? {
        guard let left, let right else { return left ?? right }
        return max(left, right)
    }

    /// 字的先後照位元組比，不用字串自己的 <：本機打的字跟從檔案讀回來的字，
    /// 一個是另一個的開頭時（「寫」跟「寫完」）排出來的順序不一定一樣，兩台會合出不同的結果。
    static func precedes(_ left: String, _ right: String) -> Bool {
        left.utf8.lexicographicallyPrecedes(right.utf8)
    }

    static func precedes(_ left: [String], _ right: [String]) -> Bool {
        left.lexicographicallyPrecedes(right) { precedes($0, $1) }
    }
}

// MARK: 挑一份

extension SyncJoin {
    /// 併不起來的欄位（標籤、長度、開始、時區、原因…）整組跟著一份走，收下、作廢的時刻也是：
    /// 先看算不算得出哪一天（算得出來的贏，日期鍵才不會看合併順序），再看時刻晚的，再同就照字比。
    /// 會併起來的欄位（念頭、那句話…）不准拿來比：併完內容變了，贏家會跟著換。
    private struct Rank: Comparable {
        var home: Bool
        var time: Millis
        var rest: [String]

        static func < (left: Rank, right: Rank) -> Bool {
            if left.home != right.home {
                return right.home
            }
            if left.time != right.time {
                return left.time < right.time
            }
            return SyncJoin.precedes(left.rest, right.rest)
        }
    }

    private static func rank(_ bean: Bean) -> Rank {
        let whole = bean.wholeMs
        return Rank(
            home: SyncRecord.kept(bean).home != nil,
            time: whole.keptAt,
            rest: [
                whole.typeId,
                mark(whole.len),
                mark(whole.flow),
                mark(whole.start),
                mark(whole.zone),
            ]
        )
    }

    private static func rank(_ entry: VoidEntry) -> Rank {
        let whole = entry.wholeMs
        return Rank(
            home: SyncRecord.voided(entry).home != nil,
            time: whole.voidedAt,
            rest: [
                whole.typeId,
                mark(Double(whole.minute)),
                whole.reason,
                mark(whole.len),
                mark(whole.start),
                mark(whole.zone),
            ]
        )
    }

    /// 沒有的寫成空字串，有的前面加一個記號：「沒有」跟「空的」才分得出來。
    private static func mark(_ value: Double?) -> String {
        value.map { "+\($0)" } ?? ""
    }

    private static func mark(_ value: String?) -> String {
        value.map { "+" + $0 } ?? ""
    }
}

// MARK: 改過的字

extension SyncJoin {
    /// 一筆的在做什麼、那句，跟最後在收據改字的時刻（作廢那筆改不了字，一律 nil）。
    struct Typed: Equatable {
        var doing: String
        var clue: String
        var editedAt: Millis?
    }

    /// 改字的時刻（照整毫秒）不一樣：晚的那份整組贏，時刻跟著它。兩句都留的話，
    /// 另一台還沒改的舊字會被併回來，改短的又變回長的。
    /// 一樣（含兩邊都沒改過）才照舊兩邊都留，時刻取晚的（同一毫秒只差小數）。
    /// 先比時刻、一樣才併：交換、結合、冪等照樣成立（SyncLawsTests、WordsEditTests 隨機跑過）。
    static func typed(_ left: Typed, _ right: Typed) -> Typed {
        let leftAt = left.editedAt.map { $0.rounded(.down) }
        let rightAt = right.editedAt.map { $0.rounded(.down) }
        if leftAt != rightAt {
            return later(leftAt, rightAt) == leftAt ? left : right
        }
        return Typed(
            doing: lines(left.doing, right.doing),
            clue: lines(left.clue, right.clue),
            editedAt: later(left.editedAt, right.editedAt)
        )
    }
}

extension SyncJoin.Typed {
    init(_ bean: Bean) {
        self.init(doing: bean.doing, clue: bean.clue, editedAt: bean.wordsEditedAt)
    }
}

// MARK: 兩邊都留

extension SyncJoin {
    /// 念頭、有人找：同一句兩邊都有只算一次，但一邊記了兩次就是兩次
    /// （沒寫字的也算一筆，存成空字串；照「不重複」去掉，分析的次數會變少）。
    /// 一邊全包含另一邊就照多的那邊的順序；兩邊各有各的才照字排：
    /// 清單裡看不出誰先誰後，照任何一邊的順序都會讓結果看合併順序。
    static func union(_ left: [String], _ right: [String]) -> [String] {
        if left == right {
            return left
        }
        let both = counts(left).merging(counts(right)) { max($0, $1) }
        let total = both.values.reduce(0, +)
        switch (total == left.count, total == right.count) {
        case (true, true):
            return precedes(left, right) ? right : left
        case (true, false):
            return left
        case (false, true):
            return right
        case (false, false):
            return both.keys
                .sorted { precedes($0, $1) }
                .flatMap { Array(repeating: $0, count: both[$0] ?? 0) }
        }
    }

    private static func counts(_ list: [String]) -> [String: Int] {
        list.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    /// 寫的字：一邊包含另一邊就留多的那份，不然兩句都留、分行。
    /// 照行比：併過的（兩行）跟還沒併的（一行）再遇到，不會又多一行。
    static func lines(_ left: String, _ right: String) -> String {
        if left == right {
            return left
        }
        let leftTop = longest(split(left))
        let rightTop = longest(split(right))
        let both = longest(leftTop + rightTop)
        switch (both == leftTop, both == rightTop) {
        case (true, true): return fuller(left, right)
        case (true, false): return left
        case (false, true): return right
        case (false, false): return both.joined(separator: "\n")
        }
    }

    private static func split(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map { String($0) }
    }

    /// 拿掉被別行包含的，照字排。
    private static func longest(_ list: [String]) -> [String] {
        let unique = Set(list)
        return unique
            .filter { line in !unique.contains { $0 != line && $0.contains(line) } }
            .sorted { precedes($0, $1) }
    }

    /// 重點的行都一樣（只差順序或多了短的行）：留字多的，一樣多就照行比。
    private static func fuller(_ left: String, _ right: String) -> String {
        if left.utf8.count != right.utf8.count {
            return left.utf8.count < right.utf8.count ? right : left
        }
        let leftLines = split(left)
        let rightLines = split(right)
        if leftLines != rightLines {
            return precedes(leftLines, rightLines) ? right : left
        }
        return precedes(left, right) ? right : left
    }
}
