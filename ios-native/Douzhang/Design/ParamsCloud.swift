import Foundation

/// iCloud 同步的數字。
extension Params {
    /// 讀雲端檔收的分鐘：一天以內
    static let cloudMinutes = 0.0 ... 1440.0
    /// 標籤的長度：0 分的標籤一開始就鈴響
    static let cloudTagMinutes = 1.0 ... 1440.0
    /// 作廢在第幾分鐘：一年以內，超出的夾住
    static let cloudVoidMinutes = 0 ... 525_600
    /// 讀雲端檔收的時刻：1970 到 2096 年的毫秒
    static let cloudTimes = 0.0 ... 4e12

    // MARK: 搬檔案（App/Cloud*）

    /// 找容器、讀、寫、刪，每一步最多等幾秒
    static let cloudStepSeconds = 10.0
    /// 第一份清單最多等幾秒
    static let cloudListSeconds = 15.0
    /// 整次拉取最多幾秒，到了就先合已經讀到的，剩的下一趟接著讀
    static let cloudPullSeconds = 60.0
    /// 讀不到的檔隔多久再讀
    static let cloudRestSeconds = 180.0
    /// 存檔之後停手多久才傳
    static let cloudPushSeconds = 2.0
    /// 雲端有動靜，等多久合併成一次拉
    static let cloudNoticeSeconds = 1.5
    /// iCloud 沒開持續多久才說
    static let cloudOffSeconds = 10.0
    /// 看過東西的雲端空了：隔多久再看一次，還是空的才問
    static let cloudEmptySeconds = 10.0
    /// 在背景合併時本機又變了，重合幾次後改在主執行緒合
    static let cloudMergeTries = 2
}
