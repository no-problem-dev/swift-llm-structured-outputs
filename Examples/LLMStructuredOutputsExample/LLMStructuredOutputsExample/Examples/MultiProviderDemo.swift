//
//  MultiProviderDemo.swift
//  LLMStructuredOutputsExample
//
//  プロバイダー比較デモ（拡張版）
//

import SwiftUI
import LLMStructuredOutputs

/// プロバイダー比較デモ
///
/// 複数のLLMプロバイダーに同じプロンプトを送信し、
/// 結果とパフォーマンスを比較できます。
struct MultiProviderDemo: View {
    private var settings = AppSettings.shared

    // MARK: - State

    // モデル選択（プロバイダーごと）
    @State private var selectedClaudeModel: AppSettings.ClaudeModelOption = .sonnet
    @State private var selectedGPTModel: AppSettings.GPTModelOption = .gpt4o
    @State private var selectedGeminiModel: AppSettings.GeminiModelOption = .flash25

    // テストケース選択
    @State private var selectedCategory: TestCaseCategory = .extraction
    @State private var selectedTestCase: ComparisonTestCase = ComparisonTestCase.basicLandmarkExtraction

    // カスタム入力モード
    @State private var useCustomInput = false
    @State private var customSystemPrompt = "テキストからランドマーク情報を抽出してください。"
    @State private var customInputText = ""

    // 実行状態
    @State private var results: [ComparisonResultData] = []
    @State private var isRunning = false
    @State private var runningProviders: Set<AppSettings.Provider> = []

    // UI状態
    @State private var showModelSelection = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - プロバイダー設定
                ProviderConfigSection(
                    selectedClaudeModel: $selectedClaudeModel,
                    selectedGPTModel: $selectedGPTModel,
                    selectedGeminiModel: $selectedGeminiModel,
                    showModelSelection: $showModelSelection
                )

                Divider()

                // MARK: - 入力モード切り替え
                InputModeToggle(useCustomInput: $useCustomInput)

                // MARK: - テストケース選択 or カスタム入力
                if useCustomInput {
                    CustomInputSection(
                        systemPrompt: $customSystemPrompt,
                        inputText: $customInputText
                    )
                } else {
                    TestCaseSelectionSection(
                        selectedCategory: $selectedCategory,
                        selectedTestCase: $selectedTestCase
                    )

                    Divider()

                    // MARK: - テストケース詳細
                    TestCaseDetailSection(testCase: selectedTestCase)
                }

                // MARK: - 実行
                ExecuteComparisonButton(
                    isRunning: isRunning,
                    availableCount: availableProviderCount,
                    isCustomMode: useCustomInput,
                    hasCustomInput: !customInputText.isEmpty
                ) {
                    runComparison()
                }

                // MARK: - 結果比較
                if !results.isEmpty {
                    ComparisonResultsSection(
                        results: results,
                        testCase: useCustomInput ? nil : selectedTestCase,
                        runningProviders: runningProviders
                    )
                }
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
        guard !isRunning else { return }

        isRunning = true
        results = []
        runningProviders = []

