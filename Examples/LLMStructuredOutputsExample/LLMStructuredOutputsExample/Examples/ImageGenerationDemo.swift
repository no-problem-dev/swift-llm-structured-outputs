//
//  ImageGenerationDemo.swift
//  LLMStructuredOutputsExample
//
//  画像生成（DALL-E / Imagen）デモ
//

import SwiftUI
import Photos
import LLMStructuredOutputs
import DesignSystem

/// 画像生成デモ
///
/// OpenAI DALL-E を使った画像生成を体験できます。
/// プロンプトから画像を生成し、結果を表示します。
struct ImageGenerationDemo: View {
    private var settings = AppSettings.shared

    // MARK: - State

    @State private var selectedSampleIndex = 0
    @State private var promptText = samplePrompts[0]
    @State private var selectedSize: ImageSize = .square1024
    @State private var selectedQuality: ImageQuality = .standard
    @State private var selectedFormat: ImageOutputFormat = .png
    @State private var selectedOpenAIModel: OpenAIImageModel = .dalle3
    @State private var selectedGeminiModel: GeminiImageModel = .gemini20FlashImage
    @State private var state: ImageGenerationState = .idle
    @State private var generatedImage: GeneratedImage?
    @State private var errorDetails: String?

    enum ImageGenerationState {
        case idle
        case loading
        case success
        case error(Error)

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }

    // MARK: - Sample Data

    private static let samplePrompts = [
        "A serene Japanese garden with a koi pond, cherry blossoms, and a traditional wooden bridge, soft morning light",
        "A futuristic cityscape at sunset with flying cars and holographic billboards, cyberpunk style",
        "A cozy coffee shop interior with vintage furniture, warm lighting, and rain on the windows",
        "An astronaut riding a horse on Mars, photorealistic style"
    ]

