//
//  VideoGenerationDemo.swift
//  LLMStructuredOutputsExample
//
//  動画生成（Sora / Veo）デモ
//

import SwiftUI
import AVKit
import Photos
import LLMStructuredOutputs

/// 動画生成デモ
///
/// OpenAI Sora 2 や Gemini Veo を使った動画生成を体験できます。
/// プロンプトから動画を生成し、結果を表示します。
struct VideoGenerationDemo: View {
    private var settings = AppSettings.shared

    // MARK: - State

    @State private var selectedSampleIndex = 0
    @State private var promptText = samplePrompts[0]
    @State private var selectedDuration: Int = 4
    @State private var selectedAspectRatio: VideoAspectRatio = .landscape16x9
    @State private var selectedResolution: VideoResolution = .hd720p
    @State private var selectedOpenAIModel: OpenAIVideoModel = .sora2
    @State private var selectedGeminiModel: GeminiVideoModel = .veo30
    @State private var state: VideoGenerationState = .idle
    @State private var currentJob: VideoGenerationJob?
    @State private var generatedVideo: GeneratedVideo?
    @State private var errorDetails: String?
    @State private var pollingTask: Task<Void, Never>?

    enum VideoGenerationState: Equatable {
        case idle
        case starting
        case processing(progress: Double?)
        case downloading
        case success
        case error(String)

        var isLoading: Bool {
            switch self {
            case .starting, .processing, .downloading:
                return true
            default:
                return false
            }
        }

        var statusText: String {
            switch self {
            case .idle: return "待機中"
            case .starting: return "ジョブ開始中..."
            case .processing(let progress):
                if let p = progress {
                    return String(format: "生成中 (%.0f%%)", p * 100)
                }
                return "生成中..."
            case .downloading: return "ダウンロード中..."
            case .success: return "完了"
            case .error: return "エラー"
            }
        }
    }

    // MARK: - Sample Data

    private static let samplePrompts = [
        "A serene Japanese koi pond with cherry blossom petals falling gently on the water surface, soft morning light",
        "A futuristic cityscape at sunset with flying cars moving through holographic billboards, cyberpunk style",
        "A cat playing with a ball of yarn on a cozy carpet, warm indoor lighting",
        "Ocean waves gently crashing on a tropical beach at golden hour, palm trees swaying"
    ]

