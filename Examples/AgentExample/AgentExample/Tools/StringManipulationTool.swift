//
//  StringManipulationTool.swift
//  AgentExample
//
//  文字列操作ツール
//

import Foundation
import LLMStructuredOutputs

/// 文字列操作ツール
///
/// 文字列の変換、カウント、検索などの操作を行います。
@Tool("文字列の操作を行います。文字数カウント、大文字/小文字変換、文字列反転、単語数カウントなどに対応しています。", name: "manipulate_string")
struct StringManipulationTool {
    @ToolArgument("操作対象の文字列")
    var text: String

    @ToolArgument("実行する操作（count: 文字数カウント, words: 単語数カウント, upper: 大文字変換, lower: 小文字変換, reverse: 反転, trim: 空白除去, lines: 行数カウント）")
    var operation: String

    func call() async throws -> String {
        let op = operation.lowercased().trimmingCharacters(in: .whitespaces)

        switch op {
        case "count", "length", "文字数":
            return characterCount()

        case "words", "word_count", "単語数":
            return wordCount()

        case "upper", "uppercase", "大文字":
            return uppercase()

        case "lower", "lowercase", "小文字":
            return lowercase()

        case "reverse", "反転":
            return reverse()

        case "trim", "strip", "空白除去":
            return trim()

        case "lines", "line_count", "行数":
            return lineCount()

        case "capitalize", "先頭大文字":
            return capitalize()

        case "snake", "snake_case":
            return snakeCase()

        case "camel", "camelcase":
            return camelCase()

        default:
            return """
            未知の操作: \(operation)
            サポートされている操作:
            - count: 文字数カウント
            - words: 単語数カウント
            - upper: 大文字変換
            - lower: 小文字変換
            - reverse: 文字列反転
            - trim: 前後の空白除去
            - lines: 行数カウント
            - capitalize: 各単語の先頭を大文字に
            - snake: スネークケースに変換
            - camel: キャメルケースに変換
            """
        }
    }

    // MARK: - Operations

    private func characterCount() -> String {
        let count = text.count
        let bytesUTF8 = text.utf8.count
        let bytesUTF16 = text.utf16.count

        return """
        === 文字数カウント結果 ===
        文字数: \(count)
        UTF-8バイト数: \(bytesUTF8)
        UTF-16コード単位数: \(bytesUTF16)
        """
    }

    private func wordCount() -> String {
        // 日本語と英語の両方に対応
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let wordCount = words.count

        // 日本語の場合は文字ベースでもカウント
        let japaneseCharCount = text.unicodeScalars.filter { scalar in
            // ひらがな、カタカナ、漢字の範囲
            (0x3040...0x309F).contains(scalar.value) || // ひらがな
            (0x30A0...0x30FF).contains(scalar.value) || // カタカナ
            (0x4E00...0x9FFF).contains(scalar.value)    // 漢字
        }.count

        return """
        === 単語・文字カウント結果 ===
        スペース区切りの単語数: \(wordCount)
        日本語文字数（ひらがな・カタカナ・漢字）: \(japaneseCharCount)
        """
    }

    private func uppercase() -> String {
        let result = text.uppercased()
        return """
        === 大文字変換結果 ===
        元の文字列: \(text)
        変換後: \(result)
        """
    }

    private func lowercase() -> String {
        let result = text.lowercased()
        return """
        === 小文字変換結果 ===
        元の文字列: \(text)
        変換後: \(result)
        """
    }

    private func reverse() -> String {
        let result = String(text.reversed())
        return """
        === 文字列反転結果 ===
        元の文字列: \(text)
        反転後: \(result)
        """
    }

    private func trim() -> String {
        let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let removedCount = text.count - result.count
        return """
        === 空白除去結果 ===
        元の文字列: "\(text)"
        除去後: "\(result)"
        除去された文字数: \(removedCount)
        """
    }

    private func lineCount() -> String {
        let lines = text.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return """
        === 行数カウント結果 ===
        総行数: \(lines.count)
        空行を除いた行数: \(nonEmptyLines.count)
        """
    }

    private func capitalize() -> String {
        let result = text.capitalized
        return """
        === 先頭大文字変換結果 ===
        元の文字列: \(text)
        変換後: \(result)
        """
    }

    private func snakeCase() -> String {
        var result = ""
        for (index, char) in text.enumerated() {
            if char.isUppercase && index > 0 {
                result += "_"
            }
            result += char.lowercased()
        }
        result = result.replacingOccurrences(of: " ", with: "_")
        result = result.replacingOccurrences(of: "-", with: "_")

        return """
        === スネークケース変換結果 ===
        元の文字列: \(text)
        変換後: \(result)
        """
    }

    private func camelCase() -> String {
        let words = text
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        guard !words.isEmpty else {
            return "変換する文字列が空です"
        }

        var result = words[0].lowercased()
        for word in words.dropFirst() {
            result += word.capitalized
        }

        return """
        === キャメルケース変換結果 ===
        元の文字列: \(text)
        変換後: \(result)
        """
    }
}