    private static let sampleDescriptions = [
        "日本庭園",
        "サイバーパンク都市",
        "カフェ内装",
        "火星の宇宙飛行士"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - プロバイダー対応状況
                ProviderSupportSection(provider: settings.selectedProvider)

                Divider()

                // MARK: - プロンプト入力
                VStack(alignment: .leading, spacing: 12) {
                    SampleInputPicker(
                        samples: Self.samplePrompts,
                        descriptions: Self.sampleDescriptions,
                        selectedIndex: $selectedSampleIndex
                    )
                    .onChange(of: selectedSampleIndex) { _, newValue in
                        promptText = Self.samplePrompts[newValue]
                    }

                    InputTextEditor(
                        title: "画像プロンプト",
                        text: $promptText,
                        minHeight: 100
                    )
                }

                // MARK: - オプション設定
                if isImageGenerationSupported {
                    OptionsSection(
                        provider: settings.selectedProvider,
                        selectedOpenAIModel: $selectedOpenAIModel,
                        selectedGeminiModel: $selectedGeminiModel,
                        selectedSize: $selectedSize,
                        selectedQuality: $selectedQuality,
                        selectedFormat: $selectedFormat,
                        supportedSizes: supportedSizes,
                        supportsQuality: supportsQuality,
                        supportsFormatSelection: supportsFormatSelection
                    )
                }

                // MARK: - 実行
                if settings.isCurrentProviderAvailable {
                    if isImageGenerationSupported {
                        ExecuteButton(
                            isLoading: state.isLoading,
                            isEnabled: !promptText.isEmpty
                        ) {
                            generateImage()
                        }
                    } else {
                        UnsupportedProviderView(
                            feature: "画像生成",
                            provider: settings.selectedProvider.shortName
                        )
                    }
                } else {
                    APIKeyRequiredView(provider: settings.selectedProvider)
                }

                // MARK: - エラー詳細
                if let errorDetails = errorDetails {
                    ErrorDetailsSection(details: errorDetails)
                }

                // MARK: - 結果
                ResultSection(
                    state: state,
                    generatedImage: generatedImage
                )

                // MARK: - コード例
                CodeExampleSection()
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("画像生成")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed Properties

    private var isImageGenerationSupported: Bool {
        switch settings.selectedProvider {
        case .openai:
            return true  // DALL-E / GPT-Image サポート
        case .gemini:
            return true  // Imagen 4 / Gemini Image サポート（generativelanguage.googleapis.com 経由）
        case .anthropic:
            return false  // Claude は画像生成非対応
        }
    }

    /// 現在のプロバイダーに応じたサポートサイズ
    private var supportedSizes: [ImageSize] {
        switch settings.selectedProvider {
        case .openai:
            return selectedOpenAIModel.supportedSizes
        case .gemini:
            return selectedGeminiModel.supportedSizes
        case .anthropic:
            return []
        }
    }

    /// 現在のプロバイダーが品質設定をサポートするか
    private var supportsQuality: Bool {
        settings.selectedProvider == .openai
    }

    /// 現在のプロバイダーがフォーマット選択をサポートするか
    private var supportsFormatSelection: Bool {
        settings.selectedProvider == .openai  // Gemini は PNG のみ
    }

    // MARK: - Actions

    private func generateImage() {
        state = .loading
        generatedImage = nil
        errorDetails = nil

        Task {
            do {
                switch settings.selectedProvider {
                case .openai:
                    try await generateWithOpenAI()
                case .gemini:
                    try await generateWithGemini()
                case .anthropic:
                    throw ImageGenerationError.notSupportedByProvider(settings.selectedProvider.shortName)
                }
            } catch let error as ImageGenerationError {
                state = .error(error)
                errorDetails = formatImageGenerationError(error)
            } catch let error as LLMError {
                state = .error(error)
                errorDetails = formatLLMError(error)
            } catch {
                state = .error(error)
                errorDetails = error.localizedDescription
            }
        }
    }

    private func generateWithOpenAI() async throws {
        guard let client = settings.createOpenAIClient() else { return }

        let image = try await client.generateImage(
            input: LLMInput(promptText),
            model: selectedOpenAIModel,
            size: selectedSize,
            quality: selectedQuality,
            format: selectedFormat,
            n: 1
        )

        generatedImage = image
        state = .success
    }

    private func generateWithGemini() async throws {
        guard let client = settings.createGeminiClient() else { return }

        let image = try await client.generateImage(
            input: LLMInput(promptText),
            model: selectedGeminiModel,
            size: selectedSize,
            quality: nil,  // Gemini は品質設定なし
            format: .png,  // Gemini は PNG のみ対応
            n: 1
        )

        generatedImage = image
        state = .success
    }

    private func formatImageGenerationError(_ error: ImageGenerationError) -> String {
        error.errorDescription ?? "画像生成エラーが発生しました"
    }

    private func formatLLMError(_ error: LLMError) -> String {
        switch error {
        case .unauthorized:
            return "認証エラー: APIキーを確認してください"
        case .rateLimitExceeded:
            return "レート制限: しばらく待ってから再試行してください"
        case .invalidRequest(let message):
            return "リクエストエラー: \(message)"
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
            プロンプトから画像を生成します。

            対応プロバイダー:
            • OpenAI: DALL-E 2/3、GPT-Image（品質・フォーマット選択可）
            • Gemini: Gemini 2.0 Flash Image、Imagen 4 シリーズ（PNG固定）
            • Claude: 非対応
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Provider Support Section

private struct ProviderSupportSection: View {
    let provider: AppSettings.Provider

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("プロバイダー別対応状況", systemImage: "checkmark.seal.fill")
                .font(.subheadline.bold())

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("").frame(width: 80)
                    Text("モデル").font(.caption.bold())
                    Text("品質").font(.caption.bold())
                    Text("フォーマット").font(.caption.bold())
                }

                GridRow {
                    HStack {
                        if provider == .openai {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption2)
                        }
                        Text("OpenAI").font(.caption)
                    }
                    .frame(width: 80, alignment: .leading)
                    Text("DALL-E 2/3").font(.system(size: 9))
                    SupportIcon(supported: true)
                    Text("PNG/JPEG/WebP").font(.system(size: 8))
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
                    Text("Imagen 4等").font(.system(size: 9))
                    Text("-").font(.system(size: 8))
                    Text("PNG").font(.system(size: 8))
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
                    Text("-").font(.system(size: 9))
                    SupportIcon(supported: false)
                    Text("-").font(.system(size: 8))
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

// MARK: - Options Section

private struct OptionsSection: View {
    let provider: AppSettings.Provider
    @Binding var selectedOpenAIModel: OpenAIImageModel
    @Binding var selectedGeminiModel: GeminiImageModel
    @Binding var selectedSize: ImageSize
    @Binding var selectedQuality: ImageQuality
    @Binding var selectedFormat: ImageOutputFormat
    let supportedSizes: [ImageSize]
    let supportsQuality: Bool
    let supportsFormatSelection: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生成オプション")
                .font(.subheadline.bold())

            // モデル選択
            VStack(alignment: .leading, spacing: 4) {
                Text("モデル")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                switch provider {
                case .openai:
                    Picker("モデル", selection: $selectedOpenAIModel) {
                        Text("DALL-E 3").tag(OpenAIImageModel.dalle3)
                        Text("DALL-E 2").tag(OpenAIImageModel.dalle2)
                        Text("GPT-Image").tag(OpenAIImageModel.gptImage)
                    }
                    .pickerStyle(.segmented)
                case .gemini:
                    Picker("モデル", selection: $selectedGeminiModel) {
                        Text("Gemini Flash").tag(GeminiImageModel.gemini20FlashImage)
                        Text("Imagen 4").tag(GeminiImageModel.imagen4)
                        Text("Imagen 4 Fast").tag(GeminiImageModel.imagen4Fast)
                        Text("Imagen 4 Ultra").tag(GeminiImageModel.imagen4Ultra)
                    }
                    .pickerStyle(.menu)
                case .anthropic:
                    EmptyView()
                }
            }

            // サイズ
            VStack(alignment: .leading, spacing: 4) {
                Text("サイズ")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("サイズ", selection: $selectedSize) {
                    ForEach(supportedSizes, id: \.self) { size in
                        Text(sizeDisplayName(size)).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 品質（OpenAI のみ）
            if supportsQuality {
                VStack(alignment: .leading, spacing: 4) {
                    Text("品質")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("品質", selection: $selectedQuality) {
                        Text("標準").tag(ImageQuality.standard)
                        Text("HD").tag(ImageQuality.hd)
                    }
                    .pickerStyle(.segmented)
                }
            }

            // フォーマット（OpenAI のみ）
            if supportsFormatSelection {
                VStack(alignment: .leading, spacing: 4) {
                    Text("フォーマット")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("フォーマット", selection: $selectedFormat) {
                        Text("PNG").tag(ImageOutputFormat.png)
                        Text("JPEG").tag(ImageOutputFormat.jpeg)
                        Text("WebP").tag(ImageOutputFormat.webp)
                    }
                    .pickerStyle(.segmented)
                }
            } else {
                // Gemini は PNG のみ
                HStack {
                    Text("フォーマット")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("PNG（固定）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sizeDisplayName(_ size: ImageSize) -> String {
        switch size {
        case .square256: return "256×256"
        case .square512: return "512×512"
        case .square1024: return "1024×1024"
        case .landscape1792x1024: return "1792×1024"
        case .landscape1536x1024: return "1536×1024"
        case .portrait1024x1792: return "1024×1792"
        case .portrait1024x1536: return "1024×1536"
        }
    }
}

// MARK: - Unsupported Provider View

private struct UnsupportedProviderView: View {
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

// MARK: - Error Details Section

private struct ErrorDetailsSection: View {
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

// MARK: - Result Section

private struct ResultSection: View {
    let state: ImageGenerationDemo.ImageGenerationState
    let generatedImage: GeneratedImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("生成結果", systemImage: "photo.fill")
                    .font(.headline)

                Spacer()

                if state.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            Group {
                switch state {
                case .idle:
                    ContentUnavailableView(
                        "実行前",
                        systemImage: "photo.badge.plus",
                        description: Text("「実行」ボタンを押して画像を生成")
                    )

                case .loading:
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("画像を生成中...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)

                case .success:
                    if let image = generatedImage {
                        GeneratedImageView(image: image)
                    }

                case .error:
                    ContentUnavailableView(
                        "生成に失敗しました",
                        systemImage: "exclamationmark.triangle",
                        description: Text("エラー詳細を確認してください")
                    )
                }
            }
        }
        .animation(.default, value: state.isLoading)
    }
}

// MARK: - Generated Image View

private struct GeneratedImageView: View {
    let image: GeneratedImage
    @State private var uiImage: UIImage?
    @State private var showingShareSheet = false
    @State private var snackbarState = SnackbarState()
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 画像表示
            Group {
                if let uiImage = uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ProgressView("画像を読み込み中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 改訂プロンプト
            if let revisedPrompt = image.revisedPrompt {
                VStack(alignment: .leading, spacing: 4) {
                    Text("改訂されたプロンプト")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(revisedPrompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // アクションボタン
            if uiImage != nil {
                HStack {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    if isSaving {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text("保存中...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                    } else {
                        Button {
                            saveToPhotos()
                        } label: {
                            Label("保存", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .onAppear {
            loadImage()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let uiImage = uiImage {
                ShareSheet(items: [uiImage])
            }
        }
        .overlay(alignment: .bottom) {
            Snackbar(state: snackbarState)
        }
    }

    private func loadImage() {
        Task {
            uiImage = image.uiImage
        }
    }

    private func saveToPhotos() {
        guard let uiImage = uiImage else {
            snackbarState.show(message: "保存する画像がありません")
            return
        }

        isSaving = true

        Task { @MainActor in
            defer { isSaving = false }

            do {
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

                guard status == .authorized || status == .limited else {
                    snackbarState.show(
                        message: "写真ライブラリへのアクセスが許可されていません",
                        primaryAction: SnackbarAction(title: "設定を開く") {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                await UIApplication.shared.open(settingsURL)
                            }
                        },
                        duration: 5.0
                    )
                    return
                }

                let imageToSave = uiImage
                try await PHPhotoLibrary.shared().performChanges { @Sendable in
                    PHAssetChangeRequest.creationRequestForAsset(from: imageToSave)
                }

                snackbarState.show(message: "カメラロールに保存しました ✓", duration: 3.0)
            } catch {
                snackbarState.show(
                    message: "保存に失敗しました: \(error.localizedDescription)",
                    duration: 5.0
                )
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Code Example Section

private struct CodeExampleSection: View {
    @State private var isExpanded = false
    @State private var selectedTab = 0

    var body: some View {
        DisclosureGroup("コード例", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("プロバイダー", selection: $selectedTab) {
                    Text("OpenAI").tag(0)
                    Text("Gemini").tag(1)
                }
                .pickerStyle(.segmented)

                ScrollView(.horizontal, showsIndicators: false) {
                    Text(selectedTab == 0 ? openAIExample : geminiExample)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private var openAIExample: String {
        """
        import LLMStructuredOutputs

        // OpenAI クライアントを作成
        let client = OpenAIClient(apiKey: "sk-...")

        // 画像を生成（DALL-E 3）
        let image = try await client.generateImage(
            input: "A serene Japanese garden with cherry blossoms",
            model: .dalle3,
            size: .square1024,
            quality: .hd,
            format: .png,
            n: 1
        )

        // 生成された画像を使用
        if let uiImage = image.uiImage {
            imageView.image = uiImage
        }

        // 改訂されたプロンプトを確認
        if let revised = image.revisedPrompt {
            print("Revised: \\(revised)")
        }
        """
    }

    private var geminiExample: String {
        """
        import LLMStructuredOutputs

        // Gemini クライアントを作成
        let client = GeminiClient(apiKey: "AIza...")

        // 画像を生成（Gemini 2.0 Flash Image）
        let image = try await client.generateImage(
            input: "A serene Japanese garden with cherry blossoms",
            model: .gemini20FlashImage,  // または .imagen4, .imagen4Fast, .imagen4Ultra
            size: .square1024
        )

        // 生成された画像を使用
        if let uiImage = image.uiImage {
            imageView.image = uiImage
        }

        // ファイルに保存
        try image.save(to: fileURL)
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ImageGenerationDemo()
    }
}
