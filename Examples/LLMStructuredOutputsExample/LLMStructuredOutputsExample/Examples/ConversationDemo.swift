//
//  ConversationDemo.swift
//  LLMStructuredOutputsExample
//
//  マルチターン会話デモ
//

import SwiftUI
import LLMStructuredOutputs

/// マルチターン会話デモ
///
/// `Conversation` Actor を使ったマルチターン会話を体験できます。
/// 会話履歴が自動追跡され、文脈を理解した応答が得られます。
struct ConversationDemo: View {
    private var settings = AppSettings.shared

    @State private var inputText = ""
    @State private var conversationState = ConversationState()
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 説明
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DescriptionSection()

                    Divider()

                    // MARK: - 会話履歴
                    ConversationHistoryView(state: conversationState)

                    // MARK: - トークン使用量
                    if conversationState.totalUsage.totalTokens > 0 {
                        TokenUsageSummary(usage: conversationState.totalUsage)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)

            Divider()

            // MARK: - 入力エリア
            if settings.isCurrentProviderAvailable {
                MessageInputView(
                    text: $inputText,
                    isLoading: isLoading,
                    onSend: sendMessage,
                    onClear: clearConversation
                )
            } else {
                APIKeyRequiredView(provider: settings.selectedProvider)
                    .padding()
            }
        }
        .navigationTitle("マルチターン会話")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let message = inputText
        inputText = ""
        isLoading = true

        // ユーザーメッセージを即座に表示
        conversationState.messages.append(
            ChatMessage(role: .user, content: message)
        )

        Task {
            do {
                let response = try await executeConversation(message: message)
                conversationState.messages.append(
                    ChatMessage(role: .assistant, content: response.content, structuredData: response.data)
                )
                conversationState.totalUsage = TokenUsage(
                    inputTokens: conversationState.totalUsage.inputTokens + response.usage.inputTokens,
                    outputTokens: conversationState.totalUsage.outputTokens + response.usage.outputTokens
                )
            } catch {
                conversationState.messages.append(
                    ChatMessage(role: .error, content: error.localizedDescription)
                )
            }
            isLoading = false
        }
    }

    private func executeConversation(message: String) async throws -> ConversationResponse {
        // 会話履歴からLLMMessageを構築
        let llmMessages = conversationState.messages.compactMap { msg -> LLMMessage? in
            switch msg.role {
            case .user:
                return .user(msg.content)
            case .assistant:
                // 構造化データがあればそれを含める
                if let data = msg.structuredData {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    if let jsonData = try? encoder.encode(data),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        return .assistant(jsonString)
                    }
                }
                return .assistant(msg.content)
            case .error:
                return nil
            }
        }

        let systemPrompt = """
        あなたは情報抽出の専門家です。ユーザーからの質問や情報に基づいて、
        構造化されたデータを抽出・生成します。

        会話の文脈を理解し、前の回答を踏まえた応答をしてください。
        例えば「その人の」「さっきの」などの指示語は、会話履歴から適切に解釈してください。
        """

        switch settings.selectedProvider {
        case .anthropic:
            guard let client = settings.createAnthropicClient() else {
                throw NSError(domain: "ConversationDemo", code: 1, userInfo: [NSLocalizedDescriptionKey: "APIキーが設定されていません"])
            }
            let response: ChatResponse<ConversationOutput> = try await client.chat(
                messages: llmMessages,
                model: settings.claudeModelOption.model,
                systemPrompt: systemPrompt,
                temperature: settings.temperature,
                maxTokens: settings.maxTokens
            )
            return ConversationResponse(
                content: response.result.summary,
                data: response.result,
                usage: response.usage
            )

        case .openai:
            guard let client = settings.createOpenAIClient() else {
                throw NSError(domain: "ConversationDemo", code: 1, userInfo: [NSLocalizedDescriptionKey: "APIキーが設定されていません"])
            }
            let response: ChatResponse<ConversationOutput> = try await client.chat(
                messages: llmMessages,
                model: settings.gptModelOption.model,
                systemPrompt: systemPrompt,
                temperature: settings.temperature,
                maxTokens: settings.maxTokens
            )
            return ConversationResponse(
                content: response.result.summary,
                data: response.result,
                usage: response.usage
            )

        case .gemini:
            guard let client = settings.createGeminiClient() else {
                throw NSError(domain: "ConversationDemo", code: 1, userInfo: [NSLocalizedDescriptionKey: "APIキーが設定されていません"])
            }
            let response: ChatResponse<ConversationOutput> = try await client.chat(
                messages: llmMessages,
                model: settings.geminiModelOption.model,
                systemPrompt: systemPrompt,
                temperature: settings.temperature,
                maxTokens: settings.maxTokens
            )
            return ConversationResponse(
                content: response.result.summary,
                data: response.result,
                usage: response.usage
            )
        }
    }

    private func clearConversation() {
        conversationState = ConversationState()
    }
}

