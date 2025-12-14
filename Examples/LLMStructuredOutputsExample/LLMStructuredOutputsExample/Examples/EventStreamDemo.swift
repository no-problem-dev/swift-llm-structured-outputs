//
//  EventStreamDemo.swift
//  LLMStructuredOutputsExample
//
//  イベントストリームデモ
//

import SwiftUI
import LLMStructuredOutputs

/// イベントストリームデモ
///
/// `Conversation` の `eventStream` を使ったリアルタイムイベント監視を体験できます。
/// メッセージの送受信やエラーをAsyncSequenceで購読します。
struct EventStreamDemo: View {
    private var settings = AppSettings.shared

    @State private var inputText = ""
    @State private var events: [EventLogEntry] = []
    @State private var isLoading = false
    @State private var conversationMessages: [LLMMessage] = []
    @State private var totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - 説明
                    DescriptionSection()

                    Divider()

                    // MARK: - イベントログ
                    EventLogView(events: events)

                    // MARK: - 統計
                    if !events.isEmpty {
                        EventStatistics(events: events, usage: totalUsage)
                    }
                }
                .padding()
            }

            Divider()

            // MARK: - 入力エリア
            if settings.isCurrentProviderAvailable {
                EventInputView(
                    text: $inputText,
                    isLoading: isLoading,
                    onSend: sendMessage,
                    onClear: clearEvents,
                    onSimulateError: simulateError
                )
            } else {
                APIKeyRequiredView(provider: settings.selectedProvider)
                    .padding()
            }
        }
        .navigationTitle("イベントストリーム")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let message = inputText
        inputText = ""
        isLoading = true

        // ユーザーメッセージイベントをログに追加
        let userEvent = EventLogEntry(
            type: .userMessage,
            content: message,
            timestamp: Date()
        )
        events.append(userEvent)

        // LLMメッセージリストに追加
        conversationMessages.append(.user(message))

        Task {
            do {
                let response = try await executeRequest(message: message)

                // アシスタントメッセージイベント
                let assistantEvent = EventLogEntry(
                    type: .assistantMessage,
                    content: response.summary,
                    timestamp: Date(),
                    structuredData: response
                )
                events.append(assistantEvent)

                // メッセージリストに追加
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let jsonData = try? encoder.encode(response),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    conversationMessages.append(.assistant(jsonString))
                }

            } catch {
                // エラーイベント
                let errorEvent = EventLogEntry(
                    type: .error,
                    content: error.localizedDescription,
                    timestamp: Date()
                )
                events.append(errorEvent)

                // 失敗したユーザーメッセージを削除
                if !conversationMessages.isEmpty {
                    conversationMessages.removeLast()
                }
            }
            isLoading = false
        }
    }

    private func executeRequest(message: String) async throws -> EventStreamOutput {
        let systemPrompt = """
        ユーザーの入力を分析し、構造化された情報を抽出してください。
        会話の文脈を考慮して応答してください。
        """

        switch settings.selectedProvider {
        case .anthropic:
            guard let client = settings.createAnthropicClient() else {
                throw EventDemoError.noAPIKey
            }
            let response: ChatResponse<EventStreamOutput> = try await client.chat(
                messages: conversationMessages,
                model: settings.claudeModelOption.model,
                systemPrompt: systemPrompt,
                temperature: settings.temperature,
                maxTokens: settings.maxTokens
            )
            totalUsage = TokenUsage(
                inputTokens: totalUsage.inputTokens + response.usage.inputTokens,
                outputTokens: totalUsage.outputTokens + response.usage.outputTokens
            )
            return response.result

        case .openai:
            guard let client = settings.createOpenAIClient() else {
                throw EventDemoError.noAPIKey
            }
            let response: ChatResponse<EventStreamOutput> = try await client.chat(
                messages: conversationMessages,
                model: settings.gptModelOption.model,
                systemPrompt: systemPrompt,
                temperature: settings.temperature,
                maxTokens: settings.maxTokens
            )
            totalUsage = TokenUsage(
                inputTokens: totalUsage.inputTokens + response.usage.inputTokens,
                outputTokens: totalUsage.outputTokens + response.usage.outputTokens
            )
            return response.result

        case .gemini:
            guard let client = settings.createGeminiClient() else {
                throw EventDemoError.noAPIKey
            }
            let response: ChatResponse<EventStreamOutput> = try await client.chat(
                messages: conversationMessages,
                model: settings.geminiModelOption.model,
                systemPrompt: systemPrompt,
                temperature: settings.temperature,
                maxTokens: settings.maxTokens
            )
            totalUsage = TokenUsage(
                inputTokens: totalUsage.inputTokens + response.usage.inputTokens,
                outputTokens: totalUsage.outputTokens + response.usage.outputTokens
            )
            return response.result
        }
    }

    private func clearEvents() {
        // クリアイベントを追加
        let clearEvent = EventLogEntry(
            type: .cleared,
            content: "会話履歴がクリアされました",
            timestamp: Date()
        )
        events.append(clearEvent)

        // 会話をリセット
        conversationMessages = []
        totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
    }

    private func simulateError() {
        // エラーシミュレーション用
        let errorEvent = EventLogEntry(
            type: .error,
            content: "シミュレートされたエラー: ネットワーク接続に失敗しました",
            timestamp: Date()
        )
        events.append(errorEvent)
    }
}

