import Foundation

/// iCloud 帳號的代號。系統給的 token 不透明，只保證能封存、能用 isEqual 比，
/// 沒保證同一個帳號每次封存的位元組都一樣：所以存封存本身，比的時候解開再比。
enum CloudToken {
    /// 跟 known 解開的是同一個就回 known，不然回這個 token 封存成的字。
    static func code(_ token: NSObjectProtocol, like known: String?) throws -> String {
        if let known, let old = opened(known), token.isEqual(old) {
            return known
        }
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: false
        )
        return data.base64EncodedString()
    }

    /// 解不開的當成不同的帳號。token 的類別沒有公開，所以不能用安全解碼；
    /// 解的是自己沙盒裡、自己寫的帳本。
    private static func opened(_ code: String) -> Any? {
        guard let data = Data(base64Encoded: code),
              let reader = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        reader.requiresSecureCoding = false
        reader.decodingFailurePolicy = .setErrorAndReturn
        defer { reader.finishDecoding() }
        return reader.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
    }
}

/// 等 iCloud 讓路（NSFileCoordinator）之後才做的事。只准在 CloudLine 上叫。
/// 等的時候可能很久、也可能被系統暫停，回來時 Apple 帳號已經換了：
/// 所以 check 一定在輪到自己的那一刻才跑，不是在等之前。
enum CloudAccess {
    static func read(
        _ url: URL,
        _ ticket: CloudTicket,
        check: () throws -> Void
    ) throws -> Data {
        var problem: NSError?
        var result: Result<Data, Error>?
        try ticket.coordinator().coordinate(
            readingItemAt: url,
            options: .withoutChanges,
            error: &problem
        ) { place in
            result = Result<Data, Error> {
                try check()
                return try contents(place)
            }
        }
        return try finish(result, problem)
    }

    /// 資料夾要先在（makeFolder）：不在就是被刪掉了，寫不進去就丟錯。
    static func write(
        _ data: Data,
        to url: URL,
        _ ticket: CloudTicket,
        check: () throws -> Void
    ) throws {
        var problem: NSError?
        var result: Result<Void, Error>?
        try ticket.coordinator().coordinate(
            writingItemAt: url,
            options: .forReplacing,
            error: &problem
        ) { place in
            result = Result<Void, Error> {
                try check()
                try data.write(to: place, options: .atomic)
            }
        }
        try finish(result, problem)
    }

    static func makeFolder(
        _ url: URL,
        _ ticket: CloudTicket,
        check: () throws -> Void
    ) throws {
        var problem: NSError?
        var result: Result<Void, Error>?
        try ticket.coordinator().coordinate(
            writingItemAt: url,
            options: [],
            error: &problem
        ) { place in
            result = Result<Void, Error> {
                try check()
                try FileManager.default.createDirectory(
                    at: place,
                    withIntermediateDirectories: true
                )
            }
        }
        try finish(result, problem)
    }

    /// 刪完還在就不算刪成。
    static func erase(
        _ url: URL,
        _ ticket: CloudTicket,
        check: () throws -> Void
    ) throws {
        var problem: NSError?
        var result: Result<Void, Error>?
        try ticket.coordinator().coordinate(
            writingItemAt: url,
            options: .forDeleting,
            error: &problem
        ) { place in
            result = Result<Void, Error> {
                try check()
                try FileManager.default.removeItem(at: place)
                if FileManager.default.fileExists(atPath: place.path) {
                    throw CloudError.stopped
                }
            }
        }
        try finish(result, problem)
    }

    /// 先看大小再讀：不讓一個怪檔把記憶體吃光（安全標準 I3）。
    private static func contents(_ url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= Params.importMaxBytes else { throw CloudError.tooBig }
        return try Data(contentsOf: url)
    }

    /// 協調器自己的錯、裡面那件事的錯，有一個就丟出去；裡面那件事根本沒輪到也算錯。
    private static func finish<T>(_ result: Result<T, Error>?, _ problem: NSError?) throws -> T {
        if let problem {
            throw problem
        }
        guard let result else { throw CloudError.stopped }
        return try result.get()
    }
}
