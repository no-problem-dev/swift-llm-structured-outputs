import Foundation
import LLMClient
import LLMTool

// MARK: - TextAnalysisTool

/// テキストの各種メトリクスやパターンを分析するツール
///
/// 以下のテキスト分析機能を提供します：
/// - 文字数、単語数、文数のカウント
/// - 正規表現によるパターンマッチング
/// - テキストの抽出と変換
/// - 基本的なテキスト統計
///
/// ## 適用されたベストプラクティス
/// - **明確な操作タイプ**: 各操作が明確に定義されている
/// - **安全な正規表現処理**: 使用前にパターンを検証
/// - **包括的なエラーメッセージ**: 正しい使用方法をガイド
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     TextAnalysisTool()
/// }
/// ```
@Tool(
    "Analyze text for metrics (count, length), find patterns using regex, " +
    "extract matches, or transform text. " +
    "Use 'stats' for counts, 'find' for pattern search, " +
    "'extract' for pattern extraction, 'replace' for substitution.",
    name: "text_analysis"
)
public struct TextAnalysisTool {

    /// The operation to perform
    @ToolArgument(
        "Operation type: 'stats' (get character/word/sentence counts), " +
        "'find' (search for pattern, returns true/false and positions), " +
        "'extract' (extract all pattern matches), " +
        "'replace' (replace pattern matches), " +
        "'split' (split text by delimiter), " +
        "'trim' (remove whitespace), " +
        "'substring' (extract portion of text)."
    )
    public var operation: String

    /// The input text to analyze
    @ToolArgument(
        "The text to analyze or transform."
    )
    public var text: String

    /// Pattern for regex operations
    @ToolArgument(
        "Regular expression pattern for 'find', 'extract', or 'replace' operations. " +
        "Uses Swift/ICU regex syntax. Example: '\\\\d+' for numbers, '\\\\b\\\\w+@\\\\w+\\\\.\\\\w+\\\\b' for emails."
    )
    public var pattern: String?

    /// Replacement string for replace operation
    @ToolArgument(
        "Replacement string for 'replace' operation. " +
        "Use $0 for full match, $1, $2 for capture groups."
    )
    public var replacement: String?

    /// Delimiter for split operation
    @ToolArgument(
        "Delimiter for 'split' operation. Default is space. " +
        "Can be a string or regex pattern."
    )
    public var delimiter: String?

    /// Start index for substring operation
    @ToolArgument(
        "Start index (0-based) for 'substring' operation."
    )
    public var startIndex: Int?

    /// Length for substring operation
    @ToolArgument(
        "Length for 'substring' operation. " +
        "If omitted, extracts to the end of the text."
    )
    public var length: Int?

    /// Case sensitivity flag
    @ToolArgument(
        "Whether pattern matching is case-sensitive. Default is true."
    )
    public var caseSensitive: Bool?

    public func call() async throws -> String {
        switch operation.lowercased() {
        case "stats":
            return analyzeStats()

        case "find":
            guard let pattern = pattern else {
                return "Error: 'pattern' parameter is required for 'find' operation."
            }
            return findPattern(pattern)

        case "extract":
            guard let pattern = pattern else {
                return "Error: 'pattern' parameter is required for 'extract' operation."
            }
            return extractMatches(pattern)

        case "replace":
            guard let pattern = pattern else {
                return "Error: 'pattern' parameter is required for 'replace' operation."
            }
            guard let replacement = replacement else {
                return "Error: 'replacement' parameter is required for 'replace' operation."
            }
            return replacePattern(pattern, with: replacement)

        case "split":
            return splitText()

        case "trim":
            return text.trimmingCharacters(in: .whitespacesAndNewlines)

        case "substring":
            return extractSubstring()

        default:
            return "Error: Unknown operation '\(operation)'. " +
                   "Valid operations: 'stats', 'find', 'extract', 'replace', 'split', 'trim', 'substring'."
        }
    }

    // MARK: - Private Helpers