// MARK: - Data Models

/// 会話の出力形式
@Structured("会話の応答")
struct ConversationOutput {
    @StructuredField("応答の要約")
    var summary: String

    @StructuredField("抽出された人物情報（該当する場合）")
    var person: ExtractedPerson?

    @StructuredField("抽出された場所情報（該当する場合）")
    var location: ExtractedLocation?

    @StructuredField("抽出された数値・統計（該当する場合）")
    var statistics: [ExtractedStatistic]?

    @StructuredField("応答の信頼度", .minimum(0), .maximum(100))
    var confidence: Int

    @StructuredField("追加の質問や確認事項")
    var followUpQuestions: [String]?
}

@Structured("人物情報")
struct ExtractedPerson {
    @StructuredField("名前")
    var name: String?

    @StructuredField("年齢")
    var age: Int?

    @StructuredField("職業")
    var occupation: String?

    @StructuredField("所属組織")
    var organization: String?
}

@Structured("場所情報")
struct ExtractedLocation {
    @StructuredField("場所名")
    var name: String?

    @StructuredField("種類")
    var type: String?

    @StructuredField("関連情報")
    var details: String?
}

@Structured("統計情報")
struct ExtractedStatistic {
    @StructuredField("項目名")
    var label: String

    @StructuredField("値")
    var value: String

    @StructuredField("単位")
    var unit: String?
}

/// 会話の状態
struct ConversationState {
    var messages: [ChatMessage] = []
    var totalUsage: TokenUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
}

/// チャットメッセージ
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    var structuredData: ConversationOutput?

    enum MessageRole {
        case user
        case assistant
        case error
    }
}

/// 会話応答
struct ConversationResponse {
    let content: String
    let data: ConversationOutput
    let usage: TokenUsage
}

// MARK: - DescriptionSection

private struct DescriptionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("このデモについて", systemImage: "info.circle.fill")
                .font(.headline)

            Text("""
            `Conversation` Actor を使うと、会話履歴が自動追跡され、
            文脈を理解したマルチターン会話が実現できます。

            「山田太郎さんは35歳のエンジニアです」と入力した後、
            「その人の職業は？」と聞くと、文脈から回答します。
            """)
            .font(.caption)
            .foregroundStyle(.secondary)

            // サンプル会話例
            VStack(alignment: .leading, spacing: 4) {
                Text("会話例：")
                    .font(.caption.bold())
                Text("1️⃣ 「山田太郎さん（35歳）は東京のスタートアップでCTOをしています」")
                Text("2️⃣ 「その人の年齢は？」")
                Text("3️⃣ 「どこで働いていますか？」")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - ConversationHistoryView

private struct ConversationHistoryView: View {
    let state: ConversationState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("会話履歴")
                    .font(.subheadline.bold())

                Spacer()

                if !state.messages.isEmpty {
                    Text("\(state.messages.filter { $0.role != .error }.count / 2) ターン")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if state.messages.isEmpty {
                EmptyConversationView()
            } else {
                VStack(spacing: 12) {
                    ForEach(state.messages) { message in
                        MessageBubble(message: message)
                    }
                }
            }
        }
    }
}

