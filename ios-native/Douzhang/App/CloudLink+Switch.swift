import Foundation

/// 開關與停下來問：設定頁與確認框叫的。
extension CloudLink {
    // MARK: 開關

    /// 親手打開：第一次就放進現在登入的 iCloud，不用再問。上次沒刪成的也不刪了。
    func turnOn() {
        erasePending = nil
        setOn(true)
        consent = .any
        requestPull()
    }

    /// 關掉：馬上停。要不要連雲端一起刪，畫面接著問，要刪就叫 eraseCloud。
    func turnOff() {
        stop()
        setOn(false)
    }

    // MARK: 停下來問

    var asking: Bool {
        question != nil
    }

    /// 停住，等使用者回答。不合也不傳。identity 是問的時候登入的那個。
    func ask(_ why: CloudQuestion, about identity: String) {
        stop()
        paused = true
        consent = .none
        askedAbout = identity
        question = why
        asks += 1
    }

    /// 放進去：答應的只有問的那一個 iCloud，拉的時候才換編號、當成第一次合。
    /// 框開著的時候又換了帳號，就再問一次。
    func adopt() {
        guard question != nil else { return }
        question = nil
        paused = false
        consent = askedAbout.map { CloudConsent.only($0) } ?? .none
        requestPull()
    }

    /// 先不要：這次打開不再問，下次打開再問。
    func decline() {
        guard question != nil else { return }
        question = nil
        problem = .paused
    }
}
