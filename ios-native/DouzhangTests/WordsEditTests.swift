@testable import Douzhang
import XCTest

/// 番茄架的收據改收下那顆的在做什麼與那句（四項第 2 項）：改字、存檔、同步時改的那份整組贏。
final class WordsEditTests: XCTestCase {
    private let minute = Moment.minute
    private let base = Moment.local(2026, 11, 24, 9)
    private let key = "2026-11-24"

    private func sample(doing: String = "寫稿", clue: String = "寫完第二章") -> Bean {
        var bean = SyncSample.bean("r1", at: base + 25 * minute)
        bean.start = base
        bean.doing = doing
        bean.clue = clue
        return bean
    }

    private func edit(_ state: AppState, doing: String, clue: String, at now: Millis) -> AppState {
        Machine.editWords(state, id: "r1", doing: doing, clue: clue, now: now)
    }

    private func only(_ state: AppState) throws -> Bean {
        let beans = SyncSample.beans(state)
        XCTAssertEqual(beans.count, 1)
        return try XCTUnwrap(beans.first)
    }

    private func merged(_ one: AppState, _ two: AppState) -> AppState {
        SyncMerge.merged(one, SyncSample.remote(two))
    }

    // MARK: 改字

    func test改了兩樣都換掉記下改的時刻別的不動() throws {
        let state = SyncSample.state(key, sample())
        let edited = try only(edit(state, doing: "改稿", clue: "第二章", at: base + minute * 90))
        XCTAssertEqual(edited.doing, "改稿")
        XCTAssertEqual(edited.clue, "第二章")
        XCTAssertEqual(edited.wordsEditedAt, base + minute * 90)
        var rest = edited
        rest.doing = "寫稿"
        rest.clue = "寫完第二章"
        rest.wordsEditedAt = nil
        XCTAssertEqual(rest, sample())
    }

    func test頭尾空白去掉上限跟寫的時候一樣清空就是不寫() throws {
        let state = SyncSample.state(key, sample())
        let long = String(repeating: "字", count: 200)
        let edited = try only(edit(state, doing: "  \(long) ", clue: "\n\(long)\n", at: base))
        XCTAssertEqual(edited.doing.count, Params.doingMaxChars)
        XCTAssertEqual(edited.clue.count, Params.noteMaxChars)
        let cleared = try only(edit(state, doing: "  ", clue: "", at: base))
        XCTAssertEqual(cleared.doing, "")
        XCTAssertEqual(cleared.clue, "")
    }

    func test沒改字只按好什麼都不變不記時刻() {
        let state = SyncSample.state(key, sample())
        XCTAssertEqual(edit(state, doing: " 寫稿 ", clue: "寫完第二章", at: base), state)
    }

    func test找不到這顆或作廢那筆原封不動() {
        var state = SyncSample.state(key, sample())
        state.days[key]?.voids.append(SyncSample.voided("v1", at: base))
        let missing = Machine.editWords(state, id: "r9", doing: "x", clue: "y", now: base)
        XCTAssertEqual(missing, state)
        let voided = Machine.editWords(state, id: "v1", doing: "x", clue: "y", now: base)
        XCTAssertEqual(voided, state)
    }

    func test兩台合過超過上限的那句沒動就不切() throws {
        let half = String(repeating: "甲", count: 100)
        let joined = half + "\n" + half.replacingOccurrences(of: "甲", with: "乙")
        let state = SyncSample.state(key, sample(clue: joined))
        let edited = try only(edit(state, doing: "改稿", clue: joined, at: base))
        XCTAssertEqual(edited.clue, joined)
        XCTAssertEqual(edited.doing, "改稿")
    }

    func test收據那一列帶著這顆的編號() {
        let rows = Receipt.rows(DayRecord(beans: [sample()]))
        XCTAssertEqual(rows.map(\.id), ["r1"])
    }

    // MARK: 存檔

    func test改的時刻存了再讀一模一樣() throws {
        let state = edit(SyncSample.state(key, sample()), doing: "改稿", clue: "", at: base + 0.5)
        XCTAssertEqual(try StateDecoding.parse(StateEncoding.text(state)), state)
    }

