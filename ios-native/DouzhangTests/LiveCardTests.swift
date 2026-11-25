@testable import Douzhang
import XCTest

/// 鎖定畫面與動態島那一張：什麼時候該有、上面是什麼、畫成什麼樣。叫系統的在 App/LiveCards，這裡不碰。
final class LiveCardTests: XCTestCase {
    private let base = Moment.local(2026, 11, 25, 9)
    private let minute = Moment.minute

    private var rang: Millis {
        base + 25 * minute
    }

    private func blank(_ change: (inout AppSettings) -> Void = { _ in }) -> AppState {
        var state = Store.blank()
        change(&state.settings)
        return state
    }

    private func focusing(_ from: AppState) -> AppState {
        Machine.start(from, now: base)
    }

    private func resting(_ from: AppState) -> AppState {
        Machine.keep(focusing(from), now: rang, text: "x")
    }

    private func moment(_ time: Millis) -> Date {
        Store.date(time)
    }

    // MARK: 計時中、響了

    func test待機沒有() {
        XCTAssertNil(LiveCard.face(blank(), now: base))
    }

    func test開始一顆就有標籤色與起訖() {
        var state = blank()
        state.settings.typeId = "t2"
        let face = LiveCard.face(focusing(state), now: base)
        let expected = LiveCardFace.growing(
            .purple,
            from: moment(base),
            until: moment(base + 50 * minute),
            ripe: false
        )
        XCTAssertEqual(face, expected)
    }

    func test響之前一毫秒還在長響的那一刻換成熟了() {
        let state = focusing(blank())
        let growing = LiveCard.face(state, now: rang - 1)
        XCTAssertEqual(growing, LiveCard.face(state, now: base))
        XCTAssertEqual(LiveCard.face(state, now: rang), .rang(.red))
    }

    func test響了沒收放多久都是熟了的樣子() {
        let state = focusing(blank())
        XCTAssertEqual(LiveCard.face(state, now: rang + 600 * minute), .rang(.red))
    }

    func test再做換成新的結束時刻番茄已經熟了() {
        let more = Machine.flow(focusing(blank()), now: rang + minute, minutes: 15)
        let expected = LiveCardFace.growing(
            .red,
            from: moment(base),
            until: moment(rang + 16 * minute),
            ripe: true
        )
        XCTAssertEqual(LiveCard.face(more, now: rang + minute), expected)
        XCTAssertEqual(LiveCard.face(more, now: rang + 16 * minute), .rang(.red))
    }

    func test作廢與停下來都收掉() {
        let voided = Machine.voidBean(focusing(blank()), now: base + 10 * minute, reason: "念頭")
        XCTAssertNil(LiveCard.face(voided, now: base + 10 * minute))
        let stopped = Machine.voidBean(focusing(blank()), now: base + minute, early: true)
        XCTAssertNil(LiveCard.face(stopped, now: base + minute))
    }

    func test計時中改標籤顏色跟著換() {
        var state = focusing(blank())
        state = SettingsLogic.setTypeColor(state, id: "t1", color: .pink, now: base + minute)
        XCTAssertEqual(LiveCard.face(state, now: rang), .rang(.pink))
    }

    func test計時中刪掉那個標籤顏色留著() {
        var state = blank()
        state.settings.typeId = "t2"
        state = SettingsLogic.removeType(focusing(state), id: "t2", now: base + minute)
        XCTAssertEqual(LiveCard.face(state, now: base + 50 * minute), .rang(.purple))
    }

    // MARK: 休息

    func test收下變休息起訖照休息() {
        let face = LiveCard.face(resting(blank()), now: rang)
        let expected = LiveCardFace.resting(from: moment(rang), until: moment(rang + 5 * minute))
        XCTAssertEqual(face, expected)
    }

    func test我自己決定的休息沒有終點放多久都一樣() {
        let state = resting(blank { $0.restMode = .own })
        XCTAssertEqual(LiveCard.face(state, now: rang), .restingOpen)
        XCTAssertEqual(LiveCard.face(state, now: rang + 300 * minute), .restingOpen)
    }

    func test休息中改成我自己決定不影響這一段() {
        var state = resting(blank())
        state.settings.restMode = .own
        let expected = LiveCardFace.resting(from: moment(rang), until: moment(rang + 5 * minute))
        XCTAssertEqual(LiveCard.face(state, now: rang + minute), expected)
    }