        Task {
            await withTaskGroup(of: ComparisonResultData?.self) { group in
                // Anthropic
                if APIKeyManager.hasAnthropicKey {
                    await MainActor.run {
                        runningProviders.insert(.anthropic)
                    }
                    group.addTask {
                        await self.executeForProvider(.anthropic)
                    }
                }

                // OpenAI
                if APIKeyManager.hasOpenAIKey {
                    await MainActor.run {
                        runningProviders.insert(.openai)
                    }
                    group.addTask {
                        await self.executeForProvider(.openai)
                    }
                }

                // Gemini
                if APIKeyManager.hasGeminiKey {
                    await MainActor.run {
                        runningProviders.insert(.gemini)
                    }
                    group.addTask {
                        await self.executeForProvider(.gemini)
                    }
                }

                // 結果を収集
                for await result in group {
                    if let result = result {
                        await MainActor.run {
                            results.append(result)
                            results.sort { $0.duration < $1.duration }
                            runningProviders.remove(result.provider)
                        }
                    }
                }
            }

            await MainActor.run {
                isRunning = false
                runningProviders = []
            }
        }
    }

    private func executeForProvider(_ provider: AppSettings.Provider) async -> ComparisonResultData? {
        let startTime = Date()

        // カスタム入力モードの場合
        if useCustomInput {
            return await executeCustomInput(
                provider: provider,
                systemPrompt: customSystemPrompt,
                inputText: customInputText,
                startTime: startTime
            )
        }

        // テストケースモードの場合
        let testCase = selectedTestCase
        switch provider {
        case .anthropic:
            return await executeAnthropic(testCase: testCase, startTime: startTime)
        case .openai:
            return await executeOpenAI(testCase: testCase, startTime: startTime)
        case .gemini:
            return await executeGemini(testCase: testCase, startTime: startTime)
        }
    }

    // MARK: - Custom Input Execution

    private func executeCustomInput(
        provider: AppSettings.Provider,
        systemPrompt: String,
        inputText: String,
        startTime: Date
    ) async -> ComparisonResultData? {
        switch provider {
        case .anthropic:
            guard let client = settings.createAnthropicClient() else { return nil }
            let model = selectedClaudeModel.model
            do {
                let response: ChatResponse<LandmarkOutput> = try await client.chat(
                    input: LLMInput(inputText),
                    model: model,
                    systemPrompt: systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .anthropic,
                    model: model.id,
                    testCaseId: "custom",
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )
            } catch {
                return ComparisonResultData(
                    provider: .anthropic,
                    model: model.id,
                    testCaseId: "custom",
                    duration: Date().timeIntervalSince(startTime),
                    error: error.localizedDescription
                )
            }

        case .openai:
            guard let client = settings.createOpenAIClient() else { return nil }
            let model = selectedGPTModel.model
            do {
                let response: ChatResponse<LandmarkOutput> = try await client.chat(
                    input: LLMInput(inputText),
                    model: model,
                    systemPrompt: systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .openai,
                    model: model.id,
                    testCaseId: "custom",
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )
            } catch {
                return ComparisonResultData(
                    provider: .openai,
                    model: model.id,
                    testCaseId: "custom",
                    duration: Date().timeIntervalSince(startTime),
                    error: error.localizedDescription
                )
            }

        case .gemini:
            guard let client = settings.createGeminiClient() else { return nil }
            let model = selectedGeminiModel.model
            do {
                let response: ChatResponse<LandmarkOutput> = try await client.chat(
                    input: LLMInput(inputText),
                    model: model,
                    systemPrompt: systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .gemini,
                    model: model.rawValue,
                    testCaseId: "custom",
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )
            } catch {
                return ComparisonResultData(
                    provider: .gemini,
                    model: model.rawValue,
                    testCaseId: "custom",
                    duration: Date().timeIntervalSince(startTime),
                    error: error.localizedDescription
                )
            }
        }
    }

    // MARK: - Provider Execution

    private func executeAnthropic(testCase: ComparisonTestCase, startTime: Date) async -> ComparisonResultData? {
        guard let client = settings.createAnthropicClient() else { return nil }
        let model = selectedClaudeModel.model

        do {
            switch testCase.outputType {
            case .landmark:
                let response: ChatResponse<LandmarkOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .anthropic,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .person:
                let response: ChatResponse<PersonOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .anthropic,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .product:
                let response: ChatResponse<ProductOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .anthropic,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .meeting:
                let response: ChatResponse<MeetingOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .anthropic,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .organization:
                let response: ChatResponse<OrganizationOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .anthropic,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .recipe:
                let response: ChatResponse<RecipeOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .anthropic,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .event:
                let response: ChatResponse<EventOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .anthropic,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .calculation:
                let response: ChatResponse<ProductOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .anthropic,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )
            }
        } catch {
            return ComparisonResultData(
                provider: .anthropic,
                model: model.id,
                testCase: testCase,
                duration: Date().timeIntervalSince(startTime),
                error: error.localizedDescription
            )
        }
    }

    private func executeOpenAI(testCase: ComparisonTestCase, startTime: Date) async -> ComparisonResultData? {
        guard let client = settings.createOpenAIClient() else { return nil }
        let model = selectedGPTModel.model

        do {
            switch testCase.outputType {
            case .landmark:
                let response: ChatResponse<LandmarkOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .openai,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .person:
                let response: ChatResponse<PersonOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .openai,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .product:
                let response: ChatResponse<ProductOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .openai,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .meeting:
                let response: ChatResponse<MeetingOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .openai,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .organization:
                let response: ChatResponse<OrganizationOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .openai,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .recipe:
                let response: ChatResponse<RecipeOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .openai,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .event:
                let response: ChatResponse<EventOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .openai,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .calculation:
                let response: ChatResponse<ProductOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .openai,
                    model: model.id,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )
            }
        } catch {
            return ComparisonResultData(
                provider: .openai,
                model: model.id,
                testCase: testCase,
                duration: Date().timeIntervalSince(startTime),
                error: error.localizedDescription
            )
        }
    }

    private func executeGemini(testCase: ComparisonTestCase, startTime: Date) async -> ComparisonResultData? {
        guard let client = settings.createGeminiClient() else { return nil }
        let model = selectedGeminiModel.model

        do {
            switch testCase.outputType {
            case .landmark:
                let response: ChatResponse<LandmarkOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .gemini,
                    model: model.rawValue,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .person:
                let response: ChatResponse<PersonOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .gemini,
                    model: model.rawValue,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .product:
                let response: ChatResponse<ProductOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .gemini,
                    model: model.rawValue,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .meeting:
                let response: ChatResponse<MeetingOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .gemini,
                    model: model.rawValue,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .organization:
                let response: ChatResponse<OrganizationOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .gemini,
                    model: model.rawValue,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .recipe:
                let response: ChatResponse<RecipeOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .gemini,
                    model: model.rawValue,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .event:
                let response: ChatResponse<EventOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .gemini,
                    model: model.rawValue,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )

            case .calculation:
                let response: ChatResponse<ProductOutput> = try await client.chat(
                    input: LLMInput(testCase.input),
                    model: model,
                    systemPrompt: testCase.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                return ComparisonResultData(
                    provider: .gemini,
                    model: model.rawValue,
                    testCase: testCase,
                    output: response.result,
                    usage: response.usage,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                )
            }
        } catch {
            return ComparisonResultData(
                provider: .gemini,
                model: model.rawValue,
                testCase: testCase,
                duration: Date().timeIntervalSince(startTime),
                error: error.localizedDescription
            )
        }
    }
}

