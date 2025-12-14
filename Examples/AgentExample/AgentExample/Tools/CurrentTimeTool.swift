//
//  CurrentTimeTool.swift
//  AgentExample
//
//  現在時刻ツール
//

import Foundation
import LLMStructuredOutputs

/// 現在時刻ツール
///
/// 指定されたタイムゾーンの現在時刻を取得します。
@Tool("現在の日時を取得します。タイムゾーンを指定することで、世界各地の時刻を確認できます。", name: "get_current_time")
struct CurrentTimeTool {
    @ToolArgument("タイムゾーン識別子（例: Asia/Tokyo, America/New_York, Europe/London）。省略時はシステムのタイムゾーンを使用。")
    var timezone: String?

    func call() async throws -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日（E）HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")

        let now = Date()
        var timezoneInfo: String

        if let tzIdentifier = timezone, !tzIdentifier.isEmpty {
            if let tz = TimeZone(identifier: tzIdentifier) {
                formatter.timeZone = tz
                timezoneInfo = tzIdentifier

                // UTC からのオフセットも表示
                let offsetSeconds = tz.secondsFromGMT(for: now)
                let offsetHours = offsetSeconds / 3600
                let offsetMinutes = abs(offsetSeconds % 3600) / 60
                let offsetString = String(format: "UTC%+d:%02d", offsetHours, offsetMinutes)
                timezoneInfo += "（\(offsetString)）"
            } else {
                // 無効なタイムゾーンの場合
                return "無効なタイムゾーン「\(tzIdentifier)」です。Asia/Tokyo, America/New_York などの形式で指定してください。"
            }
        } else {
            formatter.timeZone = TimeZone.current
            timezoneInfo = TimeZone.current.identifier

            let offsetSeconds = TimeZone.current.secondsFromGMT(for: now)
            let offsetHours = offsetSeconds / 3600
            let offsetMinutes = abs(offsetSeconds % 3600) / 60
            let offsetString = String(format: "UTC%+d:%02d", offsetHours, offsetMinutes)
            timezoneInfo += "（\(offsetString)）"
        }

        let timeString = formatter.string(from: now)

        return """
        現在時刻: \(timeString)
        タイムゾーン: \(timezoneInfo)
        """
    }
}

// MARK: - Helper Extension

extension CurrentTimeTool {
    /// よく使われるタイムゾーンの一覧
    static let commonTimezones: [(identifier: String, name: String)] = [
        ("Asia/Tokyo", "日本標準時"),
        ("America/New_York", "アメリカ東部"),
        ("America/Los_Angeles", "アメリカ太平洋"),
        ("Europe/London", "イギリス"),
        ("Europe/Paris", "中央ヨーロッパ"),
        ("Asia/Shanghai", "中国"),
        ("Asia/Singapore", "シンガポール"),
        ("Australia/Sydney", "オーストラリア東部")
    ]
}
