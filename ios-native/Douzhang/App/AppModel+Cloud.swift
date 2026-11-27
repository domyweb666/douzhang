import Foundation

/// iCloud 同步的接頭：CloudLink 只認得 CloudHost 這三樣，什麼時候拉、什麼時候傳由它決定。
extension AppModel: CloudHost {
    /// 讀不懂的本機檔、沒存進去的狀態都不准合、不准傳（準則 5-19）。
    var cloudState: AppState? {
        loaded && !unreadable && !saveFailed ? state : nil
    }

    /// 換上跟別台合好的整份。不 settle、不震：進行中那顆與偏好是原樣，合併不碰。
    /// 當場寫完：合完接著就傳（CloudLink.take 看 cloudState），存不進去要在那之前就知道。
    func takeCloud(_ merged: AppState) {
        jarSeen = jarSeenAfter(merged)
        commit(merged)
        flushSaves()
    }

    func backUpForCloud() -> Bool {
        backUpSaved()
    }
}

/// 合併時的番茄堆：別台來的當成早就看過、直接躺好；這台自己收的那顆照樣從上面掉下來。
extension AppModel {
    /// 番茄堆照這個順序放：這週的照時間排，這台最近收的那顆排最後（番茄堆只掉最後一顆）。
    /// 同一週換日清單不變，番茄堆不重新安置；跨到下週一清單變空，番茄堆跟著清空。
    var jarBeans: [Bean] {
        JarWeek.beans(state, todayKey: todayKey, fresh: jarFresh)
    }

    /// 合完之後「上次看到幾顆」：扣掉這台收了、還沒掉下來的。
    /// 待機而且都掉完了是 nil，番茄堆當場照新的躺好。
    private func jarSeenAfter(_ merged: AppState) -> Int? {
        let before = JarWeek.count(state, todayKey: todayKey)
        let after = JarWeek.count(merged, todayKey: todayKey)
        let unseen = max(0, before - (jarSeen ?? before))
        if phase == .idle, unseen == 0 {
            return nil
        }
        return max(0, after - unseen)
    }
}

extension CloudLink {
    /// app 用的那一個。開發版截圖走查不接真的 iCloud（正式 build 一律是真的）。
    static var standard: CloudLink {
        let drive: CloudDrive = LaunchOptions.dataFolder == nil ? ICloudDrive() : NoCloudDrive()
        return CloudLink(drive: drive, ledgerFile: .standard)
    }
}

/// 不接 iCloud：怎麼叫都是沒登入。
private struct NoCloudDrive: CloudDrive {
    func identity() async throws -> String? {
        nil
    }

    func files() async throws -> [CloudFile] {
        throw CloudError.off
    }

    func download(_: String) async {}

    func read(_: String, for _: String) async throws -> Data {
        throw CloudError.off
    }

    func write(_: String, _: Data, for _: String) async throws {
        throw CloudError.off
    }

    func erase(for _: String) async throws {
        throw CloudError.off
    }

    @MainActor
    func watch(_: @escaping @MainActor (CloudNotice) -> Void) {}

    @MainActor
    func unwatch() {}
}