// MARK: - Description Section

private struct DescriptionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("プロバイダー比較", systemImage: "chart.bar.xaxis")
                .font(.headline)

            Text("""
            同じテストケースを複数のLLMプロバイダーに送信し、結果を比較します。

            比較項目：応答時間、トークン使用量、抽出精度
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Provider Config Section

private struct ProviderConfigSection: View {
    @Binding var selectedClaudeModel: AppSettings.ClaudeModelOption
    @Binding var selectedGPTModel: AppSettings.GPTModelOption
    @Binding var selectedGeminiModel: AppSettings.GeminiModelOption
    @Binding var showModelSelection: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("プロバイダー設定")
                    .font(.subheadline.bold())

                Spacer()

                Button {
                    showModelSelection.toggle()
                } label: {
                    Label(
                        showModelSelection ? "閉じる" : "モデル選択",
                        systemImage: showModelSelection ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption)
                }
            }

            // プロバイダー状態
            HStack(spacing: 12) {
                ProviderChip(
                    name: "Claude",
                    model: selectedClaudeModel.model.id,
                    isAvailable: APIKeyManager.hasAnthropicKey,
                    color: .orange
                )
                ProviderChip(
                    name: "GPT",
                    model: selectedGPTModel.model.id,
                    isAvailable: APIKeyManager.hasOpenAIKey,
                    color: .green
                )
                ProviderChip(
                    name: "Gemini",
                    model: selectedGeminiModel.model.rawValue,
                    isAvailable: APIKeyManager.hasGeminiKey,
                    color: .blue
                )
            }

            // モデル選択（展開時）
            if showModelSelection {
                VStack(spacing: 12) {
                    if APIKeyManager.hasAnthropicKey {
                        ModelPicker(
                            title: "Claude",
                            selection: $selectedClaudeModel,
                            options: AppSettings.ClaudeModelOption.allCases,
                            color: .orange
                        )
                    }

                    if APIKeyManager.hasOpenAIKey {
                        ModelPicker(
                            title: "GPT",
                            selection: $selectedGPTModel,
                            options: AppSettings.GPTModelOption.allCases,
                            color: .green
                        )
                    }

                    if APIKeyManager.hasGeminiKey {
                        ModelPicker(
                            title: "Gemini",
                            selection: $selectedGeminiModel,
                            options: AppSettings.GeminiModelOption.allCases,
                            color: .blue
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct ProviderChip: View {
    let name: String
    let model: String
    let isAvailable: Bool
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(isAvailable ? .green : .red)
                Text(name)
                    .font(.caption.bold())
            }
            Text(model)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(isAvailable ? 0.15 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .opacity(isAvailable ? 1 : 0.5)
    }
}

private struct ModelPicker<T: Hashable & Identifiable & RawRepresentable>: View where T.RawValue == String {
    let title: String
    @Binding var selection: T
    let options: [T]
    let color: Color

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(color)
                .frame(width: 60, alignment: .leading)

            Picker("", selection: $selection) {
                ForEach(options, id: \.id) { option in
                    Text(option.rawValue)
                        .font(.caption)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(color)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Input Mode Toggle

private struct InputModeToggle: View {
    @Binding var useCustomInput: Bool

    var body: some View {
        HStack {
            Text("入力モード")
                .font(.subheadline.bold())

            Spacer()

            Picker("", selection: $useCustomInput) {
                Text("テストケース").tag(false)
                Text("カスタム入力").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }
}

// MARK: - Custom Input Section

private struct CustomInputSection: View {
    @Binding var systemPrompt: String
    @Binding var inputText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // システムプロンプト
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.secondary)
                    Text("システムプロンプト")
                        .font(.caption.bold())
                }

                TextField("例: テキストからランドマーク情報を抽出してください", text: $systemPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            // 入力テキスト
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(.secondary)
                    Text("入力テキスト")
                        .font(.caption.bold())
                }

                TextField("抽出したいテキストを入力...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...10)
            }

            // 出力形式の説明
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("出力形式: LandmarkOutput（名称、種類、所在地、設立年、高さなど）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Test Case Selection Section

private struct TestCaseSelectionSection: View {
    @Binding var selectedCategory: TestCaseCategory
    @Binding var selectedTestCase: ComparisonTestCase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("テストケース")
                .font(.subheadline.bold())

            // カテゴリ選択
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TestCaseCategory.allCases) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                            // カテゴリ変更時、そのカテゴリの最初のテストケースを選択
                            if let first = ComparisonTestCase.cases(for: category).first {
                                selectedTestCase = first
                            }
                        }
                    }
                }
            }

            // テストケース選択
            let cases = ComparisonTestCase.cases(for: selectedCategory)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cases) { testCase in
                        TestCaseChip(
                            testCase: testCase,
                            isSelected: selectedTestCase.id == testCase.id
                        ) {
                            selectedTestCase = testCase
                        }
                    }
                }
            }
        }
    }
}

private struct CategoryChip: View {
    let category: TestCaseCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption2)
                Text(category.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TestCaseChip: View {
    let testCase: ComparisonTestCase
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(testCase.title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.8) : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Test Case Detail Section

private struct TestCaseDetailSection: View {
    let testCase: ComparisonTestCase
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup("テストケース詳細", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                // 説明
                VStack(alignment: .leading, spacing: 4) {
                    Text("目的")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(testCase.description)
                        .font(.caption)
                }

                Divider()

                // 入力テキスト
                VStack(alignment: .leading, spacing: 4) {
                    Text("入力テキスト")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(testCase.input)
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // システムプロンプト
                VStack(alignment: .leading, spacing: 4) {
                    Text("システムプロンプト")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(testCase.systemPrompt)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.vertical, 8)
        }
        .font(.caption.bold())
    }
}

// MARK: - Execute Button

private struct ExecuteComparisonButton: View {
    let isRunning: Bool
    let availableCount: Int
    let isCustomMode: Bool
    let hasCustomInput: Bool
    let action: () -> Void

    private var isDisabled: Bool {
        isRunning || availableCount == 0 || (isCustomMode && !hasCustomInput)
    }

    private var buttonText: String {
        if isRunning {
            return "比較実行中..."
        } else if isCustomMode && !hasCustomInput {
            return "入力テキストを入力してください"
        } else {
            return "\(availableCount)プロバイダーで比較実行"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "play.fill")
                }
                Text(buttonText)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isDisabled ? Color.gray : Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isDisabled)
    }
}

// MARK: - Comparison Results Section

private struct ComparisonResultsSection: View {
    let results: [ComparisonResultData]
    let testCase: ComparisonTestCase?
    let runningProviders: Set<AppSettings.Provider>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // サマリー
            ResultSummary(results: results)

            Divider()

            // 詳細結果
            Text("詳細結果")
                .font(.subheadline.bold())

            // 実行中プロバイダー
            ForEach(Array(runningProviders), id: \.self) { provider in
                RunningProviderCard(provider: provider)
            }

            // 完了した結果
            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                ResultCard(result: result, rank: index + 1)
            }
        }
    }
}

private struct ResultSummary: View {
    let results: [ComparisonResultData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("比較サマリー")
                .font(.subheadline.bold())

            HStack(spacing: 16) {
                // 最速
                if let fastest = results.first(where: { $0.isSuccess }) {
                    SummaryItem(
                        title: "最速",
                        value: fastest.provider.shortName,
                        detail: String(format: "%.2f秒", fastest.duration),
                        color: .green
                    )
                }

                // 最小トークン
                if let minTokens = results
                    .filter({ $0.usage != nil })
                    .min(by: { ($0.usage?.totalTokens ?? 0) < ($1.usage?.totalTokens ?? 0) }) {
                    SummaryItem(
                        title: "最小トークン",
                        value: minTokens.provider.shortName,
                        detail: "\(minTokens.usage?.totalTokens ?? 0)",
                        color: .blue
                    )
                }

                // 成功率
                let successCount = results.filter { $0.isSuccess }.count
                SummaryItem(
                    title: "成功率",
                    value: "\(successCount)/\(results.count)",
                    detail: String(format: "%.0f%%", Double(successCount) / Double(max(results.count, 1)) * 100),
                    color: successCount == results.count ? .green : .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SummaryItem: View {
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

private struct RunningProviderCard: View {
    let provider: AppSettings.Provider

    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.rawValue)
                    .font(.caption.bold())
                Text("実行中...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ResultCard: View {
    let result: ComparisonResultData
    let rank: Int
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー
            HStack {
                RankBadge(rank: rank, isSuccess: result.isSuccess)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.provider.rawValue)
                        .font(.caption.bold())
                    Text(result.model)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

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

            // JSON出力（展開可能）
            if let json = result.outputJSON {
                DisclosureGroup("出力結果", isExpanded: $isExpanded) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(json)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding(8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
    let isSuccess: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSuccess ? rankColor : Color.red.opacity(0.3))
                .frame(width: 28, height: 28)

            if isSuccess && rank == 1 {
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

// MARK: - Preview

#Preview {
    NavigationStack {
        MultiProviderDemo()
    }
}
