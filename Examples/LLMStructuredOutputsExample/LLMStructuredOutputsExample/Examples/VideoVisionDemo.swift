//
//  VideoVisionDemo.swift
//  LLMStructuredOutputsExample
//
//  動画入力（Vision）デモ
//

import SwiftUI
import LLMStructuredOutputs
import DesignSystem

/// 動画入力（Vision）デモ
///
/// マルチモーダル入力を使って動画を分析するデモです。
/// 動画入力はGeminiのみでサポートされています。
struct VideoVisionDemo: View {
    private var settings = AppSettings.shared

    // MARK: - State

    @State private var inputMode: InputMode = .url
    @State private var videoURLString = VideoAnalysisResult.sampleVideoURLs[0]
    @State private var selectedSampleIndex = 0
    @State private var showVideoPicker = false
    @State private var selectedVideoData: Data?
    @State private var state: LoadingState<VideoAnalysisResult> = .idle
    @State private var tokenUsage: TokenUsage?
    @State private var errorDetails: String?

    enum InputMode: String, CaseIterable {
        case url = "URL"
        case video = "ビデオ"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - 説明
                DescriptionSection()

                Divider()

                // MARK: - プロバイダー対応状況
                ProviderSupportSection(provider: settings.selectedProvider)

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
                        urlString: $videoURLString,
                        selectedIndex: $selectedSampleIndex,
                        sampleURLs: VideoAnalysisResult.sampleVideoURLs,
                        sampleDescriptions: VideoAnalysisResult.sampleDescriptions
                    )

                case .video:
                    VideoInputSection(
                        showVideoPicker: $showVideoPicker,
                        selectedVideoData: $selectedVideoData
                    )
                }

                // MARK: - プレビュー
                VideoPreviewSection(
                    inputMode: inputMode,
                    urlString: videoURLString,
                    videoData: selectedVideoData
                )

                // MARK: - 実行
                if settings.isCurrentProviderAvailable {
                    if isVideoInputSupported {
                        ExecuteButton(
                            isLoading: state.isLoading,
                            isEnabled: hasValidInput
                        ) {
                            analyzeVideo()
                        }
                    } else {
                        UnsupportedFeatureView(
                            feature: "動画入力",
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
        .navigationTitle("動画入力（Vision）")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedSampleIndex) { _, newValue in
            videoURLString = VideoAnalysisResult.sampleVideoURLs[newValue]
        }
    }

    // MARK: - Computed Properties

    private var isVideoInputSupported: Bool {
        // 動画入力はGeminiのみ対応
        settings.selectedProvider == .gemini
    }

    private var hasValidInput: Bool {
        switch inputMode {
        case .url:
            return !videoURLString.isEmpty && URL(string: videoURLString) != nil
        case .video:
            return selectedVideoData != nil
        }
    }

    // MARK: - Actions

    private func analyzeVideo() {
        state = .loading
        tokenUsage = nil
        errorDetails = nil

        Task {
            do {
                // 動画コンテンツを作成
                let videoContent: VideoContent
                switch inputMode {
                case .url:
                    guard let url = URL(string: videoURLString) else {
                        throw LLMError.invalidRequest("Invalid URL")
                    }
                    videoContent = VideoContent.url(url, mediaType: .mp4)

                case .video:
                    guard let data = selectedVideoData else {
                        throw LLMError.invalidRequest("No video selected")
                    }
                    videoContent = VideoContent.base64(data, mediaType: .mp4)
                }

                // メッセージを作成
                let message = LLMMessage.user(
                    "この動画を詳しく分析してください。",
                    video: videoContent
                )

                // Geminiで実行
                try await analyzeWithGemini(message: message)
            } catch let error as LLMError {
                state = .error(error)
                errorDetails = formatLLMError(error)
            } catch {
                state = .error(error)
                errorDetails = error.localizedDescription
            }
        }
    }

    private func analyzeWithGemini(message: LLMMessage) async throws {
        guard let client = settings.createGeminiClient() else { return }

        // generate() を使用（chat() はメディアコンテンツ非対応）
        let result: VideoAnalysisResult = try await client.generate(
            messages: [message],
            model: settings.geminiModelOption.model,
            systemPrompt: "動画を分析し、指定されたJSON形式で結果を返してください。",
            temperature: settings.temperature,
            maxTokens: settings.maxTokens
        )
        state = .success(result)
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
            マルチモーダル入力を使って動画を分析します。

            動画をLLMに送信し、構造化された分析結果を取得します：
            • 動画の説明と主要な対象
            • アクション・イベントの検出
            • 雰囲気・シーンタイプ
            • 音声・テキストの検出

            ⚠️ 動画入力はGeminiのみ対応しています。
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
                title: "動画URL",
                text: $urlString,
                minHeight: 60
            )
        }
    }
}

// MARK: - Video Input Section

private struct VideoInputSection: View {
    @Binding var showVideoPicker: Bool
    @Binding var selectedVideoData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("動画を選択")
                .font(.subheadline.bold())

            Button {
                showVideoPicker = true
            } label: {
                Label(
                    selectedVideoData == nil ? "動画を選択" : "動画を変更",
                    systemImage: "video.badge.plus"
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .videoPicker(
                isPresented: $showVideoPicker,
                selectedVideoData: $selectedVideoData,
                maxSize: 50.mb,
                maxDuration: 60
            )

            if selectedVideoData != nil {
                Button {
                    selectedVideoData = nil
                } label: {
                    Label("クリア", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Video Preview Section

private struct VideoPreviewSection: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let inputMode: VideoVisionDemo.InputMode
    let urlString: String
    let videoData: Data?

    private var previewHeight: CGFloat {
        horizontalSizeClass == .regular ? 400 : 240
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プレビュー")
                .font(.subheadline.bold())

            Group {
                switch inputMode {
                case .url:
                    if let url = URL(string: urlString) {
                        VideoPlayerView(url: url)
                            .showMetadata(true)
                            .showActions([.play])
                    } else {
                        ContentUnavailableView(
                            "URLが無効です",
                            systemImage: "link.badge.plus",
                            description: Text("有効なURLを入力してください")
                        )
                    }

                case .video:
                    if let data = videoData {
                        VideoPlayerView(data: data)
                            .showMetadata(true)
                            .showActions([.play])
                    } else {
                        ContentUnavailableView(
                            "動画を選択してください",
                            systemImage: "video.badge.plus",
                            description: Text("カメラまたはライブラリから選択")
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: previewHeight)
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
        @Structured("動画の分析結果")
        struct VideoAnalysisResult {
            @StructuredField("動画の説明")
            var summary: String

            @StructuredField("検出されたオブジェクト")
            var subjects: [String]
        }

        // 動画コンテンツを作成
        let video = VideoContent.url(
            URL(string: "https://example.com/video.mp4")!,
            mediaType: .mp4
        )

        // メッセージを作成
        let message = LLMMessage.user(
            "この動画を分析してください",
            video: video
        )

        // Geminiクライアントで実行（動画入力はGeminiのみ対応）
        let client = GeminiClient(apiKey: "...")
        let response = try await client.generate(
            messages: [message],
            model: .flash,
            type: VideoAnalysisResult.self
        )

        print(response.result.summary)
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VideoVisionDemo()
    }
}