    private static let sampleDescriptions = [
        "日本庭園",
        "サイバーパンク",
        "猫と毛糸",
        "トロピカルビーチ"
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
                        title: "動画プロンプト",
                        text: $promptText,
                        minHeight: 100
                    )
                }

                // MARK: - オプション設定
                if isVideoGenerationSupported {
                    OptionsSection(
                        provider: settings.selectedProvider,
                        selectedOpenAIModel: $selectedOpenAIModel,
                        selectedGeminiModel: $selectedGeminiModel,
                        selectedDuration: $selectedDuration,
                        selectedAspectRatio: $selectedAspectRatio,
                        selectedResolution: $selectedResolution,
                        supportedDurations: supportedDurations,
                        supportedAspectRatios: supportedAspectRatios,
                        supportedResolutions: supportedResolutions
                    )
                }

                // MARK: - 実行
                if settings.isCurrentProviderAvailable {
                    if isVideoGenerationSupported {
                        VStack(spacing: 12) {
                            ExecuteButton(
                                isLoading: state.isLoading,
                                isEnabled: !promptText.isEmpty && !state.isLoading
                            ) {
                                generateVideo()
                            }

                            if state.isLoading {
                                VStack(spacing: 8) {
                                    ProgressView()
                                    Text(state.statusText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if case .processing = state {
                                        Button("キャンセル") {
                                            cancelGeneration()
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                    }
                                }
                            }
                        }
                    } else {
                        UnsupportedProviderView(
                            feature: "動画生成",
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
                    generatedVideo: generatedVideo
                )

                // MARK: - コード例
                CodeExampleSection()
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("動画生成")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            cancelGeneration()
        }
    }

    // MARK: - Computed Properties

    private var isVideoGenerationSupported: Bool {
        switch settings.selectedProvider {
        case .openai:
            return true  // Sora 2 サポート
        case .gemini:
            return true  // Veo サポート
        case .anthropic:
            return false  // Claude は動画生成非対応
        }
    }

    private var supportedDurations: [Int] {
        switch settings.selectedProvider {
        case .openai:
            return selectedOpenAIModel.supportedDurations
        case .gemini:
            return selectedGeminiModel.supportedDurations
        case .anthropic:
            return []
        }
    }

    private var supportedAspectRatios: [VideoAspectRatio] {
        switch settings.selectedProvider {
        case .openai:
            return selectedOpenAIModel.supportedAspectRatios
        case .gemini:
            return selectedGeminiModel.supportedAspectRatios
        case .anthropic:
            return []
        }
    }

    private var supportedResolutions: [VideoResolution] {
        switch settings.selectedProvider {
        case .openai:
            return selectedOpenAIModel.supportedResolutions
        case .gemini:
            return selectedGeminiModel.supportedResolutions
        case .anthropic:
            return []
        }
    }

    // MARK: - Actions

    private func generateVideo() {
        state = .starting
        generatedVideo = nil
        errorDetails = nil

        pollingTask = Task {
            do {
                switch settings.selectedProvider {
                case .openai:
                    try await generateWithOpenAI()
                case .gemini:
                    try await generateWithGemini()
                case .anthropic:
                    throw VideoGenerationError.notSupportedByProvider(settings.selectedProvider.shortName)
                }
            } catch let error as VideoGenerationError {
                state = .error(error.localizedDescription)
                errorDetails = error.errorDescription
            } catch let error as LLMError {
                state = .error(error.localizedDescription)
                errorDetails = formatLLMError(error)
            } catch {
                state = .error(error.localizedDescription)
                errorDetails = error.localizedDescription
            }
        }
    }

    private func generateWithOpenAI() async throws {
        guard let client = settings.createOpenAIClient() else { return }

        // ジョブを開始
        var job = try await client.startVideoGeneration(
            input: LLMInput(promptText),
            model: selectedOpenAIModel,
            duration: selectedDuration,
            aspectRatio: selectedAspectRatio,
            resolution: selectedResolution
        )

        currentJob = job
        state = .processing(progress: nil)

        // ポーリング
        while !job.status.isTerminal {
            try await Task.sleep(nanoseconds: 10_000_000_000)  // 10秒
            job = try await client.checkVideoStatus(job)
            currentJob = job
            state = .processing(progress: job.progress)
        }

        if job.status == .completed {
            state = .downloading
            let video = try await client.getGeneratedVideo(job)
            generatedVideo = video
            state = .success
        } else if job.status == .failed {
            throw VideoGenerationError.generationFailed(job.errorMessage ?? "Unknown error")
        } else if job.status == .cancelled {
            throw VideoGenerationError.cancelled
        }
    }

    private func generateWithGemini() async throws {
        guard let client = settings.createGeminiClient() else { return }

        // ジョブを開始
        var job = try await client.startVideoGeneration(
            input: LLMInput(promptText),
            model: selectedGeminiModel,
            duration: selectedDuration,
            aspectRatio: selectedAspectRatio,
            resolution: selectedResolution
        )

        currentJob = job
        state = .processing(progress: nil)

        // ポーリング
        while !job.status.isTerminal {
            try await Task.sleep(nanoseconds: 10_000_000_000)  // 10秒
            job = try await client.checkVideoStatus(job)
            currentJob = job
            state = .processing(progress: job.progress)
        }

        if job.status == .completed {
            state = .downloading
            let video = try await client.getGeneratedVideo(job)
            generatedVideo = video
            state = .success
        } else if job.status == .failed {
            throw VideoGenerationError.generationFailed(job.errorMessage ?? "Unknown error")
        } else if job.status == .cancelled {
            throw VideoGenerationError.cancelled
        }
    }

    private func cancelGeneration() {
        pollingTask?.cancel()
        pollingTask = nil
        if state.isLoading {
            state = .idle
        }
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
            プロンプトから動画を生成します。

            対応プロバイダー:
            • OpenAI: Sora 2 / Sora 2 Pro（4〜12秒、720p/1080p）
            • Gemini: Veo 3.1 / 3.0 / 2.0（4〜8秒、720p/1080p）
            • Claude: 非対応

            ⚠️ 動画生成には1〜3分程度かかります。
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
                    Text("解像度").font(.caption.bold())
                    Text("動画長").font(.caption.bold())
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
                    Text("Sora 2").font(.system(size: 9))
                    Text("720p/1080p").font(.system(size: 8))
                    Text("4-12秒").font(.system(size: 8))
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
                    Text("Veo 3.x").font(.system(size: 9))
                    Text("720p/1080p").font(.system(size: 8))
                    Text("4-8秒").font(.system(size: 8))
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
                    Text("-").font(.system(size: 8))
                    Text("-").font(.system(size: 8))
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Options Section

private struct OptionsSection: View {
    let provider: AppSettings.Provider
    @Binding var selectedOpenAIModel: OpenAIVideoModel
    @Binding var selectedGeminiModel: GeminiVideoModel
    @Binding var selectedDuration: Int
    @Binding var selectedAspectRatio: VideoAspectRatio
    @Binding var selectedResolution: VideoResolution
    let supportedDurations: [Int]
    let supportedAspectRatios: [VideoAspectRatio]
    let supportedResolutions: [VideoResolution]

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
                        Text("Sora 2").tag(OpenAIVideoModel.sora2)
                        Text("Sora 2 Pro").tag(OpenAIVideoModel.sora2Pro)
                    }
                    .pickerStyle(.segmented)
                case .gemini:
                    Picker("モデル", selection: $selectedGeminiModel) {
                        Text("Veo 3.1").tag(GeminiVideoModel.veo31)
                        Text("Veo 3.1 Fast").tag(GeminiVideoModel.veo31Fast)
                        Text("Veo 3.0").tag(GeminiVideoModel.veo30)
                        Text("Veo 2.0").tag(GeminiVideoModel.veo20)
                    }
                    .pickerStyle(.menu)
                case .anthropic:
                    EmptyView()
                }
            }

            // 動画長
            VStack(alignment: .leading, spacing: 4) {
                Text("動画長")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("動画長", selection: $selectedDuration) {
                    ForEach(supportedDurations, id: \.self) { duration in
                        Text("\(duration)秒").tag(duration)
                    }
                }
                .pickerStyle(.segmented)
            }

            // アスペクト比
            VStack(alignment: .leading, spacing: 4) {
                Text("アスペクト比")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("アスペクト比", selection: $selectedAspectRatio) {
                    ForEach(supportedAspectRatios, id: \.self) { ratio in
                        Text(aspectRatioDisplayName(ratio)).tag(ratio)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 解像度
            VStack(alignment: .leading, spacing: 4) {
                Text("解像度")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("解像度", selection: $selectedResolution) {
                    ForEach(supportedResolutions, id: \.self) { res in
                        Text(res.rawValue).tag(res)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func aspectRatioDisplayName(_ ratio: VideoAspectRatio) -> String {
        switch ratio {
        case .landscape16x9: return "横長 16:9"
        case .portrait9x16: return "縦長 9:16"
        case .square1x1: return "正方形"
        default: return ratio.rawValue
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
    let state: VideoGenerationDemo.VideoGenerationState
    let generatedVideo: GeneratedVideo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("生成結果", systemImage: "video.fill")
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
                        systemImage: "video.badge.plus",
                        description: Text("「実行」ボタンを押して動画を生成")
                    )

                case .starting, .processing, .downloading:
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(state.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)

                case .success:
                    if let video = generatedVideo {
                        GeneratedVideoView(video: video)
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

// MARK: - Generated Video View

private struct GeneratedVideoView: View {
    let video: GeneratedVideo
    @State private var player: AVPlayer?
    @State private var showingShareSheet = false
    @State private var tempFileURL: URL?
    @State private var saveMessage: String?
    @State private var showingSaveAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 動画プレイヤー
            Group {
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 300)
                } else {
                    ProgressView("動画を読み込み中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // メタデータ
            VStack(alignment: .leading, spacing: 4) {
                Text("動画情報")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    if let duration = video.duration {
                        Label("\(Int(duration))秒", systemImage: "clock")
                    }
                    if let resolution = video.resolution {
                        Label(resolution.rawValue, systemImage: "rectangle")
                    }
                    Label("\(video.data.count / 1024)KB", systemImage: "doc")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // アクションボタン
            if player != nil {
                HStack {
                    Button {
                        player?.seek(to: .zero)
                        player?.play()
                    } label: {
                        Label("再生", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        saveToPhotos()
                    } label: {
                        Label("保存", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            setupAudioSession()
            loadVideo()
        }
        .onDisappear {
            cleanupTempFile()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = tempFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert("保存", isPresented: $showingSaveAlert) {
            Button("OK") {}
        } message: {
            Text(saveMessage ?? "")
        }
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func loadVideo() {
        Task {
            // 一時ファイルに保存
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")

            do {
                try video.data.write(to: fileURL)
                tempFileURL = fileURL
                player = AVPlayer(url: fileURL)
            } catch {
                print("Error loading video: \(error)")
            }
        }
    }

    private func cleanupTempFile() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func saveToPhotos() {
        guard let url = tempFileURL else { return }

        Task {
            do {
                // 権限を確認
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

                guard status == .authorized || status == .limited else {
                    saveMessage = "写真ライブラリへのアクセスが許可されていません。設定アプリから許可してください。"
                    showingSaveAlert = true
                    return
                }

                // 動画を保存
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }

                saveMessage = "動画をカメラロールに保存しました"
                showingSaveAlert = true
            } catch {
                saveMessage = "保存に失敗しました: \(error.localizedDescription)"
                showingSaveAlert = true
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

        // 動画生成ジョブを開始
        var job = try await client.startVideoGeneration(
            input: "A cat playing with a ball",
            model: .sora2,
            duration: 4,
            aspectRatio: .landscape16x9,
            resolution: .hd720p
        )

        // 完了までポーリング
        while !job.status.isTerminal {
            try await Task.sleep(nanoseconds: 10_000_000_000)
            job = try await client.checkVideoStatus(job)
            print("Progress: \\(job.progress ?? 0)")
        }

        // 動画をダウンロード
        if job.status == .completed {
            let video = try await client.getGeneratedVideo(job)
            try video.save(to: fileURL)
        }
        """
    }

    private var geminiExample: String {
        """
        import LLMStructuredOutputs

        // Gemini クライアントを作成
        let client = GeminiClient(apiKey: "AIza...")

        // 動画生成ジョブを開始（Veo）
        var job = try await client.startVideoGeneration(
            input: "A serene Japanese garden",
            model: .veo30,
            duration: 4,
            aspectRatio: .landscape16x9,
            resolution: .hd720p
        )

        // 完了までポーリング
        while !job.status.isTerminal {
            try await Task.sleep(nanoseconds: 10_000_000_000)
            job = try await client.checkVideoStatus(job)
            print("Progress: \\(job.progress ?? 0)")
        }

        // 動画をダウンロード
        if job.status == .completed {
            let video = try await client.getGeneratedVideo(job)
            try video.save(to: fileURL)
        }
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VideoGenerationDemo()
    }
}
