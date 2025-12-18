import Foundation
import LLMClient
import LLMTool

// MARK: - UtilityToolKit

/// 一般的なユーティリティツールを提供するToolKit
///
/// 日時取得、計算、UUID生成など、汎用的なユーティリティ機能を提供します。
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     UtilityToolKit()
/// }
/// ```
///
/// ## 提供されるツール
///
/// - `get_current_time`: 現在時刻を指定フォーマットで取得
/// - `calculate`: 基本的な数学計算を実行
/// - `generate_uuid`: ランダムなUUIDを生成
/// - `sleep`: 指定時間待機
public final class UtilityToolKit: ToolKit, @unchecked Sendable {
    // MARK: - Properties

    public let name: String = "utility"

    /// タイムゾーン
    private let timeZone: TimeZone

    // MARK: - Initialization

    /// UtilityToolKitを作成
    ///
    /// - Parameter timeZone: 時刻取得に使用するタイムゾーン（デフォルト: システムのローカル）
    public init(timeZone: TimeZone = .current) {
        self.timeZone = timeZone
    }

    // MARK: - ToolKit Protocol

    public var tools: [any Tool] {
        [
            getCurrentTimeTool,
            calculateTool,
            generateUUIDTool,
            sleepTool
        ]
    }

    // MARK: - Tool Definitions

