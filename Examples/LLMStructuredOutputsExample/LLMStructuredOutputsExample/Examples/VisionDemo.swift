//
//  VisionDemo.swift
//  LLMStructuredOutputsExample
//
//  画像入力（Vision）デモ
//

import SwiftUI
import PhotosUI
import LLMStructuredOutputs

/// 画像入力（Vision）デモ
///
/// マルチモーダル入力を使って画像を分析するデモです。
/// プロバイダーごとのメディア対応状況を確認できます。
struct VisionDemo: View {
    private var settings = AppSettings.shared

    // MARK: - State

    @State private var inputMode: InputMode = .url
    @State private var imageURLString = ImageAnalysisResult.sampleImageURLs[0]
    @State private var selectedSampleIndex = 0
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var state: LoadingState<ImageAnalysisResult> = .idle
    @State private var tokenUsage: TokenUsage?
    @State private var errorDetails: String?

    enum InputMode: String, CaseIterable {
        case url = "URL"
        case photo = "フォト"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - プロバイダー対応状況
                MediaSupportSection(provider: settings.selectedProvider)

                Divider()

                // MARK: - 入力方式選択
                VStack(alignment: .leading, spacing: 12) {
                    Text("入力方式")
                        .font(.subheadline.bold())

                    Picker("入力方式", selection: $inputMode) {
                        ForEach(InputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: - 入力コンテンツ
                switch inputMode {
                case .url:
                    URLInputSection(
                        urlString: $imageURLString,
                        selectedIndex: $selectedSampleIndex,
                        sampleURLs: ImageAnalysisResult.sampleImageURLs,
                        sampleDescriptions: ImageAnalysisResult.sampleDescriptions
                    )

                case .photo:
                    PhotoInputSection(
                        selectedItem: $selectedPhotoItem,
                        selectedData: $selectedImageData
                    )
                }

                // MARK: - プレビュー
                ImagePreviewSection(
                    inputMode: inputMode,
                    urlString: imageURLString,
                    imageData: selectedImageData
                )

                // MARK: - 実行
                if settings.isCurrentProviderAvailable {
                    if isImageInputSupported {
                        ExecuteButton(
                            isLoading: state.isLoading,
                            isEnabled: hasValidInput
                        ) {
                            analyzeImage()
                        }
                    } else {
                        UnsupportedFeatureView(
                            feature: "画像入力",
                            provider: settings.selectedProvider.shortName
                        )
                    }
                } else {
                    APIKeyRequiredView(provider: settings.selectedProvider)
                }

                // MARK: - エラー詳細
                if let errorDetails = errorDetails {
                    ErrorDetailsView(details: errorDetails)
                }

                // MARK: - 結果
                ResultDisplayView(state: state, usage: tokenUsage)

                // MARK: - コード例
                CodeExampleSection()
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("画像入力（Vision）")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedSampleIndex) { _, newValue in
            imageURLString = ImageAnalysisResult.sampleImageURLs[newValue]
        }
    }

    // MARK: - Computed Properties

    private var isImageInputSupported: Bool {
        // 現在のプロバイダーが画像入力をサポートしているか
        // Chat/Conversation API経由ではメディアはサポートされていないため、
        // 基本のProvider APIを使用する必要がある
        switch settings.selectedProvider {
        case .anthropic:
            return true  // Base Provider APIで画像対応
        case .openai:
            return true  // Base Provider APIで画像対応
        case .gemini:
            return true  // Base Provider APIで全メディア対応
        }
    }

    private var hasValidInput: Bool {
        switch inputMode {
        case .url:
            return !imageURLString.isEmpty && URL(string: imageURLString) != nil
        case .photo:
            return selectedImageData != nil
        }
    }

    // MARK: - Actions

    private func analyzeImage() {
        state = .loading
        tokenUsage = nil
        errorDetails = nil

        Task {
            do {
                // 画像コンテンツを作成
                let imageContent: ImageContent
                switch inputMode {
                case .url:
                    guard let url = URL(string: imageURLString) else {
                        throw LLMError.invalidRequest("Invalid URL")
                    }
                    imageContent = ImageContent.url(url, mediaType: .png)

                case .photo:
                    guard let data = selectedImageData else {
                        throw LLMError.invalidRequest("No image selected")
                    }
                    imageContent = ImageContent.base64(data, mediaType: .jpeg)
                }

                // メッセージを作成
                let message = LLMMessage.user(
                    "この画像を詳しく分析してください。",
                    image: imageContent
                )

                // プロバイダー別に実行
                switch settings.selectedProvider {
                case .anthropic:
                    try await analyzeWithAnthropic(message: message)
                case .openai:
                    try await analyzeWithOpenAI(message: message)
                case .gemini:
                    try await analyzeWithGemini(message: message)
                }
            } catch let error as LLMError {
                state = .error(error)
                errorDetails = formatLLMError(error)
            } catch {
                state = .error(error)
                errorDetails = error.localizedDescription
            }
        }
    }

    private func analyzeWithAnthropic(message: LLMMessage) async throws {
        guard let client = settings.createAnthropicClient() else { return }

        // generate() を使用（chat() はメディアコンテンツ非対応）
        let result: ImageAnalysisResult = try await client.generate(
            messages: [message],
            model: settings.claudeModelOption.model,
            systemPrompt: "画像を分析し、指定されたJSON形式で結果を返してください。",
            temperature: settings.temperature,
            maxTokens: settings.maxTokens
        )
        state = .success(result)
        // generate() はトークン使用量を返さない
        tokenUsage = nil
    }

    private func analyzeWithOpenAI(message: LLMMessage) async throws {
        guard let client = settings.createOpenAIClient() else { return }

        // generate() を使用（chat() はメディアコンテンツ非対応）
        let result: ImageAnalysisResult = try await client.generate(
            messages: [message],
            model: settings.gptModelOption.model,
            systemPrompt: "画像を分析し、指定されたJSON形式で結果を返してください。",
            temperature: settings.temperature,
            maxTokens: settings.maxTokens
        )
        state = .success(result)
        // generate() はトークン使用量を返さない
        tokenUsage = nil
    }

    private func analyzeWithGemini(message: LLMMessage) async throws {
        guard let client = settings.createGeminiClient() else { return }

        // generate() を使用（chat() はメディアコンテンツ非対応）
        let result: ImageAnalysisResult = try await client.generate(
            messages: [message],
            model: settings.geminiModelOption.model,
            systemPrompt: "画像を分析し、指定されたJSON形式で結果を返してください。",
            temperature: settings.temperature,
            maxTokens: settings.maxTokens
        )
        state = .success(result)
        // generate() はトークン使用量を返さない
        tokenUsage = nil
    }

    private func formatLLMError(_ error: LLMError) -> String {
        switch error {
        case .mediaNotSupported(let mediaType, let provider):
            return """
            \(mediaType.capitalized)入力は\(provider)でサポートされていません。

            対応状況:
            • Anthropic: 画像 ✓ / 音声 ✗ / 動画 ✗
            • OpenAI: 画像 ✓ / 音声 ✓ / 動画 ✗
            • Gemini: 画像 ✓ / 音声 ✓ / 動画 ✓
            """
        case .invalidRequest(let message):
            return "リクエストエラー: \(message)"
        case .unauthorized:
            return "認証エラー: APIキーを確認してください"
        case .rateLimitExceeded:
            return "レート制限: しばらく待ってから再試行してください"
        default:
            return "エラー: \(error.localizedDescription)"
        }
    }
}

// MARK: - Description Section

private struct DescriptionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("このデモについて", systemImage: "info.circle.fill")
                .font(.headline)