    func test休息到點收掉前一毫秒還在() {
        let state = resting(blank())
        XCTAssertNotNil(LiveCard.face(state, now: rang + 5 * minute - 1))
        XCTAssertNil(LiveCard.face(state, now: rang + 5 * minute))
    }

    func test提早回來與響太久才收都沒有() {
        XCTAssertNil(LiveCard.face(Machine.backFromRest(resting(blank())), now: rang + minute))
        let late = Machine.keep(focusing(blank()), now: rang + 60 * minute, text: "")
        XCTAssertNil(LiveCard.face(late, now: rang + 60 * minute))
    }

    func test自動開始的空檔留著原本那張過了換成新的一顆() {
        let state = resting(blank { $0.autoNext = true })
        let restEnd = rang + 5 * minute
        let before = LiveCard.face(state, now: restEnd - 1)
        XCTAssertEqual(LiveCard.face(state, now: restEnd), before)
        let startAt = restEnd + Params.autoNextDelayMs
        let begun = Machine.settle(state, now: startAt)
        let expected = LiveCardFace.growing(
            .red,
            from: moment(startAt),
            until: moment(startAt + 25 * minute),
            ripe: false
        )
        XCTAssertEqual(LiveCard.face(begun, now: startAt), expected)
    }

    func test從捷徑開始跟按開始同一張() {
        let outside = Machine.startFromOutside(resting(blank()), now: rang + minute)
        let pressed = Machine.start(Machine.backFromRest(resting(blank())), now: rang + minute)
        XCTAssertNotNil(outside)
        XCTAssertEqual(
            outside.flatMap { LiveCard.face($0, now: rang + minute) },
            LiveCard.face(pressed, now: rang + minute)
        )
    }

    func test整份換掉就照換上的那份() {
        XCTAssertNil(LiveCard.face(Store.blank(), now: base + minute))
        let other = Machine.start(Store.blank(), now: base + minute, typeId: "t3")
        XCTAssertEqual(LiveCard.face(other, now: base + 40 * minute), .rang(.orange))
    }

    // MARK: 沒變就是同一個值、不含使用者寫的字

    func test時間走與寫字都不換內容() {
        let state = focusing(blank())
        let first = LiveCard.face(state, now: base)
        var busy = Machine.setDraft(state, text: "改一個字")
        busy = Machine.setDoing(busy, text: "寫第三節")
        busy = Machine.jot(busy, kind: .notes)
        busy = Machine.markDone(busy, now: base + minute)
        busy = SettingsLogic.renameType(busy, id: "t1", name: "看診", now: base + minute)
        XCTAssertEqual(LiveCard.face(busy, now: base + 24 * minute), first)
    }

