//
//  ConversationController.swift
//  ConversationAgentExample
//
//  会話型エージェントセッションの制御
//

import Foundation
import SwiftUI
import LLMStructuredOutputs

/// 会話ステップの表示情報
struct ConversationStepInfo: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: StepType
    let content: String
    let detail: String?
    let isError: Bool

    enum StepType: String {
        case userMessage = "👤"
        case thinking = "🤔"
        case toolCall = "🔧"
        case toolResult = "📄"
        case interrupted = "⚡"
        case textResponse = "💬"
        case finalResponse = "✅"
        case event = "📢"
        case error = "❌"

        var icon: String {
            switch self {
            case .userMessage: return "person.fill"
            case .thinking: return "brain.head.profile"
            case .toolCall: return "wrench.and.screwdriver"
            case .toolResult: return "doc.text"
            case .interrupted: return "bolt.fill"
            case .textResponse: return "text.bubble"
            case .finalResponse: return "checkmark.circle.fill"
            case .event: return "bell.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        var label: String {
            switch self {
            case .userMessage: return "ユーザー"
            case .thinking: return "思考中"
            case .toolCall: return "ツール呼び出し"
            case .toolResult: return "ツール結果"
            case .interrupted: return "割り込み"
            case .textResponse: return "応答"
            case .finalResponse: return "完了"
            case .event: return "イベント"
            case .error: return "エラー"
            }
        }
    }

    init(type: StepType, content: String, detail: String? = nil, isError: Bool = false) {
        self.timestamp = Date()
        self.type = type
        self.content = content
        self.detail = detail
        self.isError = isError
    }
}

/// セッション状態
enum SessionState: Equatable {
    case idle
    case running
    case completed(String)
    case error(String)

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

/// 会話コントローラー
///
/// ConversationalAgentSession を使用して、マルチターン会話を管理します。
@Observable @MainActor
final class ConversationController {

    // MARK: - Properties

    private(set) var state: SessionState = .idle
    private(set) var steps: [ConversationStepInfo] = []
    private(set) var events: [ConversationStepInfo] = []
    private(set) var turnCount: Int = 0

    private var session: ConversationalAgentSession<AnthropicClient>?
    private var runningTask: Task<Void, Never>?
    private var eventMonitorTask: Task<Void, Never>?

    // MARK: - Session Management

    /// セッションが存在するか
    var hasSession: Bool {
        session != nil
    }

    /// セッションを作成（存在しない場合のみ）
    func createSessionIfNeeded() {
        guard session == nil else { return }
        createSession()
    }

    /// セッションを作成
    func createSession() {
        guard let apiKey = APIKeyManager.anthropicKey else {
            state = .error("APIキーが設定されていません")
            return
        }

        let client = AnthropicClient(apiKey: apiKey)
        let tools = ToolSet {
            WebSearchTool.self
            FetchWebPageTool.self
        }

        session = ConversationalAgentSession(
            client: client,
            systemPrompt: Prompt {
                PromptComponent.role("リサーチアシスタント")
                PromptComponent.objective("ユーザーの質問に対して調査を行い、結果をまとめる")
                PromptComponent.instruction("必要に応じてWeb検索やページ取得を行ってください")
                PromptComponent.instruction("調査が完了したら、指定された構造化フォーマットで結果を出力してください")
            },
            tools: tools
        )

        // イベント監視を開始
        startEventMonitoring()

        state = .idle
        steps = []
        events = []
        addEvent("セッションが作成されました")
    }

    /// セッションをクリア
    func clearSession() async {
        runningTask?.cancel()
        runningTask = nil
        eventMonitorTask?.cancel()
        eventMonitorTask = nil

        if let session = session {
            await session.clear()
        }

        session = nil
        state = .idle
        steps = []
        events = []
        turnCount = 0
    }

    // MARK: - Run Methods

    /// リサーチレポートを生成
    func runResearch(prompt: String) {
        guard let session = session else {
            state = .error("セッションが作成されていません")
            return
        }
        guard !state.isRunning else { return }

        state = .running

        runningTask = Task {
            await executeRun(session: session, prompt: prompt, outputType: .research)
        }
    }

    /// サマリーレポートを生成
    func runSummary(prompt: String) {
        guard let session = session else {
            state = .error("セッションが作成されていません")
            return
        }
        guard !state.isRunning else { return }

        state = .running

        runningTask = Task {
            await executeRun(session: session, prompt: prompt, outputType: .summary)
        }
    }

    /// 比較レポートを生成
    func runComparison(prompt: String) {
        guard let session = session else {
            state = .error("セッションが作成されていません")
            return
        }
        guard !state.isRunning else { return }

        state = .running

        runningTask = Task {
            await executeRun(session: session, prompt: prompt, outputType: .comparison)
        }
    }

    /// 選択した出力タイプで実行
    func run(prompt: String, outputType: OutputTypeSelection) {
        switch outputType {
        case .research:
            runResearch(prompt: prompt)
        case .summary:
            runSummary(prompt: prompt)
        case .comparison:
            runComparison(prompt: prompt)
        }
    }

    // MARK: - Interrupt

    /// 割り込みメッセージを送信
    func interrupt(message: String) async {
        guard let session = session else { return }
        await session.interrupt(message)
        addStep(.init(type: .interrupted, content: "割り込み送信: \(message)"))
    }

    // MARK: - Private Methods