private struct EmptyConversationView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("会話を開始してください")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // ラベル
                HStack(spacing: 4) {
                    Image(systemName: iconName)
                        .font(.caption2)
                    Text(roleName)
                        .font(.caption2.bold())
                }
                .foregroundStyle(labelColor)

                // メッセージ内容
                Text(message.content)
                    .font(.caption)
                    .padding(10)
                    .background(bubbleColor)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // 構造化データ（あれば）
                if let data = message.structuredData {
                    StructuredDataPreview(data: data)
                }
            }

            if message.role != .user {
                Spacer(minLength: 40)
            }
        }
    }

    private var iconName: String {
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return "cpu"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var roleName: String {
        switch message.role {
        case .user: return "あなた"
        case .assistant: return "アシスタント"
        case .error: return "エラー"
        }
    }

    private var labelColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return .green
        case .error: return .red
        }
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return Color(.systemGray5)
        case .error: return .red.opacity(0.2)
        }
    }
}

private struct StructuredDataPreview: View {
    let data: ConversationOutput
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup("構造化データ", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                // 人物情報
                if let person = data.person, person.name != nil {
                    DataRow(icon: "person.fill", label: "人物", value: formatPerson(person))
                }

                // 場所情報
                if let location = data.location, location.name != nil {
                    DataRow(icon: "mappin.circle.fill", label: "場所", value: formatLocation(location))
                }

                // 統計情報
                if let stats = data.statistics, !stats.isEmpty {
                    DataRow(icon: "chart.bar.fill", label: "統計", value: formatStatistics(stats))
                }

                // 信頼度
                DataRow(icon: "checkmark.seal.fill", label: "信頼度", value: "\(data.confidence)%")

                // フォローアップ
                if let questions = data.followUpQuestions, !questions.isEmpty {
                    DataRow(icon: "questionmark.circle.fill", label: "追加質問", value: questions.joined(separator: "\n"))
                }
            }
            .padding(8)
        }
        .font(.caption2)
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatPerson(_ person: ExtractedPerson) -> String {
        var parts: [String] = []
        if let name = person.name { parts.append(name) }
        if let age = person.age { parts.append("\(age)歳") }
        if let occupation = person.occupation { parts.append(occupation) }
        if let org = person.organization { parts.append(org) }
        return parts.joined(separator: " / ")
    }

    private func formatLocation(_ location: ExtractedLocation) -> String {
        var parts: [String] = []
        if let name = location.name { parts.append(name) }
        if let type = location.type { parts.append("(\(type))") }
        if let details = location.details { parts.append(details) }
        return parts.joined(separator: " ")
    }

    private func formatStatistics(_ stats: [ExtractedStatistic]) -> String {
        stats.map { stat in
            if let unit = stat.unit {
                return "\(stat.label): \(stat.value) \(unit)"
            }
            return "\(stat.label): \(stat.value)"
        }.joined(separator: "\n")
    }
}

private struct DataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            Text(value)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - TokenUsageSummary

private struct TokenUsageSummary: View {
    let usage: TokenUsage

    var body: some View {
        HStack {
            Label("累計トークン", systemImage: "chart.bar.fill")
                .font(.caption.bold())

            Spacer()

            HStack(spacing: 12) {
                UsageChip(label: "入力", value: usage.inputTokens, color: .blue)
                UsageChip(label: "出力", value: usage.outputTokens, color: .green)
                UsageChip(label: "合計", value: usage.totalTokens, color: .purple)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct UsageChip: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - MessageInputView

private struct MessageInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // クリアボタン
                Button {
                    onClear()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .disabled(isLoading)

                // テキストフィールド
                TextField("メッセージを入力...", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .disabled(isLoading)

                // 送信ボタン
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
        ConversationDemo()
    }
}
