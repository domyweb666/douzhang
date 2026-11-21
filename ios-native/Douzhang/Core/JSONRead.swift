import Foundation

typealias JSONObject = [String: Any]

/// 讀外部來的 JSON 欄位：型別不對就當沒有。來源不可信（舊版 PWA、手改過的檔）。
enum JSONRead {
    /// JSONSerialization 把 true／false 跟數字都給成 NSNumber，要自己分：數字 0、1 不算布林。
    private static func isBoolean(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    static func bool(_ value: Any?, or fallback: Bool) -> Bool {
        guard isBoolean(value), let number = value as? NSNumber else { return fallback }
        return number.boolValue
    }

    static func number(_ value: Any?) -> Double? {
        guard !isBoolean(value), let number = value as? NSNumber else { return nil }
        let double = number.doubleValue
        return double.isFinite ? double : nil
    }

    /// 整數才收：帶小數的、大到裝不下的都當沒有。
    static func int(_ value: Any?) -> Int? {
        number(value).flatMap { Int(exactly: $0) }
    }

    static func string(_ value: Any?) -> String? {
        value as? String
    }

    static func object(_ value: Any?) -> JSONObject? {
        value as? JSONObject
    }

    /// 陣列裡是物件的那幾個；不是陣列回空的。
    static func objects(_ value: Any?) -> [JSONObject] {
        (value as? [Any] ?? []).compactMap { $0 as? JSONObject }
    }

    /// 陣列裡是字串的那幾個。會直接畫上畫面的字只留字串。
    static func strings(_ value: Any?) -> [String] {
        (value as? [Any] ?? []).compactMap { $0 as? String }
    }
}