    private func executeRun(
        session: ConversationalAgentSession<AnthropicClient>,
        prompt: String,
        outputType: OutputTypeSelection
    ) async {
        do {
            switch outputType {
            case .research:
                let stream: some ConversationalAgentStepStream<ResearchReport> = await session.run(
                    prompt,
                    model: .sonnet
                )
                try await processStream(stream, formatResult: formatResearchReport)

            case .summary:
                let stream: some ConversationalAgentStepStream<SummaryReport> = await session.run(
                    prompt,
                    model: .sonnet
                )
                try await processStream(stream, formatResult: formatSummaryReport)

            case .comparison:
                let stream: some ConversationalAgentStepStream<ComparisonReport> = await session.run(
                    prompt,
                    model: .sonnet
                )
                try await processStream(stream, formatResult: formatComparisonReport)
            }

            turnCount = await session.turnCount

        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
                addStep(.init(type: .error, content: error.localizedDescription, isError: true))
            }
        }

        runningTask = nil
    }

    private func processStream<Output: StructuredProtocol>(
        _ stream: some ConversationalAgentStepStream<Output>,
        formatResult: @escaping (Output) -> String
    ) async throws {
        var finalOutput: Output?

        for try await step in stream {
            await MainActor.run {
                let stepInfo = processStep(step)
                addStep(stepInfo)

                if case .finalResponse(let output) = step {
                    finalOutput = output
                }
            }
        }

        await MainActor.run {
            if let output = finalOutput {
                state = .completed(formatResult(output))
            } else {
                state = .completed("完了しました（テキスト応答）")
            }
        }
    }

    private func processStep<Output>(_ step: ConversationalAgentStep<Output>) -> ConversationStepInfo {
        switch step {
        case .userMessage(let message):
            return .init(type: .userMessage, content: message)

        case .thinking(let response):
            let text = response.content.compactMap { block -> String? in
                if case .text(let value) = block { return value }
                return nil
            }.joined()
            return .init(type: .thinking, content: text.isEmpty ? "（考え中...）" : String(text.prefix(200)))

        case .toolCall(let call):
            let args = formatToolArgs(call.arguments)
            return .init(type: .toolCall, content: call.name, detail: args)

        case .toolResult(let result):
            return .init(
                type: .toolResult,
                content: String(result.output.prefix(300)),
                isError: result.isError
            )

        case .interrupted(let message):
            return .init(type: .interrupted, content: "割り込み処理: \(message)")

        case .textResponse(let text):
            return .init(type: .textResponse, content: String(text.prefix(500)))

        case .finalResponse:
            return .init(type: .finalResponse, content: "レポート生成完了")
        }
    }

    private func formatToolArgs(_ data: Data) -> String? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }

    private func addStep(_ step: ConversationStepInfo) {
        steps.append(step)
    }

    private func addEvent(_ message: String) {
        events.append(.init(type: .event, content: message))
    }

    // MARK: - Event Monitoring

    private func startEventMonitoring() {
        guard let session = session else { return }

        eventMonitorTask?.cancel()
        eventMonitorTask = Task {
            for await event in session.eventStream {
                await MainActor.run {
                    handleEvent(event)
                }
            }
        }
    }

    private func handleEvent(_ event: ConversationalAgentEvent) {
        let message: String
        switch event {
        case .userMessage:
            message = "ユーザーメッセージが追加されました"
        case .assistantMessage:
            message = "アシスタントメッセージが追加されました"
        case .interruptQueued(let msg):
            message = "割り込みがキューに追加: \(msg)"
        case .interruptProcessed(let msg):
            message = "割り込みが処理されました: \(msg)"
        case .sessionStarted:
            message = "セッションが開始されました"
        case .sessionCompleted:
            message = "セッションが完了しました"
        case .cleared:
            message = "会話履歴がクリアされました"
        case .error(let error):
            message = "エラー: \(error.localizedDescription)"
        }
        addEvent(message)
    }

    // MARK: - Result Formatting (Markdown)

    private func formatResearchReport(_ report: ResearchReport) -> String {
        var md = "# 📚 \(report.topic)\n\n"
        md += "## 要約\n\n\(report.summary)\n\n"
        md += "## 重要な発見\n\n"
        for (i, finding) in report.keyFindings.enumerated() {
            md += "\(i + 1). \(finding)\n"
        }
        md += "\n## 情報源\n\n"
        for source in report.sources {
            if source.hasPrefix("http") {
                md += "- [\(source)](\(source))\n"
            } else {
                md += "- \(source)\n"
            }
        }
        md += "\n## さらに調査すべき点\n\n"
        for question in report.furtherQuestions {
            md += "- \(question)\n"
        }
        return md
    }

    private func formatSummaryReport(_ report: SummaryReport) -> String {
        var md = "# 📋 \(report.title)\n\n"
        md += "\(report.summary)\n\n"
        md += "## ポイント\n\n"
        for point in report.bulletPoints {
            md += "- \(point)\n"
        }
        return md
    }

    private func formatComparisonReport(_ report: ComparisonReport) -> String {
        var md = "# ⚖️ \(report.subject)\n\n"
        for item in report.items {
            md += "## \(item.name)\n\n"
            md += "### ✅ メリット\n\n"
            for pro in item.pros {
                md += "- \(pro)\n"
            }
            md += "\n### ❌ デメリット\n\n"
            for con in item.cons {
                md += "- \(con)\n"
            }
            md += "\n"
        }
        md += "## 💡 推奨\n\n\(report.recommendation)"
        return md
    }
}