    func test沒改過的不寫這一欄舊檔讀出來是沒有() throws {
        let text = try StateEncoding.text(SyncSample.state(key, sample()))
        XCTAssertFalse(text.contains("wordsEditedAt"))
        let old = """
        {"settings":{},"days":{"2026-11-24":{"beans":[{"t":1,"len":25,"clue":"寫完","id":"r1"}]}}}
        """
        let bean = try XCTUnwrap(StateDecoding.parse(old).days[key]?.beans.first)
        XCTAssertNil(bean.wordsEditedAt)
        XCTAssertEqual(bean.clue, "寫完")
    }

    /// 舊版讀檔的寫法：不認得的欄位跳過，其他照讀。新版寫出來的檔多一欄，舊版照樣讀得懂。
    func test不認得的欄位照樣讀得懂() throws {
        let text = """
        {"settings":{},"days":{"2026-11-24":{"beans":[{"t":1,"len":25,"clue":"寫完","id":"r1",
         "doing":"寫稿","someNewField":12345}]}}}
        """
        let bean = try XCTUnwrap(StateDecoding.parse(text).days[key]?.beans.first)
        XCTAssertEqual(bean.doing, "寫稿")
        XCTAssertEqual(bean.clue, "寫完")
    }

    func test雲端檔帶著改的時刻範圍外的那顆不收() {
        let edited = edit(SyncSample.state(key, sample()), doing: "改稿", clue: "", at: base + 0.7)
        XCTAssertEqual(SyncSample.beans(merged(Store.blank(), edited)).first?.wordsEditedAt, base)
        var broken = sample()
        broken.wordsEditedAt = -1
        let skipped = merged(Store.blank(), SyncSample.state(key, broken))
        XCTAssertTrue(SyncSample.beans(skipped).isEmpty)
    }

    // MARK: 同步

    func test改短的贏過另一台沒改的長字不會被併回來() throws {
        let theirs = SyncSample.state(key, sample())
        let mine = edit(theirs, doing: "改", clue: "短", at: base + 60 * minute)
        for state in [merged(mine, theirs), merged(theirs, mine)] {
            let bean = try only(state)
            XCTAssertEqual(bean.doing, "改")
            XCTAssertEqual(bean.clue, "短")
            XCTAssertEqual(bean.wordsEditedAt, base + 60 * minute)
        }
    }

    func test兩台都改過改得晚的整組贏() throws {
        let start = SyncSample.state(key, sample())
        let early = edit(start, doing: "早", clue: "早的那句", at: base + 60 * minute)
        let late = edit(start, doing: "晚", clue: "", at: base + 61 * minute)
        for state in [merged(early, late), merged(late, early)] {
            let bean = try only(state)
            XCTAssertEqual(bean.doing, "晚")
            XCTAssertEqual(bean.clue, "")
            XCTAssertEqual(bean.wordsEditedAt, base + 61 * minute)
        }
    }

    func test改的時刻一樣或都沒改照舊兩句都留() {
        var one = sample(doing: "寫", clue: "甲")
        var two = sample(doing: "寫完", clue: "乙")
        let both = SyncJoin.records(.kept(one), .kept(two))
        // 兩句都留時照位元組排：「乙」在「甲」前面
        XCTAssertEqual(both, .kept(merging(one, doing: "寫完", clue: "乙\n甲")))
        one.wordsEditedAt = base
        two.wordsEditedAt = base + 0.5
        let same = SyncJoin.records(.kept(one), .kept(two))
        var expected = merging(one, doing: "寫完", clue: "乙\n甲")
        expected.wordsEditedAt = base + 0.5
        XCTAssertEqual(same, .kept(expected))
    }

    func test改過字的那顆遇到作廢那筆留它改的字() {
        var bean = sample(doing: "改", clue: "短")
        bean.wordsEditedAt = base
        var entry = SyncSample.voided("r1", at: base)
        entry.text = "作廢那行"
        entry.doing = "寫稿"
        let joined = SyncJoin.records(.kept(bean), .voided(entry))
        XCTAssertEqual(joined, .kept(bean))
        bean.wordsEditedAt = nil
        let old = SyncJoin.records(.voided(entry), .kept(bean))
        XCTAssertEqual(old, .kept(merging(bean, doing: "寫稿\n改", clue: "作廢那行\n短")))
    }

    private func merging(_ bean: Bean, doing: String, clue: String) -> Bean {
        var next = bean
        next.doing = doing
        next.clue = clue
        return next
    }
}