    func test每一態送出去的內容都沒有標籤名在做什麼與那句() throws {
        var state = blank { $0.types[0].name = "祕密標籤" }
        state.doing = "祕密的事"
        var run = Machine.setDraft(focusing(state), text: "祕密那句")
        run = Machine.jot(run, kind: .notes)
        run = Machine.amendJot(run, from: .notes, into: .notes, text: "祕密念頭")
        let rest = Machine.keep(run, now: rang, text: "祕密那句")
        let own = resting(blank { $0.restMode = .own })
        let more = Machine.flow(run, now: rang, minutes: 30)
        let faces = [
            LiveCard.face(run, now: base),
            LiveCard.face(run, now: rang),
            LiveCard.face(more, now: rang),
            LiveCard.face(rest, now: rang),
            LiveCard.face(own, now: rang),
        ].compactMap { $0 }
        XCTAssertEqual(faces.count, 5)
        let line = try XCTUnwrap(rest.restRun?.msg)
        for face in faces {
            let data = try JSONEncoder().encode(face)
            let sent = try XCTUnwrap(String(bytes: data, encoding: .utf8))
            XCTAssertFalse(sent.contains("祕密"), sent)
            XCTAssertFalse(sent.contains(line), sent)
            XCTAssertFalse(sent.contains(#""t1""#), sent)
            XCTAssertEqual(try JSONDecoder().decode(LiveCardFace.self, from: data), face)
        }
    }

    func test只有有終點的會過時時刻就是終點() {
        let end = moment(rang)
        let growing = LiveCardFace.growing(.red, from: moment(base), until: end, ripe: false)
        XCTAssertEqual(growing.staleDate, end)
        XCTAssertEqual(LiveCardFace.resting(from: moment(base), until: end).staleDate, end)
        XCTAssertNil(LiveCardFace.rang(.red).staleDate)
        XCTAssertNil(LiveCardFace.restingOpen.staleDate)
    }
}

/// 同一張在每一態畫成什麼樣、讀屏念什麼。
final class LiveCardLookTests: XCTestCase {
    private let from = Date(timeIntervalSince1970: 1_000_000)
    private let until = Date(timeIntervalSince1970: 1_001_500)

    private func growing(ripe: Bool = false, isStale: Bool = false) -> LiveCardLook {
        let face = LiveCardFace.growing(.purple, from: from, until: until, ripe: ripe)
        return LiveCardLook(face, isStale: isStale)
    }

    func test計時中番茄是青的環是標籤色只有時間() {
        let look = growing()
        XCTAssertEqual(look.ring, .running(from ... until))
        XCTAssertEqual(look.ringColor, Tokens.Tomato.body(.purple))
        XCTAssertEqual(look.fill, Tokens.Tomato.unripe)
        XCTAssertEqual(look.timer, from ... until)
        XCTAssertNil(look.title)
        XCTAssertNil(look.note)
        XCTAssertNil(look.caption)
        XCTAssertFalse(look.isSmall)
        XCTAssertEqual(look.spoken, "這顆還剩")
    }

    func test再做的那段番茄熟了環是滿的照樣倒數() {
        let look = growing(ripe: true)
        XCTAssertEqual(look.ring, .full)
        XCTAssertEqual(look.fill, Tokens.Tomato.body(.purple))
        XCTAssertEqual(look.timer, from ... until)
    }

    func test過時的跟響了畫成同一個樣子() {
        let rang = LiveCardLook(.rang(.purple), isStale: false)
        XCTAssertEqual(growing(isStale: true), rang)
        XCTAssertEqual(growing(ripe: true, isStale: true), rang)
        XCTAssertEqual(rang.ring, .full)
        XCTAssertEqual(rang.fill, Tokens.Tomato.body(.purple))
        XCTAssertEqual(rang.title, "響了。")
        XCTAssertEqual(rang.note, "這顆熟了，回來收下。")
        XCTAssertNil(rang.timer)
        XCTAssertEqual(rang.spoken, "響了。這顆熟了，回來收下。")
    }

    func test休息藤綠小青番茄倒數到點寫休息完了() {
        let face = LiveCardFace.resting(from: from, until: until)
        let look = LiveCardLook(face, isStale: false)
        XCTAssertEqual(look.ring, .running(from ... until))
        XCTAssertEqual(look.ringColor, Tokens.Tomato.vine)
        XCTAssertEqual(look.fill, Tokens.Tomato.unripe)
        XCTAssertTrue(look.isSmall)
        XCTAssertEqual(look.caption, "休息")
        XCTAssertNil(look.title)
        XCTAssertEqual(look.timer, from ... until)
        XCTAssertEqual(look.spoken, "休息")
        let over = LiveCardLook(face, isStale: true)
        XCTAssertEqual(over.ring, .full)
        XCTAssertEqual(over.title, "休息完了")
        XCTAssertNil(over.caption)
        XCTAssertNil(over.timer)
        XCTAssertEqual(over.spoken, "休息完了")
    }

    func test沒終點的休息寫休息環是空的不數() {
        let look = LiveCardLook(.restingOpen, isStale: false)
        XCTAssertEqual(look.ring, .empty)
        XCTAssertEqual(look.title, "休息")
        XCTAssertNil(look.timer)
        XCTAssertNil(look.caption)
        XCTAssertEqual(look.spoken, "休息")
    }

    func test起訖顛倒不會當掉() {
        let face = LiveCardFace.growing(.red, from: until, until: from, ripe: false)
        XCTAssertEqual(LiveCardLook(face, isStale: false).timer, from ... from)
    }

    func test計時的框十分鐘起才留兩位() {
        func template(_ seconds: Double) -> String {
            let end = from.addingTimeInterval(seconds)
            let face = LiveCardFace.growing(.red, from: from, until: end, ripe: false)
            return LiveCardLook(face, isStale: false).timerTemplate
        }
        XCTAssertEqual(template(599), "0:00")
        XCTAssertEqual(template(600), "00:00")
        XCTAssertEqual(template(90 * 60), "00:00")
        XCTAssertEqual(LiveCardLook(.restingOpen, isStale: false).timerTemplate, "")
    }
}
