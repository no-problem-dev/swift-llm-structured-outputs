import Foundation
import LLMClient
import LLMTool

// MARK: - DateTimeTool

/// 現在の日時取得または日時計算を行うツール
///
/// 以下の日時操作を提供します：
/// - 様々なフォーマットでの現在日時取得
/// - 時間間隔の加算・減算
/// - 日付間の差分計算
/// - 異なるスタイルでの日時フォーマット
///
/// ## 適用されたベストプラクティス
/// - **ポカヨケ**: 操作は enum を使用して無効な状態を防止
/// - **明確な説明**: 各パラメータの目的と有効な値を説明
/// - **エッジケース処理**: タイムゾーン変換やフォーマットのエッジケースを処理
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     DateTimeTool()
/// }
/// ```
@Tool(
    "Get current date/time or perform date arithmetic. " +
    "Use 'now' to get current time, 'add' to add duration to a date, " +
    "'subtract' to subtract duration, 'difference' to calculate time between two dates, " +
    "or 'format' to convert a date to a specific format.",
    name: "date_time"
)
public struct DateTimeTool {

    /// The operation to perform
    @ToolArgument(
        "The operation type: 'now' (get current time), 'add' (add duration to date), " +
        "'subtract' (subtract duration from date), 'difference' (time between two dates), " +
        "or 'format' (format a date string)"
    )
    public var operation: String

    /// The base date for calculations (ISO8601 format: YYYY-MM-DDTHH:MM:SS)
    @ToolArgument(
        "The date to operate on in ISO8601 format (e.g., '2024-03-15T10:30:00'). " +
        "Required for all operations except 'now'."
    )
    public var date: String?

    /// Second date for difference calculation
    @ToolArgument(
        "The second date for 'difference' operation in ISO8601 format. " +
        "The result shows (date - second_date)."
    )
    public var secondDate: String?

    /// Duration value for add/subtract operations
    @ToolArgument(
        "The numeric value of duration for 'add' or 'subtract' operations. " +
        "Example: 5 (for 5 days, hours, etc. depending on duration_unit)."
    )
    public var durationValue: Int?

    /// Unit for duration (days, hours, minutes, seconds)
    @ToolArgument(
        "The unit for duration: 'days', 'hours', 'minutes', or 'seconds'. " +
        "Used with 'add' and 'subtract' operations."
    )
    public var durationUnit: String?

    /// Output format style
    @ToolArgument(
        "Output format: 'iso8601' (default), 'readable' (human-friendly), " +
        "'date_only' (YYYY-MM-DD), 'time_only' (HH:MM:SS), or 'unix' (timestamp)."
    )
    public var outputFormat: String?

    /// Timezone for the operation
    @ToolArgument(
        "Timezone identifier (e.g., 'UTC', 'America/New_York', 'Asia/Tokyo'). " +
        "Defaults to UTC."
    )
    public var timezone: String?

    public func call() async throws -> String {
        let tz = TimeZone(identifier: timezone ?? "UTC") ?? .current
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = tz

        switch operation.lowercased() {
        case "now":
            let now = Date()
            return formatDate(now, format: outputFormat, timezone: tz)

        case "add", "subtract":
            guard let dateStr = date else {
                return "Error: 'date' parameter is required for '\(operation)' operation."
            }
            guard let baseDate = parseDate(dateStr) else {
                return "Error: Invalid date format. Use ISO8601 format (e.g., '2024-03-15T10:30:00')."
            }
            guard let value = durationValue else {
                return "Error: 'duration_value' is required for '\(operation)' operation."
            }
            guard let unit = durationUnit else {
                return "Error: 'duration_unit' is required for '\(operation)' operation."
            }

            let multiplier = operation.lowercased() == "subtract" ? -1 : 1
            guard let result = addDuration(to: baseDate, value: value * multiplier, unit: unit) else {
                return "Error: Invalid duration_unit '\(unit)'. Use 'days', 'hours', 'minutes', or 'seconds'."
            }

            return formatDate(result, format: outputFormat, timezone: tz)

        case "difference":
            guard let dateStr = date else {
                return "Error: 'date' parameter is required for 'difference' operation."
            }
            guard let secondDateStr = secondDate else {
                return "Error: 'second_date' parameter is required for 'difference' operation."
            }
            guard let date1 = parseDate(dateStr) else {
                return "Error: Invalid 'date' format. Use ISO8601 format."
            }
            guard let date2 = parseDate(secondDateStr) else {
                return "Error: Invalid 'second_date' format. Use ISO8601 format."
            }

            return calculateDifference(from: date2, to: date1)

        case "format":
            guard let dateStr = date else {
                return "Error: 'date' parameter is required for 'format' operation."
            }
            guard let parsedDate = parseDate(dateStr) else {
                return "Error: Invalid date format. Use ISO8601 format."
            }

            return formatDate(parsedDate, format: outputFormat, timezone: tz)

        default:
            return "Error: Unknown operation '\(operation)'. " +
                   "Valid operations: 'now', 'add', 'subtract', 'difference', 'format'."
        }
    }

    // MARK: - プライベートヘルパー

    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) {
            return date
        }

        // Try date only format
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: string)
    }

    private func formatDate(_ date: Date, format: String?, timezone: TimeZone) -> String {
        let fmt = format?.lowercased() ?? "iso8601"

        switch fmt {
        case "iso8601":
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = timezone
            return formatter.string(from: date)

        case "readable":
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .long
            formatter.timeZone = timezone
            return formatter.string(from: date)

        case "date_only":
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = timezone
            return formatter.string(from: date)

        case "time_only":
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            formatter.timeZone = timezone
            return formatter.string(from: date)

        case "unix":
            return String(Int(date.timeIntervalSince1970))

        default:
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = timezone
            return formatter.string(from: date)
        }
    }

    private func addDuration(to date: Date, value: Int, unit: String) -> Date? {
        var components = DateComponents()

        switch unit.lowercased() {
        case "days":
            components.day = value
        case "hours":
            components.hour = value
        case "minutes":
            components.minute = value
        case "seconds":
            components.second = value
        default:
            return nil
        }

        return Calendar.current.date(byAdding: components, to: date)
    }

    private func calculateDifference(from start: Date, to end: Date) -> String {
        let components = Calendar.current.dateComponents(
            [.day, .hour, .minute, .second],
            from: start,
            to: end
        )

        var parts: [String] = []

        if let days = components.day, days != 0 {
            parts.append("\(days) day\(abs(days) == 1 ? "" : "s")")
        }
        if let hours = components.hour, hours != 0 {
            parts.append("\(hours) hour\(abs(hours) == 1 ? "" : "s")")
        }
        if let minutes = components.minute, minutes != 0 {
            parts.append("\(minutes) minute\(abs(minutes) == 1 ? "" : "s")")
        }
        if let seconds = components.second, seconds != 0 {
            parts.append("\(seconds) second\(abs(seconds) == 1 ? "" : "s")")
        }

        if parts.isEmpty {
            return "0 seconds (dates are identical)"
        }

        let totalSeconds = Int(end.timeIntervalSince(start))
        let direction = totalSeconds >= 0 ? "" : " (negative - second_date is after date)"

        return parts.joined(separator: ", ") + direction
    }
}
