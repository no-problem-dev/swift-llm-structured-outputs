import Foundation
import LLMStructuredOutputs
import LLMDynamicStructured
import LLMClient

// MARK: - GenerationPhase

/// 生成フェーズ（DynamicStructured用）
///
/// ConversationalAgentSession の SessionPhase に相当するが、
/// DynamicStructured 専用のシンプルな実装
enum GenerationPhase: Sendable {
    /// アイドル状態
    case idle
    /// 処理中
    case running(step: GenerationStep)
    /// 完了
    case completed(output: DynamicStructuredResult)
    /// エラー
    case failed(error: String)
}

/// 生成ステップ
enum GenerationStep: Sendable, Equatable {
    /// ユーザーメッセージ受信
    case userMessage(String)
    /// 生成中
    case generating
    /// 最終レスポンス
    case finalResponse(String)
}

// MARK: - ProviderClient

/// プロバイダークライアントを統一的に扱うための enum
///
/// DynamicStructured を使用した構造化出力生成をサポート
enum ProviderClient: Sendable {
    case anthropic(AnthropicClient)
    case openai(OpenAIClient)
    case gemini(GeminiClient)

    // MARK: - Generate

    /// DynamicStructured を使用して構造化出力を生成
    ///
    /// - Parameters:
    ///   - messages: 会話履歴
    ///   - output: DynamicStructured 定義
    ///   - claudeModel: Claude モデル（Anthropic 用）
    ///   - gptModel: GPT モデル（OpenAI 用）
    ///   - geminiModel: Gemini モデル（Gemini 用）
    ///   - systemPrompt: システムプロンプト
    /// - Returns: 生成結果
    func generate(
        messages: [LLMMessage],
        output: DynamicStructured,
        claudeModel: ClaudeModel,
        gptModel: GPTModel,
        geminiModel: GeminiModel,
        systemPrompt: String?
    ) async throws -> DynamicStructuredResult {
        switch self {
        case .anthropic(let client):
            return try await client.generate(
                messages: messages,
                model: claudeModel,
                output: output,
                systemPrompt: systemPrompt
            )
        case .openai(let client):
            return try await client.generate(
                messages: messages,
                model: gptModel,
                output: output,
                systemPrompt: systemPrompt
            )
        case .gemini(let client):
            return try await client.generate(
                messages: messages,
                model: geminiModel,
                output: output,
                systemPrompt: systemPrompt
            )
        }
    }
}

// MARK: - ProviderSession

/// DynamicStructured 用の会話セッション
///
/// 会話履歴を維持しながら、DynamicStructured を使用した
/// 構造化出力生成を行う
actor ProviderSession {
    private let client: ProviderClient
    private var messages: [LLMMessage] = []
    private let systemPrompt: String?
    private var isRunning: Bool = false

    // MARK: - Initialization

    init(
        client: ProviderClient,
        systemPrompt: String? = nil,
        initialMessages: [LLMMessage] = []
    ) {
        self.client = client
        self.systemPrompt = systemPrompt
        self.messages = initialMessages
    }

    // MARK: - Properties

    var running: Bool { isRunning }

    var turnCount: Int {
        messages.filter { $0.role == .user }.count
    }

    // MARK: - Session Management

    func getMessages() -> [LLMMessage] {
        messages
    }

    func clear() {
        guard !isRunning else { return }
        messages.removeAll()
    }

    // MARK: - Run

    /// 会話を実行
    ///
    /// ユーザーメッセージを追加し、LLM で構造化出力を生成する
    nonisolated func run(
        _ userMessage: String,
        output: DynamicStructured,
        claudeModel: ClaudeModel = .sonnet,
        gptModel: GPTModel = .gpt4o,
        geminiModel: GeminiModel = .flash25
    ) -> AsyncThrowingStream<GenerationPhase, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.executeRun(
                    userMessage: userMessage,
                    output: output,
                    claudeModel: claudeModel,
                    gptModel: gptModel,
                    geminiModel: geminiModel,
                    continuation: continuation
                )
            }
        }
    }

    private func executeRun(
        userMessage: String,
        output: DynamicStructured,
        claudeModel: ClaudeModel,
        gptModel: GPTModel,
        geminiModel: GeminiModel,
        continuation: AsyncThrowingStream<GenerationPhase, Error>.Continuation
    ) async {
        guard !isRunning else {
            continuation.finish(throwing: GenerationError.sessionBusy)
            return
        }

        isRunning = true
        defer { isRunning = false }

        // ユーザーメッセージを追加
        messages.append(.user(userMessage))
        continuation.yield(.running(step: .userMessage(userMessage)))

        // 生成中
        continuation.yield(.running(step: .generating))

        do {
            let result = try await client.generate(
                messages: messages,
                output: output,
                claudeModel: claudeModel,
                gptModel: gptModel,
                geminiModel: geminiModel,
                systemPrompt: systemPrompt
            )

            // アシスタントメッセージを履歴に追加（JSON として）
            if let jsonData = try? JSONSerialization.data(withJSONObject: result.rawValues),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                messages.append(.assistant(jsonString))
                continuation.yield(.running(step: .finalResponse(jsonString)))
            }

            continuation.yield(.completed(output: result))
            continuation.finish()

        } catch {
            let errorMessage = error.localizedDescription
            continuation.yield(.failed(error: errorMessage))
            continuation.finish(throwing: error)
        }
    }

    // MARK: - Resume

    /// 会話を再開
    ///
    /// 既存の会話履歴を使用して継続メッセージを送信
    nonisolated func resume(
        output: DynamicStructured,
        claudeModel: ClaudeModel = .sonnet,
        gptModel: GPTModel = .gpt4o,
        geminiModel: GeminiModel = .flash25
    ) -> AsyncThrowingStream<GenerationPhase, Error> {
        run(
            "Please continue where you left off.",
            output: output,
            claudeModel: claudeModel,
            gptModel: gptModel,
            geminiModel: geminiModel
        )
    }
}

// MARK: - GenerationError

enum GenerationError: Error, LocalizedError {
    case sessionBusy

    var errorDescription: String? {
        switch self {
        case .sessionBusy:
            return "Session is already running"
        }
    }
}
