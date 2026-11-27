import AppIntents

/// 卡片上的「開始」：同一個標籤、同樣長度開始下一顆。
/// LiveActivityIntent 由系統在 app 的行程裡跑（app 沒開時在背景叫醒它），所以 perform 走 app 那邊的 LiveStart。
/// 擴充也要編這個檔（按鈕畫在擴充裡）；擴充那邊的 LiveStart 是空的，系統不會在擴充裡叫 perform。
struct StartNextIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "開始下一顆"
    /// 只給卡片上的按鈕用，捷徑裡不列
    static let isDiscoverable = false

    @Parameter(title: "標籤")
    var typeId: String

    init() {}

    init(typeId: String) {
        self.typeId = typeId
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveStart.run(typeId: typeId)
        return .result()
    }
}
