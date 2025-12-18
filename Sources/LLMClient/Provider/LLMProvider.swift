import Foundation

// MARK: - LLMProvider Protocol

/// LLM プロバイダーの共通インターフェース（内部実装）
///
/// このプロトコルは内部実装で使用されます。
/// 外部からは `StructuredLLMClient` プロトコルを使用してください。
internal protocol LLMProvider: Sendable {
    /// リクエストを送信してレスポンスを取得
    ///
    /// - Parameter request: LLM リクエスト
    /// - Returns: LLM レスポンス
    /// - Throws: `LLMError` - 通信エラー、認証エラーなど
    func send(_ request: LLMRequest) async throws -> LLMResponse
}

// MARK: - LLMRequest

/// LLM への統一リクエスト形式（内部実装）
///
/// 基本的な LLM リクエストのみを扱います。
/// ツールコール機能は LLMTool モジュールで拡張されます。
internal struct LLMRequest: Sendable {
    /// 使用するモデル
    public let model: LLMModel

    /// メッセージ履歴
    public let messages: [LLMMessage]

    /// システムプロンプト（オプション）
    public let systemPrompt: String?

    /// 構造化出力のスキーマ（nil の場合はプレーンテキスト）
    public let responseSchema: JSONSchema?

    /// 温度パラメータ（0.0-1.0）
    public let temperature: Double?

    /// 最大トークン数
    public let maxTokens: Int?