// MARK: - Data Models

/// イベントストリーム出力
@Structured("イベントストリーム応答")
struct EventStreamOutput {
    @StructuredField("応答の要約")
    var summary: String

    @StructuredField("検出されたトピック", .minItems(1), .maxItems(5))
    var topics: [String]

    @StructuredField("感情分析")
    var sentiment: SentimentAnalysis?

    @StructuredField("アクション提案")
    var suggestedActions: [String]?
}

@Structured("感情分析")
struct SentimentAnalysis {
    @StructuredField("感情ラベル")
    var label: String

    @StructuredField("スコア", .minimum(-1), .maximum(1))
    var score: Double

    @StructuredField("信頼度", .minimum(0), .maximum(100))
    var confidence: Int
}

/// イベントログエントリ
struct EventLogEntry: Identifiable {
    let id = UUID()
    let type: EventType
    let content: String
    let timestamp: Date
    var structuredData: EventStreamOutput?

    enum EventType {
        case userMessage
        case assistantMessage
        case error
        case cleared

        var icon: String {
            switch self {
            case .userMessage: return "arrow.up.circle.fill"
            case .assistantMessage: return "arrow.down.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            case .cleared: return "trash.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .userMessage: return .blue
            case .assistantMessage: return .green
            case .error: return .red
            case .cleared: return .orange
            }
        }

        var label: String {
            switch self {
            case .userMessage: return "USER"
            case .assistantMessage: return "ASSISTANT"
            case .error: return "ERROR"
            case .cleared: return "CLEARED"
            }
        }
    }
}

/// デモ用エラー
enum EventDemoError: LocalizedError {
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "APIキーが設定されていません"
        }
    }
}

// MARK: - DescriptionSection

private struct DescriptionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("このデモについて", systemImage: "info.circle.fill")
                .font(.headline)

            Text("""
            `Conversation` の `eventStream` を使うと、会話中のイベントを
            AsyncSequence としてリアルタイムに監視できます。

            イベントの種類：
            • userMessage - ユーザーメッセージ送信
            • assistantMessage - アシスタント応答受信
            • error - エラー発生
            • cleared - 会話クリア
            """)
            .font(.caption)
            .foregroundStyle(.secondary)

            // コード例
            CodePreview()
        }
    }
}