    /// get_current_time ツール
    private var getCurrentTimeTool: BuiltInTool {
        BuiltInTool(
            name: "get_current_time",
            description: "Get the current time in a specified format and timezone",
            inputSchema: .object(
                properties: [
                    "format": .string(
                        description: "Date format string (e.g., 'yyyy-MM-dd HH:mm:ss', 'ISO8601'). Default is ISO8601."
                    ),
                    "timezone": .string(
                        description: "Timezone identifier (e.g., 'UTC', 'Asia/Tokyo', 'America/New_York'). Default is local timezone."
                    )
                ],
                required: []
            ),
            annotations: ToolAnnotations(
                title: "Get Current Time",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { [timeZone] data in
            let input = try JSONDecoder().decode(GetCurrentTimeInput.self, from: data)

            // タイムゾーンの決定
            let tz: TimeZone
            if let tzIdentifier = input.timezone,
               let parsedTZ = TimeZone(identifier: tzIdentifier) {
                tz = parsedTZ
            } else {
                tz = timeZone
            }

            // フォーマットの決定
            let formatString = input.format ?? "ISO8601"
            let date = Date()

            let formattedDate: String
            if formatString == "ISO8601" {
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = tz
                formattedDate = formatter.string(from: date)
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = formatString
                formatter.timeZone = tz
                formattedDate = formatter.string(from: date)
            }

            let result = TimeResult(
                time: formattedDate,
                timezone: tz.identifier,
                format: formatString
            )
            let output = try JSONEncoder().encode(result)
            return .json(output)
        }
    }

    /// calculate ツール
    private var calculateTool: BuiltInTool {
        BuiltInTool(
            name: "calculate",
            description: "Perform basic mathematical calculations",
            inputSchema: .object(
                properties: [
                    "operation": .string(
                        description: "Mathematical operation: 'add', 'subtract', 'multiply', 'divide', 'power', 'sqrt', 'abs', 'round', 'floor', 'ceil'"
                    ),
                    "a": .number(description: "First operand (required for all operations)"),
                    "b": .number(description: "Second operand (required for binary operations like add, subtract, multiply, divide, power)")
                ],
                required: ["operation", "a"]
            ),
            annotations: ToolAnnotations(
                title: "Calculate",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { data in
            let input = try JSONDecoder().decode(CalculateInput.self, from: data)

            let result: Double
            switch input.operation.lowercased() {
            case "add", "+":
                guard let b = input.b else {
                    throw UtilityToolKitError.missingOperand(operation: input.operation, operand: "b")
                }
                result = input.a + b

            case "subtract", "-":
                guard let b = input.b else {
                    throw UtilityToolKitError.missingOperand(operation: input.operation, operand: "b")
                }
                result = input.a - b

            case "multiply", "*":
                guard let b = input.b else {
                    throw UtilityToolKitError.missingOperand(operation: input.operation, operand: "b")
                }
                result = input.a * b

            case "divide", "/":
                guard let b = input.b else {
                    throw UtilityToolKitError.missingOperand(operation: input.operation, operand: "b")
                }
                guard b != 0 else {
                    throw UtilityToolKitError.divisionByZero
                }
                result = input.a / b

            case "power", "pow", "^":
                guard let b = input.b else {
                    throw UtilityToolKitError.missingOperand(operation: input.operation, operand: "b")
                }
                result = pow(input.a, b)

            case "sqrt":
                guard input.a >= 0 else {
                    throw UtilityToolKitError.invalidInput(message: "Cannot calculate square root of negative number")
                }
                result = sqrt(input.a)

            case "abs":
                result = abs(input.a)

            case "round":
                result = round(input.a)

            case "floor":
                result = floor(input.a)

            case "ceil":
                result = ceil(input.a)

            default:
                throw UtilityToolKitError.unknownOperation(input.operation)
            }

            let output = CalculateResult(
                operation: input.operation,
                a: input.a,
                b: input.b,
                result: result
            )
            let encoded = try JSONEncoder().encode(output)
            return .json(encoded)
        }
    }

    /// generate_uuid ツール
    private var generateUUIDTool: BuiltInTool {
        BuiltInTool(
            name: "generate_uuid",
            description: "Generate a random UUID (Universally Unique Identifier)",
            inputSchema: .object(
                properties: [
                    "format": .string(
                        description: "Output format: 'standard' (with hyphens), 'compact' (no hyphens), 'uppercase'. Default is 'standard'."
                    ),
                    "count": .integer(
                        description: "Number of UUIDs to generate (1-100). Default is 1."
                    )
                ],
                required: []
            ),
            annotations: ToolAnnotations(
                title: "Generate UUID",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { data in
            let input = try JSONDecoder().decode(GenerateUUIDInput.self, from: data)

            let format = input.format ?? "standard"
            let count = min(max(input.count ?? 1, 1), 100)

            let uuids: [String] = (0..<count).map { _ in
                let uuid = UUID()
                switch format.lowercased() {
                case "compact":
                    return uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
                case "uppercase":
                    return uuid.uuidString
                default: // standard
                    return uuid.uuidString.lowercased()
                }
            }

            let result = GenerateUUIDResult(uuids: uuids, format: format, count: count)
            let output = try JSONEncoder().encode(result)
            return .json(output)
        }
    }

    /// sleep ツール
    private var sleepTool: BuiltInTool {
        BuiltInTool(
            name: "sleep",
            description: "Wait for a specified duration",
            inputSchema: .object(
                properties: [
                    "seconds": .number(
                        description: "Duration to wait in seconds (0.001 - 60)"
                    )
                ],
                required: ["seconds"]
            ),
            annotations: ToolAnnotations(
                title: "Sleep",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { data in
            let input = try JSONDecoder().decode(SleepInput.self, from: data)

            // 範囲を制限（1ms〜60秒）
            let duration = min(max(input.seconds, 0.001), 60.0)
            let nanoseconds = UInt64(duration * 1_000_000_000)

            try await Task.sleep(nanoseconds: nanoseconds)

            let result = SleepResult(requestedSeconds: input.seconds, actualSeconds: duration)
            let output = try JSONEncoder().encode(result)
            return .json(output)
        }
    }
}

// MARK: - Input Types

private struct GetCurrentTimeInput: Codable {
    var format: String?
    var timezone: String?
}

private struct CalculateInput: Codable {
    var operation: String
    var a: Double
    var b: Double?
}

private struct GenerateUUIDInput: Codable {
    var format: String?
    var count: Int?
}

private struct SleepInput: Codable {
    var seconds: Double
}

// MARK: - Result Types

private struct TimeResult: Codable {
    var time: String
    var timezone: String
    var format: String
}

private struct CalculateResult: Codable {
    var operation: String
    var a: Double
    var b: Double?
    var result: Double
}

private struct GenerateUUIDResult: Codable {
    var uuids: [String]
    var format: String
    var count: Int
}

private struct SleepResult: Codable {
    var requestedSeconds: Double
    var actualSeconds: Double
}

// MARK: - Errors

/// UtilityToolKitのエラー
public enum UtilityToolKitError: Error, LocalizedError {
    case missingOperand(operation: String, operand: String)
    case divisionByZero
    case invalidInput(message: String)
    case unknownOperation(String)

    public var errorDescription: String? {
        switch self {
        case .missingOperand(let operation, let operand):
            return "Operation '\(operation)' requires operand '\(operand)'"
        case .divisionByZero:
            return "Division by zero is not allowed"
        case .invalidInput(let message):
            return message
        case .unknownOperation(let operation):
            return "Unknown operation: \(operation)"
        }
    }
}
