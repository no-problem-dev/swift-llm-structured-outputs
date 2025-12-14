//
//  MultiProviderDemo.swift
//  LLMStructuredOutputsExample
//
//  プロバイダー比較デモ
//

import SwiftUI
import LLMStructuredOutputs

/// プロバイダー比較デモ
///
/// 同じプロンプトを複数のLLMプロバイダーに送信し、
/// 結果とパフォーマンスを比較できます。
struct MultiProviderDemo: View {
    private var settings = AppSettings.shared

    @State private var inputText = "東京スカイツリーは2012年5月に開業した電波塔で、高さは634メートルです。墨田区押上に位置し、年間約400万人が訪れる人気観光スポットです。"
    @State private var results: [ProviderResult] = []
    @State private var isRunning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - プロバイダー状態
                ProviderStatusView()

                Divider()

                // MARK: - 入力
                InputTextEditor(
                    title: "比較用テキスト",
                    text: $inputText,
                    minHeight: 100
                )

                // MARK: - 実行
                ExecuteComparisonButton(
                    isRunning: isRunning,
                    availableCount: availableProviderCount
                ) {
                    runComparison()
                }

                // MARK: - 結果比較
                if !results.isEmpty {
                    ComparisonResultsView(results: results)
                }

                // MARK: - コード例
                CodeExampleSection()
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("プロバイダー比較")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed Properties

    private var availableProviderCount: Int {
        var count = 0
        if APIKeyManager.hasAnthropicKey { count += 1 }
        if APIKeyManager.hasOpenAIKey { count += 1 }
        if APIKeyManager.hasGeminiKey { count += 1 }
        return count
    }

    // MARK: - Actions

    private func runComparison() {
        guard !inputText.isEmpty else { return }

        isRunning = true
        results = []

        Task {
            // 並列実行
            await withTaskGroup(of: ProviderResult?.self) { group in
                // Anthropic
                if APIKeyManager.hasAnthropicKey {
                    group.addTask {
                        await self.executeAnthropic()
                    }
                }

                // OpenAI
                if APIKeyManager.hasOpenAIKey {
                    group.addTask {
                        await self.executeOpenAI()
                    }
                }

                // Gemini
                if APIKeyManager.hasGeminiKey {
                    group.addTask {
                        await self.executeGemini()
                    }
                }

                // 結果を収集
                for await result in group {
                    if let result = result {
                        await MainActor.run {
                            results.append(result)
                            // 完了順にソート
                            results.sort { $0.duration < $1.duration }
                        }
                    }
                }
            }

            await MainActor.run {
                isRunning = false
            }
        }
    }