private struct CodePreview: View {
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup("eventStream の使い方", isExpanded: $isExpanded) {
            Text("""
            Task {
                for await event in conv.eventStream {
                    switch event {
                    case .userMessage(let msg):
                        print("👤 \\(msg.content)")
                    case .assistantMessage(let msg):
                        print("🤖 \\(msg.content)")
                    case .error(let error):
                        print("❌ \\(error)")
                    case .cleared:
                        print("🗑️ Cleared")
                    }
                }
            }
            """)
            .font(.system(.caption2, design: .monospaced))
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - EventLogView

private struct EventLogView: View {
    let events: [EventLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("イベントログ")
                    .font(.subheadline.bold())

                Spacer()

                Text("\(events.count) イベント")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if events.isEmpty {
                EmptyLogView()
            } else {
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        EventRow(event: event)
                    }
                }
            }
        }
    }
}

private struct EmptyLogView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("イベントがありません")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("メッセージを送信するとイベントが記録されます")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct EventRow: View {
    let event: EventLogEntry
    @State private var isExpanded = false

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // ヘッダー
            HStack(spacing: 6) {
                Image(systemName: event.type.icon)
                    .foregroundStyle(event.type.color)
                    .frame(width: 20)

                Text(event.type.label)
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(event.type.color)

                Spacer()

                Text(timeFormatter.string(from: event.timestamp))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // コンテンツ
            Text(event.content)
                .font(.caption)
                .lineLimit(isExpanded ? nil : 2)

            // 構造化データ（あれば）
            if let data = event.structuredData {
                EventStructuredDataView(data: data, isExpanded: $isExpanded)
            }

            // 展開/折りたたみ
            if event.content.count > 100 || event.structuredData != nil {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "折りたたむ" : "詳細を表示")
                        .font(.caption2)
                }
            }
        }
        .padding(10)
        .background(event.type.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct EventStructuredDataView: View {
    let data: EventStreamOutput
    @Binding var isExpanded: Bool

    var body: some View {
        if isExpanded {
            VStack(alignment: .leading, spacing: 6) {
                Divider()

                // トピック
                HStack(alignment: .top) {
                    Text("トピック:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    FlexibleTopicView(topics: data.topics)
                }

                // 感情分析
                if let sentiment = data.sentiment {
                    HStack {
                        Text("感情:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(sentiment.label) (スコア: \(String(format: "%.2f", sentiment.score)), 信頼度: \(sentiment.confidence)%)")
                            .font(.caption2)
                    }
                }

                // アクション提案
                if let actions = data.suggestedActions, !actions.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("アクション提案:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(actions, id: \.self) { action in
                            Text("• \(action)")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }
}

private struct FlexibleTopicView: View {
    let topics: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(topics, id: \.self) { topic in
                Text(topic)
                    .font(.system(size: 9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}

// MARK: - EventStatistics

private struct EventStatistics: View {
    let events: [EventLogEntry]
    let usage: TokenUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("統計情報")
                .font(.subheadline.bold())

            HStack(spacing: 16) {
                StatBox(
                    label: "ユーザー",
                    value: "\(events.filter { $0.type == .userMessage }.count)",
                    icon: "person.fill",
                    color: .blue
                )
                StatBox(
                    label: "アシスタント",
                    value: "\(events.filter { $0.type == .assistantMessage }.count)",
                    icon: "cpu",
                    color: .green
                )
                StatBox(
                    label: "エラー",
                    value: "\(events.filter { $0.type == .error }.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
                StatBox(
                    label: "トークン",
                    value: "\(usage.totalTokens)",
                    icon: "chart.bar.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatBox: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.bold().monospacedDigit())
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - EventInputView

private struct EventInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onClear: () -> Void
    let onSimulateError: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // アクションボタン
            HStack(spacing: 12) {
                Button {
                    onClear()
                } label: {
                    Label("クリア", systemImage: "trash")
                        .font(.caption)
                }
                .disabled(isLoading)

                Button {
                    onSimulateError()
                } label: {
                    Label("エラー発生", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .disabled(isLoading)

                Spacer()
            }

            HStack(spacing: 8) {
                TextField("メッセージを入力...", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .disabled(isLoading)

                Button {
                    onSend()
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .disabled(text.isEmpty || isLoading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EventStreamDemo()
    }
}
