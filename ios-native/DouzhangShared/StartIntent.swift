import AppIntents

/// 從捷徑、Siri、動作按鈕、控制中心開始一顆：打開番茄帳，照設定選中的標籤開始。
/// 這個檔的字不放 Words：系統在編譯時讀這些字，只認直接寫在這裡的。
/// app 與擴充都要編進去，控制中心那顆才打得開 app；perform 在 app 的程序裡跑。
struct StartTomatoIntent: AppIntent {
    static let title: LocalizedStringResource = "開始一顆番茄"
    static let description = IntentDescription("打開番茄帳，用選好的標籤開始一顆。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        StartAsk.shared.ask()
        return .result()
    }
}

/// 外面要求開始一顆的那張便條。app 可能還沒讀完檔就被叫，所以先記著，殼的下一拍（讀完檔之後）才拿。
@MainActor
final class StartAsk {
    static let shared = StartAsk()
    private var isAsked = false

    func ask() {
        isAsked = true
    }

    /// 拿走就沒了：連按兩次也只開始一顆。
    func take() -> Bool {
        defer { isAsked = false }
        return isAsked
    }
}