            Text("""
            マルチモーダル入力を使って画像を分析します。

            画像をLLMに送信し、構造化された分析結果を取得します：
            • 画像の説明と主要オブジェクト
            • 色彩・雰囲気・シーンタイプ
            • テキスト検出（OCR）
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Media Support Section

private struct MediaSupportSection: View {
    let provider: AppSettings.Provider

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("プロバイダー別対応状況", systemImage: "checkmark.seal.fill")
                .font(.subheadline.bold())

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("").frame(width: 80)
                    Text("画像").font(.caption.bold())
                    Text("音声").font(.caption.bold())
                    Text("動画").font(.caption.bold())
                }

                GridRow {
                    HStack {
                        if provider == .anthropic {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption2)
                        }
                        Text("Claude").font(.caption)
                    }
                    .frame(width: 80, alignment: .leading)
                    SupportIcon(supported: true)
                    SupportIcon(supported: false)
                    SupportIcon(supported: false)
                }

                GridRow {
                    HStack {
                        if provider == .openai {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption2)
                        }
                        Text("GPT").font(.caption)
                    }
                    .frame(width: 80, alignment: .leading)
                    SupportIcon(supported: true)
                    SupportIcon(supported: true, note: "audio-preview")
                    SupportIcon(supported: false)
                }

                GridRow {
                    HStack {
                        if provider == .gemini {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption2)
                        }
                        Text("Gemini").font(.caption)
                    }
                    .frame(width: 80, alignment: .leading)
                    SupportIcon(supported: true)
                    SupportIcon(supported: true)
                    SupportIcon(supported: true)
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct SupportIcon: View {
    let supported: Bool
    var note: String? = nil

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(supported ? .green : .red.opacity(0.6))
                .font(.caption)
            if let note = note {
                Text(note)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - URL Input Section

private struct URLInputSection: View {
    @Binding var urlString: String
    @Binding var selectedIndex: Int
    let sampleURLs: [String]
    let sampleDescriptions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SampleInputPicker(
                samples: sampleURLs,
                descriptions: sampleDescriptions,
                selectedIndex: $selectedIndex
            )

            InputTextEditor(
                title: "画像URL",
                text: $urlString,
                minHeight: 60
            )
        }
    }
}

// MARK: - Photo Input Section

private struct PhotoInputSection: View {
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var selectedData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("写真を選択")
                .font(.subheadline.bold())

            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("フォトライブラリから選択", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        selectedData = data
                    }
                }
            }
        }
    }
}

// MARK: - Image Preview Section

private struct ImagePreviewSection: View {
    let inputMode: VisionDemo.InputMode
    let urlString: String
    let imageData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プレビュー")
                .font(.subheadline.bold())

            Group {
                switch inputMode {
                case .url:
                    if let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 150)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                            case .failure:
                                ContentUnavailableView(
                                    "画像を読み込めません",
                                    systemImage: "photo.badge.exclamationmark",
                                    description: Text("URLを確認してください")
                                )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "URLが無効です",
                            systemImage: "link.badge.plus",
                            description: Text("有効なURLを入力してください")
                        )
                    }

                case .photo:
                    if let data = imageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 200)
                    } else {
                        ContentUnavailableView(
                            "画像を選択してください",
                            systemImage: "photo.badge.plus",
                            description: Text("フォトライブラリから選択")
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Unsupported Feature View

private struct UnsupportedFeatureView: View {
    let feature: String
    let provider: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("\(feature)は\(provider)でサポートされていません")
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Error Details View

private struct ErrorDetailsView: View {
    let details: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("エラー詳細", systemImage: "exclamationmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.red)

            Text(details)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Code Example Section

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
        import LLMStructuredOutputs

        // 構造化出力の型を定義
        @Structured("画像の分析結果")
        struct ImageAnalysisResult {
            @StructuredField("画像の説明")
            var summary: String

            @StructuredField("検出されたオブジェクト")
            var objects: [String]
        }

        // 画像コンテンツを作成
        let image = ImageContent.url(
            URL(string: "https://example.com/image.jpg")!,
            mediaType: .jpeg
        )

        // メッセージを作成
        let message = LLMMessage.user(
            "この画像を分析してください",
            image: image
        )

        // クライアントで実行
        let client = GeminiClient(apiKey: "...")
        let response = try await client.generate(
            messages: [message],
            model: .flash,
            type: ImageAnalysisResult.self
        )

        print(response.result.summary)
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VisionDemo()
    }
}