    /// リクエストを初期化
    public init(
        model: LLMModel,
        messages: [LLMMessage],
        systemPrompt: String? = nil,
        responseSchema: JSONSchema? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.model = model
        self.messages = messages
        self.systemPrompt = systemPrompt
        self.responseSchema = responseSchema
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

// MARK: - LLMResponse

/// LLM からの統一レスポンス形式
public struct LLMResponse: Sendable {
    /// レスポンスコンテンツ
    public let content: [ContentBlock]

    /// 使用されたモデル
    public let model: String

    /// 使用トークン数
    public let usage: TokenUsage

    /// 停止理由
    public let stopReason: StopReason?

    /// レスポンスを初期化
    public init(
        content: [ContentBlock],
        model: String,
        usage: TokenUsage,
        stopReason: StopReason? = nil
    ) {
        self.content = content
        self.model = model
        self.usage = usage
        self.stopReason = stopReason
    }

    /// コンテンツブロック
    public enum ContentBlock: Sendable {
        case text(String)
        case toolUse(id: String, name: String, input: Data)

        /// テキストコンテンツを取得（text ブロックの場合のみ）
        public var text: String? {
            if case .text(let value) = self {
                return value
            }
            return nil
        }

        /// ツール使用の入力を JSON としてデコード
        public func toolInput<T: Decodable>(as type: T.Type) throws -> T? {
            guard case .toolUse(_, _, let data) = self else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(type, from: data)
        }
    }

    /// 停止理由
    public enum StopReason: String, Sendable {
        case endTurn = "end_turn"
        case maxTokens = "max_tokens"
        case stopSequence = "stop_sequence"
        case toolUse = "tool_use"
    }
}

// MARK: - TokenUsage

/// トークン使用量
public struct TokenUsage: Sendable {
    /// 入力トークン数
    public let inputTokens: Int

    /// 出力トークン数
    public let outputTokens: Int

    /// 合計トークン数
    public var totalTokens: Int {
        inputTokens + outputTokens
    }

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

// MARK: - LLMMessage

/// LLM メッセージ
///
/// テキストメッセージに加えて、ツール呼び出しとツール結果もサポートします。
///
/// ## 使用例
///
/// ```swift
/// // テキストメッセージ
/// let userMessage = LLMMessage.user("東京の天気は？")
/// let assistantMessage = LLMMessage.assistant("東京は晴れです。")
///
/// // ツール呼び出し（アシスタントからの応答）
/// let toolCallMessage = LLMMessage.toolUse(
///     id: "call_123",
///     name: "get_weather",
///     input: jsonData
/// )
///
/// // ツール結果（ユーザーからの応答として送信）
/// let toolResultMessage = LLMMessage.toolResult(
///     toolCallId: "call_123",
///     name: "get_weather",
///     content: "晴れ、25度"
/// )
/// ```
public struct LLMMessage: Sendable {
    /// メッセージの役割
    public let role: Role

    /// メッセージ内容（複合コンテンツ対応）
    public let contents: [MessageContent]

    /// 役割
    public enum Role: String, Sendable {
        case user
        case assistant
    }

    /// メッセージコンテンツの種類
    public enum MessageContent: Sendable, Equatable {
        /// テキストコンテンツ
        case text(String)

        /// ツール呼び出し（アシスタントが生成）
        case toolUse(id: String, name: String, input: Data)

        /// ツール実行結果（ツール呼び出しへの応答）
        /// - Parameters:
        ///   - toolCallId: 対応するツール呼び出しID
        ///   - name: ツール名（Gemini APIで必須）
        ///   - content: 実行結果の文字列
        ///   - isError: エラー結果かどうか
        case toolResult(toolCallId: String, name: String, content: String, isError: Bool)
    }

    // MARK: - Initializers

    /// メッセージを初期化（複合コンテンツ）
    public init(role: Role, contents: [MessageContent]) {
        self.role = role
        self.contents = contents
    }

    /// メッセージを初期化（単一テキスト）
    public init(role: Role, content: String) {
        self.role = role
        self.contents = [.text(content)]
    }

    // MARK: - Convenience Properties

    /// テキストコンテンツを取得（後方互換性）
    ///
    /// 複数のテキストブロックがある場合は結合して返します。
    /// テキストがない場合は空文字列を返します。
    public var content: String {
        contents.compactMap { content in
            if case .text(let text) = content {
                return text
            }
            return nil
        }.joined()
    }

    /// ツール呼び出しを含むかどうか
    public var hasToolUse: Bool {
        contents.contains { content in
            if case .toolUse = content { return true }
            return false
        }
    }

    /// ツール結果を含むかどうか
    public var hasToolResult: Bool {
        contents.contains { content in
            if case .toolResult = content { return true }
            return false
        }
    }

    /// ツール呼び出しを取得
    public var toolUses: [(id: String, name: String, input: Data)] {
        contents.compactMap { content in
            if case .toolUse(let id, let name, let input) = content {
                return (id, name, input)
            }
            return nil
        }
    }

    /// ツール結果を取得
    public var toolResults: [(toolCallId: String, name: String, content: String, isError: Bool)] {
        contents.compactMap { content in
            if case .toolResult(let id, let name, let resultContent, let isError) = content {
                return (id, name, resultContent, isError)
            }
            return nil
        }
    }

    // MARK: - Factory Methods

    /// ユーザーメッセージを作成
    public static func user(_ content: String) -> LLMMessage {
        LLMMessage(role: .user, content: content)
    }

    /// アシスタントメッセージを作成
    public static func assistant(_ content: String) -> LLMMessage {
        LLMMessage(role: .assistant, content: content)
    }

    /// ツール呼び出しメッセージを作成（アシスタント）
    ///
    /// LLM がツールを呼び出すことを決定した際のメッセージ。
    /// 通常は `LLMResponse` から自動的に生成されます。
    ///
    /// - Parameters:
    ///   - id: ツール呼び出しID
    ///   - name: ツール名
    ///   - input: ツール引数（JSON データ）
    public static func toolUse(id: String, name: String, input: Data) -> LLMMessage {
        LLMMessage(role: .assistant, contents: [.toolUse(id: id, name: name, input: input)])
    }

    /// 複数のツール呼び出しを含むメッセージを作成（アシスタント）
    ///
    /// - Parameter toolCalls: ツール呼び出し情報の配列
    public static func toolUses(_ toolCalls: [(id: String, name: String, input: Data)]) -> LLMMessage {
        let contents = toolCalls.map { MessageContent.toolUse(id: $0.id, name: $0.name, input: $0.input) }
        return LLMMessage(role: .assistant, contents: contents)
    }

    /// ツール実行結果メッセージを作成（ユーザー）
    ///
    /// ツールを実行した結果を LLM に返すためのメッセージ。
    ///
    /// - Parameters:
    ///   - toolCallId: 対応するツール呼び出しID
    ///   - name: ツール名
    ///   - content: 実行結果の文字列
    ///   - isError: エラー結果かどうか（デフォルト: false）
    public static func toolResult(
        toolCallId: String,
        name: String,
        content: String,
        isError: Bool = false
    ) -> LLMMessage {
        LLMMessage(role: .user, contents: [.toolResult(toolCallId: toolCallId, name: name, content: content, isError: isError)])
    }

    /// 複数のツール実行結果を含むメッセージを作成（ユーザー）
    ///
    /// - Parameter results: ツール結果情報の配列
    public static func toolResults(_ results: [(toolCallId: String, name: String, content: String, isError: Bool)]) -> LLMMessage {
        let contents = results.map {
            MessageContent.toolResult(toolCallId: $0.toolCallId, name: $0.name, content: $0.content, isError: $0.isError)
        }
        return LLMMessage(role: .user, contents: contents)
    }
}

// MARK: - LLMModel

/// LLM モデル指定（内部実装）
internal enum LLMModel: Sendable, Equatable {
    /// Anthropic Claude モデル
    case claude(ClaudeModel)

    /// OpenAI GPT モデル
    case gpt(GPTModel)

    /// Google Gemini モデル
    case gemini(GeminiModel)

    /// カスタムモデル ID
    case custom(String)

    /// モデル ID 文字列を取得
    public var id: String {
        switch self {
        case .claude(let model):
            return model.id
        case .gpt(let model):
            return model.id
        case .gemini(let model):
            return model.id
        case .custom(let id):
            return id
        }
    }
}

// MARK: - Claude Models

/// Anthropic Claude モデル
///
/// エイリアス（推奨）または固定バージョンでモデルを指定できます。
///
/// ## エイリアス（推奨）
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
/// let result: UserInfo = try await client.generate(
///     prompt: "...",
///     model: .sonnet  // 最新の Sonnet を使用
/// )
/// ```
///
/// ## 固定バージョン
/// ```swift
/// let result: UserInfo = try await client.generate(
///     prompt: "...",
///     model: .sonnet4_5("20250929")  // 特定バージョンを指定
/// )
/// ```
///
/// ## カスタムモデルID
/// ```swift
/// let result: UserInfo = try await client.generate(
///     prompt: "...",
///     model: .custom("claude-3-opus-20240229")  // 任意のモデルID
/// )
/// ```
public enum ClaudeModel: Sendable, Equatable {
    // MARK: - Aliases (推奨)

    /// Claude Opus 4.5 最新版（最高性能）
    case opus

    /// Claude Sonnet 4.5 最新版（バランス型）
    case sonnet

    /// Claude Haiku 4.5 最新版（高速・低コスト）
    case haiku

    // MARK: - Fixed Versions

    /// Claude Opus 4.5 固定バージョン
    /// - Parameter version: バージョン文字列（例: "20251101"）
    case opus4_5(version: String)

    /// Claude Sonnet 4.5 固定バージョン
    /// - Parameter version: バージョン文字列（例: "20250929"）
    case sonnet4_5(version: String)

    /// Claude Haiku 4.5 固定バージョン
    /// - Parameter version: バージョン文字列（例: "20250929"）
    case haiku4_5(version: String)

    /// Claude Opus 4.1 固定バージョン
    /// - Parameter version: バージョン文字列（例: "20250918"）
    case opus4_1(version: String)

    /// Claude Sonnet 4 固定バージョン
    /// - Parameter version: バージョン文字列（例: "20250514"）
    case sonnet4(version: String)

    // MARK: - Custom

    /// カスタムモデルID
    /// - Parameter id: 任意のモデルID文字列
    case custom(String)

    // MARK: - Model ID

    /// モデルID文字列を取得
    public var id: String {
        switch self {
        // Aliases（常に最新のスナップショットを指す）
        case .opus:
            return "claude-opus-4-5"
        case .sonnet:
            return "claude-sonnet-4-5"
        case .haiku:
            return "claude-haiku-4-5"
        // Fixed versions
        case .opus4_5(let version):
            return "claude-opus-4-5-\(version)"
        case .sonnet4_5(let version):
            return "claude-sonnet-4-5-\(version)"
        case .haiku4_5(let version):
            return "claude-haiku-4-5-\(version)"
        case .opus4_1(let version):
            return "claude-opus-4-1-\(version)"
        case .sonnet4(let version):
            return "claude-sonnet-4-\(version)"
        // Custom
        case .custom(let id):
            return id
        }
    }
}

// MARK: - Preset

extension ClaudeModel {
    /// UI選択用のプリセットモデル
    ///
    /// `CaseIterable` に準拠しており、SwiftUI の `ForEach` などで使用できます。
    ///
    /// ```swift
    /// ForEach(ClaudeModel.Preset.allCases) { preset in
    ///     Text(preset.displayName)
    /// }
    /// ```
    public enum Preset: String, CaseIterable, Identifiable, Sendable {
        /// Claude Opus 4.5（最高性能）
        case opus = "opus"
        /// Claude Sonnet 4.5（バランス型）
        case sonnet = "sonnet"
        /// Claude Haiku 4.5（高速・低コスト）
        case haiku = "haiku"

        public var id: String { rawValue }

        /// 対応する `ClaudeModel` を取得
        public var model: ClaudeModel {
            switch self {
            case .opus: return .opus
            case .sonnet: return .sonnet
            case .haiku: return .haiku
            }
        }

        /// 表示名
        public var displayName: String {
            switch self {
            case .opus: return "Claude Opus 4.5"
            case .sonnet: return "Claude Sonnet 4.5"
            case .haiku: return "Claude Haiku 4.5"
            }
        }

        /// 短い表示名
        public var shortName: String {
            switch self {
            case .opus: return "Opus"
            case .sonnet: return "Sonnet"
            case .haiku: return "Haiku"
            }
        }
    }
}

// MARK: - GPT Models

/// OpenAI GPT モデル
///
/// エイリアス（推奨）または固定バージョンでモデルを指定できます。
///
/// ## エイリアス（推奨）
/// ```swift
/// let client = OpenAIClient(apiKey: "...")
/// let result: UserInfo = try await client.generate(
///     prompt: "...",
///     model: .gpt4o  // 最新の GPT-4o を使用
/// )
/// ```
///
/// ## 固定バージョン
/// ```swift
/// let result: UserInfo = try await client.generate(
///     prompt: "...",
///     model: .gpt4o_version("2024-11-20")  // 特定バージョンを指定
/// )
/// ```
///
/// ## カスタムモデルID
/// ```swift
/// let result: UserInfo = try await client.generate(
///     prompt: "...",
///     model: .custom("gpt-4-32k")  // 任意のモデルID
/// )
/// ```
public enum GPTModel: Sendable, Equatable {
    // MARK: - Aliases (推奨)

    /// GPT-4o 最新版（マルチモーダル）
    case gpt4o

    /// GPT-4o mini 最新版（軽量版）
    case gpt4oMini

    /// GPT-4 Turbo 最新版
    case gpt4Turbo

    /// GPT-4 最新版
    case gpt4

    /// o1 最新版（推論特化）
    case o1

    /// o3 最新版（高度な推論）
    case o3

    /// o3-mini 最新版（軽量推論）
    case o3Mini

    /// o4-mini 最新版（最新軽量推論）
    case o4Mini

    // MARK: - Fixed Versions

    /// GPT-4o 固定バージョン
    /// - Parameter version: バージョン文字列（例: "2024-11-20", "2024-08-06"）
    case gpt4o_version(String)

    /// GPT-4o mini 固定バージョン
    /// - Parameter version: バージョン文字列
    case gpt4oMini_version(String)

    /// o1 固定バージョン
    /// - Parameter version: バージョン文字列
    case o1_version(String)

    /// o3 固定バージョン
    /// - Parameter version: バージョン文字列（例: "2025-04-16"）
    case o3_version(String)

    /// o3-mini 固定バージョン
    /// - Parameter version: バージョン文字列
    case o3Mini_version(String)

    /// o4-mini 固定バージョン
    /// - Parameter version: バージョン文字列（例: "2025-04-16"）
    case o4Mini_version(String)

    // MARK: - Custom

    /// カスタムモデルID
    /// - Parameter id: 任意のモデルID文字列
    case custom(String)

    // MARK: - Model ID

    /// モデルID文字列を取得
    public var id: String {
        switch self {
        // Aliases
        case .gpt4o:
            return "gpt-4o"
        case .gpt4oMini:
            return "gpt-4o-mini"
        case .gpt4Turbo:
            return "gpt-4-turbo"
        case .gpt4:
            return "gpt-4"
        case .o1:
            return "o1"
        case .o3:
            return "o3"
        case .o3Mini:
            return "o3-mini"
        case .o4Mini:
            return "o4-mini"
        // Fixed versions
        case .gpt4o_version(let version):
            return "gpt-4o-\(version)"
        case .gpt4oMini_version(let version):
            return "gpt-4o-mini-\(version)"
        case .o1_version(let version):
            return "o1-\(version)"
        case .o3_version(let version):
            return "o3-\(version)"
        case .o3Mini_version(let version):
            return "o3-mini-\(version)"
        case .o4Mini_version(let version):
            return "o4-mini-\(version)"
        // Custom
        case .custom(let id):
            return id
        }
    }
}

// MARK: - Preset

extension GPTModel {
    /// UI選択用のプリセットモデル
    ///
    /// `CaseIterable` に準拠しており、SwiftUI の `ForEach` などで使用できます。
    ///
    /// ```swift
    /// ForEach(GPTModel.Preset.allCases) { preset in
    ///     Text(preset.displayName)
    /// }
    /// ```
    public enum Preset: String, CaseIterable, Identifiable, Sendable {
        /// GPT-4o（マルチモーダル）
        case gpt4o = "gpt4o"
        /// GPT-4o mini（軽量版）
        case gpt4oMini = "gpt4oMini"
        /// o1（推論特化）
        case o1 = "o1"
        /// o3-mini（軽量推論）
        case o3Mini = "o3Mini"

        public var id: String { rawValue }

        /// 対応する `GPTModel` を取得
        public var model: GPTModel {
            switch self {
            case .gpt4o: return .gpt4o
            case .gpt4oMini: return .gpt4oMini
            case .o1: return .o1
            case .o3Mini: return .o3Mini
            }
        }

        /// 表示名
        public var displayName: String {
            switch self {
            case .gpt4o: return "GPT-4o"
            case .gpt4oMini: return "GPT-4o mini"
            case .o1: return "o1"
            case .o3Mini: return "o3-mini"
            }
        }

        /// 短い表示名
        public var shortName: String {
            switch self {
            case .gpt4o: return "4o"
            case .gpt4oMini: return "4o mini"
            case .o1: return "o1"
            case .o3Mini: return "o3-mini"
            }
        }
    }
}

// MARK: - Gemini Models

/// Google Gemini モデル
///
/// エイリアス（推奨）または固定バージョンでモデルを指定できます。
///
/// ## エイリアス（推奨）
/// ```swift
/// let client = GeminiClient(apiKey: "...")
/// let result: UserInfo = try await client.generate(
///     prompt: "...",
///     model: .flash25  // 最新の Gemini 2.5 Flash を使用
/// )
/// ```
///
/// ## プレビューバージョン
/// ```swift
/// let result: UserInfo = try await client.generate(
///     prompt: "...",
///     model: .flash25_preview("05-20")  // 特定プレビューを指定
/// )
/// ```
///
/// ## カスタムモデルID
/// ```swift
/// let result: UserInfo = try await client.generate(
///     prompt: "...",
///     model: .custom("gemini-2.5-pro-exp-03-25")  // 任意のモデルID
/// )
/// ```
public enum GeminiModel: Sendable, Equatable {
    // MARK: - Aliases (推奨)

    /// Gemini 3 Flash 最新版（最高性能・高速）
    case flash3

    /// Gemini 2.5 Pro 最新版（高性能）
    case pro25

    /// Gemini 2.5 Flash 最新版（高速・バランス型）
    case flash25

    /// Gemini 2.5 Flash-Lite 最新版（軽量・低コスト）
    case flash25Lite

    /// Gemini 2.0 Flash 最新版
    case flash20

    /// Gemini 1.5 Pro 最新版
    case pro15

    /// Gemini 1.5 Flash 最新版
    case flash15

    // MARK: - Preview/Experimental Versions

    /// Gemini 3 Flash プレビューバージョン
    /// - Parameter version: バージョン文字列（例: "12-17"）
    case flash3_preview(version: String)

    /// Gemini 2.5 Pro プレビューバージョン
    /// - Parameter version: バージョン文字列（例: "05-06"）
    case pro25_preview(version: String)

    /// Gemini 2.5 Flash プレビューバージョン
    /// - Parameter version: バージョン文字列（例: "05-20"）
    case flash25_preview(version: String)

    /// Gemini 2.5 Flash-Lite プレビューバージョン
    /// - Parameter version: バージョン文字列（例: "06-17"）
    case flash25Lite_preview(version: String)

    // MARK: - Custom

    /// カスタムモデルID
    /// - Parameter id: 任意のモデルID文字列
    case custom(String)

    // MARK: - Model ID

    /// モデルID文字列を取得
    public var id: String {
        switch self {
        // Aliases
        case .flash3:
            return "gemini-3-flash-preview"
        case .pro25:
            return "gemini-2.5-pro"
        case .flash25:
            return "gemini-2.5-flash"
        case .flash25Lite:
            return "gemini-2.5-flash-lite"
        case .flash20:
            return "gemini-2.0-flash"
        case .pro15:
            return "gemini-1.5-pro"
        case .flash15:
            return "gemini-1.5-flash"
        // Preview versions
        case .flash3_preview(let version):
            return "gemini-3-flash-preview-\(version)"
        case .pro25_preview(let version):
            return "gemini-2.5-pro-preview-\(version)"
        case .flash25_preview(let version):
            return "gemini-2.5-flash-preview-\(version)"
        case .flash25Lite_preview(let version):
            return "gemini-2.5-flash-lite-preview-\(version)"
        // Custom
        case .custom(let id):
            return id
        }
    }
}

// MARK: - RawValue Compatibility

extension GeminiModel: RawRepresentable {
    public var rawValue: String {
        return id
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "gemini-3-flash-preview":
            self = .flash3
        case "gemini-2.5-pro":
            self = .pro25
        case "gemini-2.5-flash":
            self = .flash25
        case "gemini-2.5-flash-lite":
            self = .flash25Lite
        case "gemini-2.0-flash":
            self = .flash20
        case "gemini-1.5-pro":
            self = .pro15
        case "gemini-1.5-flash":
            self = .flash15
        default:
            self = .custom(rawValue)
        }
    }
}

// MARK: - Preset

extension GeminiModel {
    /// UI選択用のプリセットモデル
    ///
    /// `CaseIterable` に準拠しており、SwiftUI の `ForEach` などで使用できます。
    ///
    /// ```swift
    /// ForEach(GeminiModel.Preset.allCases) { preset in
    ///     Text(preset.displayName)
    /// }
    /// ```
    public enum Preset: String, CaseIterable, Identifiable, Sendable {
        /// Gemini 3 Flash（最高性能・高速）
        case flash3 = "flash3"
        /// Gemini 2.5 Pro（高性能）
        case pro25 = "pro25"
        /// Gemini 2.5 Flash（高速・バランス型）
        case flash25 = "flash25"
        /// Gemini 2.5 Flash-Lite（軽量・低コスト）
        case flash25Lite = "flash25Lite"

        public var id: String { rawValue }

        /// 対応する `GeminiModel` を取得
        public var model: GeminiModel {
            switch self {
            case .flash3: return .flash3
            case .pro25: return .pro25
            case .flash25: return .flash25
            case .flash25Lite: return .flash25Lite
            }
        }

        /// 表示名
        public var displayName: String {
            switch self {
            case .flash3: return "Gemini 3 Flash"
            case .pro25: return "Gemini 2.5 Pro"
            case .flash25: return "Gemini 2.5 Flash"
            case .flash25Lite: return "Gemini 2.5 Flash-Lite"
            }
        }

        /// 短い表示名
        public var shortName: String {
            switch self {
            case .flash3: return "3 Flash"
            case .pro25: return "2.5 Pro"
            case .flash25: return "2.5 Flash"
            case .flash25Lite: return "2.5 Flash-Lite"
            }
        }
    }
}

// MARK: - LLMError

/// LLM API エラー
public enum LLMError: Error, Sendable {
    /// 認証エラー（無効な API キー）
    case unauthorized

    /// レート制限超過
    case rateLimitExceeded

    /// 無効なリクエスト
    case invalidRequest(String)

    /// モデルが見つからない
    case modelNotFound(String)

    /// サーバーエラー
    case serverError(Int, String)

    /// ネットワークエラー
    case networkError(Error)

    /// 空のレスポンス
    case emptyResponse

    /// 無効なエンコーディング
    case invalidEncoding

    /// デコードエラー
    case decodingFailed(Error)

    /// モデルがプロバイダーに対応していない
    case modelNotSupported(model: String, provider: String)

    /// 構造化出力がサポートされていない
    case structuredOutputNotSupported(model: String)

    /// コンテンツがブロックされた（安全性フィルター）
    case contentBlocked(reason: String?)

    /// 最大トークン数に達した
    case maxTokensReached

    /// タイムアウト
    case timeout

    /// 不明なエラー
    case unknown(Error)
}

extension LLMError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid API key or unauthorized access"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .emptyResponse:
            return "Empty response from the API"
        case .invalidEncoding:
            return "Invalid text encoding in response"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .modelNotSupported(let model, let provider):
            return "Model \(model) is not supported by \(provider)"
        case .structuredOutputNotSupported(let model):
            return "Structured output is not supported by model: \(model)"
        case .contentBlocked(let reason):
            return "Content blocked by safety filter\(reason.map { ": \($0)" } ?? "")"
        case .maxTokensReached:
            return "Maximum token limit reached"
        case .timeout:
            return "Request timed out"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