    private func analyzeStats() -> String {
        let characterCount = text.count
        let characterCountNoSpaces = text.filter { !$0.isWhitespace }.count

        // Word count: split by whitespace and filter empty
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let wordCount = words.count

        // Sentence count: rough estimate based on sentence-ending punctuation
        let sentencePattern = "[.!?]+"
        let sentenceCount: Int
        if let regex = try? NSRegularExpression(pattern: sentencePattern) {
            let range = NSRange(text.startIndex..., in: text)
            sentenceCount = max(1, regex.numberOfMatches(in: text, range: range))
        } else {
            sentenceCount = 1
        }

        // Line count
        let lineCount = text.components(separatedBy: .newlines).count

        // Paragraph count (separated by blank lines)
        let paragraphs = text.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let paragraphCount = max(1, paragraphs.count)

        // Average word length
        let avgWordLength: Double
        if wordCount > 0 {
            let totalCharacters = words.reduce(0) { $0 + $1.count }
            avgWordLength = Double(totalCharacters) / Double(wordCount)
        } else {
            avgWordLength = 0
        }

        return """
        Text Statistics:
        - Characters (total): \(characterCount)
        - Characters (no spaces): \(characterCountNoSpaces)
        - Words: \(wordCount)
        - Sentences (approx): \(sentenceCount)
        - Lines: \(lineCount)
        - Paragraphs: \(paragraphCount)
        - Avg word length: \(String(format: "%.1f", avgWordLength))
        """
    }

    private func findPattern(_ pattern: String) -> String {
        do {
            var options: NSRegularExpression.Options = []
            if caseSensitive == false {
                options.insert(.caseInsensitive)
            }

            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)

            if matches.isEmpty {
                return "No matches found for pattern '\(pattern)'."
            }

            var result = "Found \(matches.count) match(es):\n"
            for (index, match) in matches.prefix(20).enumerated() {
                if let matchRange = Range(match.range, in: text) {
                    let matchText = String(text[matchRange])
                    let startPos = text.distance(from: text.startIndex, to: matchRange.lowerBound)
                    result += "  \(index + 1). '\(matchText)' at position \(startPos)\n"
                }
            }

            if matches.count > 20 {
                result += "  ... and \(matches.count - 20) more matches"
            }

            return result
        } catch {
            return "Error: Invalid regex pattern '\(pattern)'. \(error.localizedDescription)"
        }
    }

    private func extractMatches(_ pattern: String) -> String {
        do {
            var options: NSRegularExpression.Options = []
            if caseSensitive == false {
                options.insert(.caseInsensitive)
            }

            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)

            if matches.isEmpty {
                return "[]"
            }

            var extracted: [String] = []
            for match in matches {
                if let matchRange = Range(match.range, in: text) {
                    extracted.append(String(text[matchRange]))
                }
            }

            // Return as JSON array for easy parsing
            if let jsonData = try? JSONSerialization.data(withJSONObject: extracted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }

            return extracted.joined(separator: ", ")
        } catch {
            return "Error: Invalid regex pattern '\(pattern)'. \(error.localizedDescription)"
        }
    }

    private func replacePattern(_ pattern: String, with replacement: String) -> String {
        do {
            var options: NSRegularExpression.Options = []
            if caseSensitive == false {
                options.insert(.caseInsensitive)
            }

            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(text.startIndex..., in: text)

            let result = regex.stringByReplacingMatches(
                in: text,
                range: range,
                withTemplate: replacement
            )

            return result
        } catch {
            return "Error: Invalid regex pattern '\(pattern)'. \(error.localizedDescription)"
        }
    }

    private func splitText() -> String {
        let delim = delimiter ?? " "
        let components: [String]

        // Try to interpret delimiter as regex first
        if let regex = try? NSRegularExpression(pattern: delim) {
            let range = NSRange(text.startIndex..., in: text)
            var lastEnd = text.startIndex
            var parts: [String] = []

            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                if let match = match, let matchRange = Range(match.range, in: text) {
                    let part = String(text[lastEnd..<matchRange.lowerBound])
                    if !part.isEmpty {
                        parts.append(part)
                    }
                    lastEnd = matchRange.upperBound
                }
            }

            // Add remaining text
            if lastEnd < text.endIndex {
                parts.append(String(text[lastEnd...]))
            }

            components = parts
        } else {
            // Fall back to simple string split
            components = text.components(separatedBy: delim)
        }

        // Return as JSON array
        if let jsonData = try? JSONSerialization.data(withJSONObject: components),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return components.joined(separator: "\n")
    }

    private func extractSubstring() -> String {
        guard let start = startIndex else {
            return "Error: 'start_index' parameter is required for 'substring' operation."
        }

        guard start >= 0 && start < text.count else {
            return "Error: 'start_index' \(start) is out of range. Text length is \(text.count)."
        }

        let startIdx = text.index(text.startIndex, offsetBy: start)

        if let len = length {
            guard len >= 0 else {
                return "Error: 'length' must be non-negative."
            }
            let availableLength = text.distance(from: startIdx, to: text.endIndex)
            let actualLength = min(len, availableLength)
            let endIdx = text.index(startIdx, offsetBy: actualLength)
            return String(text[startIdx..<endIdx])
        } else {
            return String(text[startIdx...])
        }
    }
}