    private func executeAnthropic() async -> ProviderResult? {
        guard let client = settings.createAnthropicClient() else { return nil }

        let startTime = Date()
        do {
            let response: ChatResponse<ComparisonOutput> = try await client.chat(
                prompt: inputText,
                model: settings.claudeModelOption.model,
                systemPrompt: "テキストからランドマーク情報を抽出してください。",
                temperature: settings.temperature,
                maxTokens: settings.maxTokens
            )
            let duration = Date().timeIntervalSince(startTime)
            return ProviderResult(
                provider: .anthropic,
                model: settings.claudeModelOption.model.id,
                output: response.result,
                usage: response.usage,
                duration: duration,
                error: nil
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return ProviderResult(
                provider: .anthropic,
                model: settings.claudeModelOption.model.id,
                output: nil,
                usage: nil,
                duration: duration,
                error: error.localizedDescription
            )
        }
    }

    private func executeOpenAI() async -> ProviderResult? {
        guard let client = settings.createOpenAIClient() else { return nil }

        let startTime = Date()
        do {
            let response: ChatResponse<ComparisonOutput> = try await client.chat(
                prompt: inputText,
                model: settings.gptModelOption.model,
                systemPrompt: "テキストからランドマーク情報を抽出してください。",
                temperature: settings.temperature,
                maxTokens: settings.maxTokens
            )
            let duration = Date().timeIntervalSince(startTime)
            return ProviderResult(
                provider: .openai,
                model: settings.gptModelOption.model.id,
                output: response.result,
                usage: response.usage,
                duration: duration,
                error: nil
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return ProviderResult(
                provider: .openai,
                model: settings.gptModelOption.model.id,
                output: nil,
                usage: nil,
                duration: duration,
                error: error.localizedDescription
            )
        }
    }

    private func executeGemini() async -> ProviderResult? {
        guard let client = settings.createGeminiClient() else { return nil }

        let startTime = Date()
        do {
            let response: ChatResponse<ComparisonOutput> = try await client.chat(
                prompt: inputText,
                model: settings.geminiModelOption.model,
                systemPrompt: "テキストからランドマーク情報を抽出してください。",
                temperature: settings.temperature,
                maxTokens: settings.maxTokens
            )
            let duration = Date().timeIntervalSince(startTime)
            return ProviderResult(
                provider: .gemini,
                model: settings.geminiModelOption.model.rawValue,
                output: response.result,
                usage: response.usage,
                duration: duration,
                error: nil
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return ProviderResult(
                provider: .gemini,
                model: settings.geminiModelOption.model.rawValue,
                output: nil,
                usage: nil,
                duration: duration,
                error: error.localizedDescription
            )
        }
    }
}

// MARK: - Data Models

/// 比較用出力
@Structured("ランドマーク情報")
struct ComparisonOutput {
    @StructuredField("名称")
    var name: String

    @StructuredField("種類")
    var type: String

    @StructuredField("場所")
    var location: String?

    @StructuredField("開業/設立年")
    var establishedYear: Int?

    @StructuredField("特徴的な数値")
    var keyFigures: [KeyFigure]?

    @StructuredField("説明", .maxLength(200))
    var description: String
}

@Structured("数値情報")
struct KeyFigure {
    @StructuredField("項目")
    var label: String

    @StructuredField("値")
    var value: String

    @StructuredField("単位")
    var unit: String?
}

/// プロバイダー結果
struct ProviderResult: Identifiable {
    let id = UUID()
    let provider: AppSettings.Provider
    let model: String
    let output: ComparisonOutput?
    let usage: TokenUsage?
    let duration: TimeInterval
    let error: String?

    var isSuccess: Bool {
        output != nil
    }
}

// MARK: - DescriptionSection

private struct DescriptionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("このデモについて", systemImage: "info.circle.fill")
                .font(.headline)

            Text("""
            同じプロンプトを複数のLLMプロバイダーに並列送信し、
            結果とパフォーマンスを比較します。

            比較項目：
            • 応答時間（レイテンシ）
            • トークン使用量
            • 抽出結果の精度
            • エラー発生有無
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ProviderStatusView

private struct ProviderStatusView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("プロバイダー状態")
                .font(.subheadline.bold())

            HStack(spacing: 12) {
                ProviderStatusChip(
                    name: "Anthropic",
                    isAvailable: APIKeyManager.hasAnthropicKey,
                    color: .orange
                )
                ProviderStatusChip(
                    name: "OpenAI",
                    isAvailable: APIKeyManager.hasOpenAIKey,
                    color: .green
                )
                ProviderStatusChip(
                    name: "Gemini",
                    isAvailable: APIKeyManager.hasGeminiKey,
                    color: .blue
                )
            }
        }
    }
}

private struct ProviderStatusChip: View {
    let name: String
    let isAvailable: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isAvailable ? .green : .red)
            Text(name)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(isAvailable ? 0.2 : 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(isAvailable ? 1 : 0.5)
    }
}

// MARK: - ExecuteComparisonButton

private struct ExecuteComparisonButton: View {
    let isRunning: Bool
    let availableCount: Int
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "play.fill")
                }
                Text(isRunning ? "比較実行中..." : "\(availableCount)プロバイダーで比較実行")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(availableCount > 0 ? Color.blue : Color.gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isRunning || availableCount == 0)
    }
}

// MARK: - ComparisonResultsView

private struct ComparisonResultsView: View {
    let results: [ProviderResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // サマリー
            ComparisonSummary(results: results)

            Divider()

            // 個別結果
            Text("詳細結果")
                .font(.subheadline.bold())

            ForEach(results) { result in
                ProviderResultCard(result: result, rank: rankFor(result))
            }
        }
    }

    private func rankFor(_ result: ProviderResult) -> Int {
        guard let index = results.firstIndex(where: { $0.id == result.id }) else {
            return 0
        }
        return index + 1
    }
}

private struct ComparisonSummary: View {
    let results: [ProviderResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("比較サマリー")
                .font(.subheadline.bold())

            HStack(spacing: 16) {
                // 最速
                if let fastest = results.first(where: { $0.isSuccess }) {
                    SummaryChip(
                        title: "最速",
                        value: fastest.provider.rawValue,
                        detail: String(format: "%.2f秒", fastest.duration),
                        color: .green
                    )
                }

                // 最小トークン
                if let minTokens = results
                    .filter({ $0.usage != nil })
                    .min(by: { ($0.usage?.totalTokens ?? 0) < ($1.usage?.totalTokens ?? 0) }) {
                    SummaryChip(
                        title: "最小トークン",
                        value: minTokens.provider.rawValue,
                        detail: "\(minTokens.usage?.totalTokens ?? 0) tokens",
                        color: .blue
                    )
                }

                // 成功率
                let successCount = results.filter { $0.isSuccess }.count
                SummaryChip(
                    title: "成功率",
                    value: "\(successCount)/\(results.count)",
                    detail: String(format: "%.0f%%", Double(successCount) / Double(results.count) * 100),
                    color: successCount == results.count ? .green : .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SummaryChip: View {
    let title: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProviderResultCard: View {
    let result: ProviderResult
    let rank: Int
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー
            HStack {
                // ランク
                RankBadge(rank: rank)

                // プロバイダー名
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.provider.rawValue)
                        .font(.caption.bold())
                    Text(result.model)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // ステータス
                if result.isSuccess {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f秒", result.duration))
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(.green)
                        if let usage = result.usage {
                            Text("\(usage.totalTokens) tokens")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            // エラー表示
            if let error = result.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // 抽出結果（展開可能）
            if let output = result.output {
                DisclosureGroup("抽出結果", isExpanded: $isExpanded) {
                    OutputPreview(output: output)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(result.isSuccess ? Color(.systemGray6) : Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct RankBadge: View {
    let rank: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(rankColor)
                .frame(width: 28, height: 28)

            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)
            } else {
                Text("\(rank)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .secondary
        }
    }
}

private struct OutputPreview: View {
    let output: ComparisonOutput

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            OutputRow(label: "名称", value: output.name)
            OutputRow(label: "種類", value: output.type)
            if let location = output.location {
                OutputRow(label: "場所", value: location)
            }
            if let year = output.establishedYear {
                OutputRow(label: "設立年", value: "\(year)年")
            }
            if let figures = output.keyFigures, !figures.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("数値情報:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(figures, id: \.label) { figure in
                        Text("• \(figure.label): \(figure.value)\(figure.unit ?? "")")
                            .font(.caption2)
                    }
                }
            }
            OutputRow(label: "説明", value: output.description)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct OutputRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.caption2)
        }
    }
}

// MARK: - CodeExampleSection

private struct CodeExampleSection: View {
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup("コード例", isExpanded: $isExpanded) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(codeExample)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private var codeExample: String {
        """
        // 複数プロバイダーで並列実行
        await withTaskGroup(of: Result.self) { group in
            // Anthropic
            group.addTask {
                let client = AnthropicClient(apiKey: "...")
                return try await client.generate(
                    prompt: text,
                    model: .sonnet
                )
            }

            // OpenAI
            group.addTask {
                let client = OpenAIClient(apiKey: "...")
                return try await client.generate(
                    prompt: text,
                    model: .gpt4o
                )
            }

            // Gemini
            group.addTask {
                let client = GeminiClient(apiKey: "...")
                return try await client.generate(
                    prompt: text,
                    model: .flash
                )
            }

            // 結果を収集
            for await result in group {
                print(result)
            }
        }
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MultiProviderDemo()
    }
}
