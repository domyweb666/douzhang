import Foundation
import Observation

/// 左右滑的三頁：番茄架｜主畫面｜設定。
enum Page: Hashable, CaseIterable {
    case rack, home, settings
}

/// 殼：開機讀檔、每一拍看時鐘、到點換畫面、每次改動就存、狀態變了就重排通知。
/// 狀態機在 Core/Machine.swift，畫面在 Screens/。每個動作先算新狀態（純函式），再 commit。
@MainActor
@Observable
final class AppModel {
    /// 存著的狀態。過期的休息每一拍收掉，所以畫面讀到的就是現在這一態。
    private(set) var state = Store.blank()
    /// 還在讀檔時是 false，畫面先空著
    private(set) var loaded = false
    private(set) var now = TimeText.nowMillis()
    private(set) var phase = Phase.idle
    /// 存不進去：畫面最上面顯示那一行
    private(set) var saveFailed = false
    /// 本機檔讀不懂：先不覆蓋，只有匯入或清空能換掉
    private(set) var unreadable = false
    var notif = NotifStatus.undetermined
    var page: Page? = Page.home
    /// 剛清空過：番茄架的空狀態換一句話
    var wiped = false
    /// 番茄堆上次看到幾顆：鈴響時番茄堆不在畫面上，回來時要知道哪顆是新的
    var jarSeen: Int?

    @ObservationIgnored let file: StateFile
    @ObservationIgnored let notifier = Notifier()
    @ObservationIgnored private var notifWasOff = false

    init(file: StateFile = .standard) {
        self.file = file
    }

    var todayKey: String {
        Store.dayKey(now)
    }

    /// 開機讀檔，然後每一拍看一次時鐘，直到畫面收掉。
    func run() async {
        if !loaded { load() }
        while !Task.isCancelled {
            tick()
            try? await Task.sleep(for: .milliseconds(Params.tickMs))
        }
    }

    private func load() {
        let found = file.load()
        unreadable = found.unreadable
        let time = TimeText.nowMillis()
        state = Machine.settle(found.state, now: time)
        loaded = true
        // 開機對齊：系統裡排的通知要跟現在的狀態一致
        follow(force: true)
        refreshNotif()
    }

    /// 每一拍：休息到點沒按也回待機（或自動開始下一顆）；到點那一刻換成鈴響。
    func tick() {
        let time = TimeText.nowMillis()
        if loaded {
            let settled = Machine.settle(state, now: time)
            if settled.current != state.current { commit(settled) }
            let next = Machine.phaseOf(state, now: time)
            if next != phase { enter(next) }
        }
        now = time
    }

    /// 換態：計時中鎖在主畫面，人可能在別頁（休息完自動開始），一樣拉回來。
    private func enter(_ next: Phase) {
        phase = next
        if next == .focus || next == .bell { page = .home }
    }

    /// 狀態改了之後：算現在哪一態、對齊通知。
    private func follow(force: Bool = false) {
        let time = TimeText.nowMillis()
        let next = Machine.phaseOf(state, now: time)
        if next != phase { enter(next) }
        now = time
        notifier.sync(state, now: time, force: force)
    }

    /// 現在這一態（過期的休息先收掉）。動作都從這份算新狀態。
    func settled() -> AppState {
        Machine.settle(state, now: TimeText.nowMillis())
    }

    /// 換上新狀態並存檔。本機檔讀不懂時不存（壞檔不蓋）。
    func commit(_ next: AppState) {
        state = next
        if !unreadable { saveFailed = !file.save(next) }
        follow()
    }

    /// 匯入、清空：整份換掉。這是唯一准蓋掉「讀不懂的本機檔」的路。
    func replaceAll(_ next: AppState) {
        unreadable = false
        state = next
        saveFailed = !file.save(next)
        follow(force: true)
    }

    /// 回到前景：時鐘立刻重算（鎖屏放過到點回來不閃計時中）；權限可能剛從系統設定改回來。
    func becameActive() {
        tick()
        refreshNotif()
    }

    /// 權限從沒允許翻成允許時，要重排一次通知。
    private func refreshNotif() {
        Task {
            let status = await notifier.status()
            notif = status
            let isOff = status != .granted
            if !isOff, notifWasOff { notifier.sync(state, now: TimeText.nowMillis(), force: true) }
            notifWasOff = isOff
        }
    }
}
