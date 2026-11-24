@testable import Douzhang
import XCTest

/// 固定種子的骰子：每次跑都是同一串，壞了才重現得出來。
private struct Dice {
    var seed: UInt64

    mutating func roll() -> UInt64 {
        seed &+= 0x9E37_79B9_7F4A_7C15
        var mix = seed
        mix = (mix ^ (mix >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mix = (mix ^ (mix >> 27)) &* 0x94D0_49BB_1331_11EB
        return mix ^ (mix >> 31)
    }

    mutating func pick<Value>(_ list: [Value]) -> Value {
        list[Int(roll() % UInt64(list.count))]
    }
}

/// 合併的三個性質：交換、結合、冪等（標籤順序與空的日子除外）。
/// 三台照什麼順序互相合，最後每台都一樣。
final class SyncLawsTests: XCTestCase {
    private let rounds = 400
    private let base = Moment.local(2026, 11, 24, 9)
    private let words = ["", "寫", "寫完", "寫完第二章", "改稿", "甲\n乙", "乙\n甲"]

    /// 拿來比的內容：紀錄（有東西的日子）、還在的標籤、刪掉的標籤。
    /// 時刻照整毫秒比：本機那份留著小數，別台讀到的是整毫秒。
    private struct Content: Equatable {
        var days: [String: DayRecord]
        var types: [String: TagType]
        var removed: [String: RemovedTag]

        init(_ state: AppState) {
            days = state.days.filter { $0.value != DayRecord() }.mapValues { day in
                DayRecord(beans: day.beans.map(\.wholeMs), voids: day.voids.map(\.wholeMs))
            }
            types = state.settings.types.reduce(into: [:]) { $0[$1.id] = Content.whole($1) }
            removed = state.settings.removedTypes.reduce(into: [:]) {
                $0[$1.type.id] = Content.whole($1)
            }
        }

        private static func whole(_ type: TagType) -> TagType {
            var next = type
            next.mod = type.mod.rounded(.down)
            return next
        }

        private static func whole(_ gone: RemovedTag) -> RemovedTag {
            RemovedTag(type: whole(gone.type), removedAt: gone.removedAt.rounded(.down))
        }
    }

    // MARK: 造資料

    private func bean(_ id: String, _ dice: inout Dice) -> Bean {
        var bean = SyncSample.bean(id, at: base + dice.pick([0, 0.25, 0.75, 1, 2]))
        bean.typeId = dice.pick(["t1", "t2"])
        bean.flow = dice.pick([0, 15])
        bean.start = dice.pick([nil, base, base + 0.25, base + Params.msPerHour * 16])
        bean.zone = dice.pick([nil, "Asia/Taipei", "America/Los_Angeles", "Not/AZone"])
        bean.clue = dice.pick(words)
        bean.doing = dice.pick(words)
        bean.notes = [dice.pick(words), dice.pick(words)]
        bean.pings = dice.pick([[], [""], ["", ""], ["快遞"]])
        bean.done = dice.pick([true, false])
        bean.doneAt = dice.pick([nil, base, base + 0.5, base + 1])
        return bean
    }

    private func entry(_ id: String, _ dice: inout Dice) -> VoidEntry {
        var entry = SyncSample.voided(id, at: base + dice.pick([0, 0.5, 1, 2]))
        entry.start = dice.pick([nil, base])
        entry.zone = dice.pick([nil, "Asia/Taipei"])
        entry.len = dice.pick([nil, 25])
        entry.reason = dice.pick(["", "訊息"])
        entry.text = dice.pick(words)
        entry.notes = [dice.pick(words)]
        return entry
    }

    private func days(_ dice: inout Dice) -> [String: DayRecord] {
        var days: [String: DayRecord] = [:]
        for id in ["r1", "r2", "r3"] {
            let key = dice.pick(["2026-11-23", "2026-11-24", "2026-11-25"])
            switch dice.pick([0, 1, 2]) {
            case 0: days[key, default: DayRecord()].beans.append(bean(id, &dice))
            case 1: days[key, default: DayRecord()].voids.append(entry(id, &dice))
            default: continue
            }
        }
        return StateUpgrade.regrouped(days)
    }

    /// t1 永遠在：全被刪光時留哪個看本機，那一條不在三個性質裡。
    /// 沒動過的預設（mod 0）也不在：這台沒有、沒人用的不收，看是誰合誰。
    private func state(_ dice: inout Dice) -> AppState {
        var state = SyncSample.state(days(&dice))
        state.settings.types = [Store.defaultType]
        for id in ["t2", "t3", "t4"] {
            let mod: Millis = dice.pick([1, 2, 2.5, 3])
            let type = TagType(
                id: id,
                name: dice.pick(["甲", "乙"]),
                len: 25,
                color: dice.pick([.red, .pink]),
                mod: mod
            )
            switch dice.pick([0, 1, 2]) {
            case 0: state.settings.types.append(type)
            case 1:
                let when = mod + dice.pick([1, 2, 3])
                state.settings.removedTypes.append(RemovedTag(type: type, removedAt: when))
            default: continue
            }
        }
        return state
    }

    private func merged(_ one: AppState, _ two: AppState) -> AppState {
        SyncMerge.merged(one, SyncSample.remote(two))
    }

    // MARK: 三個性質

    func test交換() {
        var dice = Dice(seed: 1)
        for round in 0 ..< rounds {
            let one = state(&dice)
            let two = state(&dice)
            let left = Content(merged(one, two))
            XCTAssertEqual(left, Content(merged(two, one)), "第 \(round) 輪")
        }
    }

    func test結合() {
        var dice = Dice(seed: 2)
        for round in 0 ..< rounds {
            let one = state(&dice)
            let two = state(&dice)
            let three = state(&dice)
            let left = Content(merged(merged(one, two), three))
            XCTAssertEqual(left, Content(merged(one, merged(two, three))), "第 \(round) 輪")
        }
    }

    func test冪等合過的再合一次不變() {
        var dice = Dice(seed: 3)
        for round in 0 ..< rounds {
            let one = state(&dice)
            let two = state(&dice)
            // 合一份空的只會照時間排好，拿來當對照
            let tidy = SyncMerge.merged(one, [SyncFiles.Remote(device: SyncSample.other)])
            XCTAssertEqual(merged(one, one), tidy, "第 \(round) 輪")
            let both = merged(one, two)
            XCTAssertEqual(merged(both, two), both, "第 \(round) 輪")
            XCTAssertEqual(merged(both, both), both, "第 \(round) 輪")
        }
    }

    func test三台經過檔案來回最後每台一樣() {
        var dice = Dice(seed: 4)
        for round in 0 ..< rounds {
            var phones = [state(&dice), state(&dice), state(&dice)]
            for (from, into) in [(0, 1), (2, 0), (1, 2), (0, 1), (2, 0), (1, 2)] {
                phones[into] = SyncMerge.merged(phones[into], SyncSample.remote(phones[from]))
            }
            XCTAssertEqual(Content(phones[0]), Content(phones[1]), "第 \(round) 輪")
            XCTAssertEqual(Content(phones[1]), Content(phones[2]), "第 \(round) 輪")
        }
    }
}
