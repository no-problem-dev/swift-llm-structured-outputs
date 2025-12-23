// TestConfiguration.swift
// swift-llm-structured-outputs
//
// インテグレーションテスト用の共通設定

import Foundation
import Testing

// MARK: - TestConfiguration

/// インテグレーションテストの共通設定
///
/// 環境変数からAPIキーを読み込み、テスト実行に必要な設定を提供します。
/// `.env` ファイルからの読み込みもサポートしています。
enum TestConfiguration {

    // MARK: - API Keys

    /// Anthropic API キー
    static var anthropicAPIKey: String? {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
    }

    /// OpenAI API キー
    static var openAIAPIKey: String? {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    }

    /// Gemini API キー
    static var geminiAPIKey: String? {
        ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
    }

    // MARK: - Validation

    /// OpenAI APIキーが利用可能かどうか
    static var isOpenAIAvailable: Bool {
        guard let key = openAIAPIKey else { return false }
        return !key.isEmpty
    }

    /// Anthropic APIキーが利用可能かどうか
    static var isAnthropicAvailable: Bool {
        guard let key = anthropicAPIKey else { return false }
        return !key.isEmpty
    }

    /// Gemini APIキーが利用可能かどうか
    static var isGeminiAvailable: Bool {
        guard let key = geminiAPIKey else { return false }
        return !key.isEmpty
    }

    // MARK: - Required Key Access

    /// OpenAI APIキーを取得（未設定の場合はテストをスキップ）
    static func requireOpenAIKey() throws -> String {
        guard let key = openAIAPIKey, !key.isEmpty else {
            throw TestSkipError("OPENAI_API_KEY not set - skipping test")
        }
        return key
    }

    /// Anthropic APIキーを取得（未設定の場合はテストをスキップ）
    static func requireAnthropicKey() throws -> String {
        guard let key = anthropicAPIKey, !key.isEmpty else {
            throw TestSkipError("ANTHROPIC_API_KEY not set - skipping test")
        }
        return key
    }

    /// Gemini APIキーを取得（未設定の場合はテストをスキップ）
    static func requireGeminiKey() throws -> String {
        guard let key = geminiAPIKey, !key.isEmpty else {
            throw TestSkipError("GEMINI_API_KEY not set - skipping test")
        }
        return key
    }

    // MARK: - Environment File Loading

    /// `.env` ファイルから環境変数を読み込む
    ///
    /// テスト実行前に呼び出すことで、ローカルの `.env` ファイルから
    /// APIキーなどの設定を読み込めます。
    static func loadEnvironmentFile() {
        // 複数の場所を探索
        let possiblePaths = [
            FileManager.default.currentDirectoryPath,
            FileManager.default.currentDirectoryPath + "/../..",
            FileManager.default.currentDirectoryPath + "/../../.."
        ]

        for basePath in possiblePaths {
            let envPath = URL(fileURLWithPath: basePath).appendingPathComponent(".env")
            if loadEnvFile(at: envPath) {
                return
            }
        }
    }

    private static func loadEnvFile(at url: URL) -> Bool {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return false
        }

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)

            // クォートを除去
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            setenv(key, value, 1)
        }

        return true
    }

    // MARK: - Test Timeouts

    /// 標準的なAPIリクエストのタイムアウト（秒）
    static let standardTimeout: TimeInterval = 30

    /// 画像生成のタイムアウト（秒）
    static let imageGenerationTimeout: TimeInterval = 60

    /// 動画生成のタイムアウト（秒）
    static let videoGenerationTimeout: TimeInterval = 300

    /// 動画生成のポーリング間隔（秒）
    static let videoPollingInterval: TimeInterval = 10
}

// MARK: - TestSkipError

/// テストをスキップするためのエラー
struct TestSkipError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String { message }
}

// MARK: - Test Tags

extension Tag {
    /// インテグレーションテスト（実APIを使用）
    @Tag static var integration: Self

    /// 低速テスト（動画生成など、1分以上かかる可能性）
    @Tag static var slow: Self

    /// 高コストテスト（課金が発生するAPI呼び出し）
    @Tag static var expensive: Self

    /// OpenAI プロバイダーのテスト
    @Tag static var openai: Self

    /// Anthropic プロバイダーのテスト
    @Tag static var anthropic: Self

    /// Gemini プロバイダーのテスト
    @Tag static var gemini: Self

    /// 画像生成テスト
    @Tag static var imageGeneration: Self

    /// 音声生成テスト
    @Tag static var speechGeneration: Self

    /// 動画生成テスト
    @Tag static var videoGeneration: Self

    /// Vision（画像入力）テスト
    @Tag static var vision: Self
}
