//
//  SpeechGenerationDemo.swift
//  LLMStructuredOutputsExample
//
//  音声生成（TTS）デモ
//

import SwiftUI
import AVFoundation
import LLMStructuredOutputs

/// 音声生成（TTS）デモ
///
/// OpenAI TTS を使ってテキストから音声を生成します。
/// 様々な声やフォーマットを選択できます。
struct SpeechGenerationDemo: View {
    private var settings = AppSettings.shared

    // MARK: - State

    @State private var selectedSampleIndex = 0
    @State private var inputText = sampleTexts[0]
    @State private var selectedModel: OpenAITTSModel = .tts1HD
    @State private var selectedVoice: OpenAIVoice = .alloy
    @State private var selectedSpeed: Double = 1.0
    @State private var selectedFormat: AudioOutputFormat = .mp3
    @State private var state: SpeechGenerationState = .idle
    @State private var generatedAudio: GeneratedAudio?
    @State private var errorDetails: String?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false

    enum SpeechGenerationState {
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

    private static let sampleTexts = [
        "こんにちは、世界！これは音声合成のテストです。",
        "The quick brown fox jumps over the lazy dog. This sentence contains every letter of the alphabet.",
        "人工知能は、人間の知能を模倣し、学習、推論、問題解決などのタスクを実行するコンピューターシステムです。",
        "Welcome to the future of text-to-speech technology. Experience natural, human-like voices."
    ]

    private static let sampleDescriptions = [
        "日本語挨拶",
        "英語アルファベット",
        "AI説明文",
        "英語ナレーション"
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

                // MARK: - テキスト入力
                VStack(alignment: .leading, spacing: 12) {
                    SampleInputPicker(
                        samples: Self.sampleTexts,
                        descriptions: Self.sampleDescriptions,
                        selectedIndex: $selectedSampleIndex
                    )
                    .onChange(of: selectedSampleIndex) { _, newValue in
                        inputText = Self.sampleTexts[newValue]
                    }

                    InputTextEditor(
                        title: "読み上げテキスト",
                        text: $inputText,
                        minHeight: 100
                    )

                    // 文字数表示
                    HStack {
                        Text("\(inputText.count) / 4096 文字")
                            .font(.caption)
                            .foregroundStyle(inputText.count > 4096 ? .red : .secondary)

                        Spacer()
                    }
                }

                // MARK: - オプション設定
                if isSpeechGenerationSupported {
                    OptionsSection(
                        selectedModel: $selectedModel,
                        selectedVoice: $selectedVoice,
                        selectedSpeed: $selectedSpeed,
                        selectedFormat: $selectedFormat
                    )
                }

                // MARK: - 実行
                if settings.isCurrentProviderAvailable {
                    if isSpeechGenerationSupported {
                        ExecuteButton(
                            isLoading: state.isLoading,
                            isEnabled: !inputText.isEmpty && inputText.count <= 4096
                        ) {
                            generateSpeech()
                        }
                    } else {
                        UnsupportedProviderView(
                            feature: "音声生成",
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
                    generatedAudio: generatedAudio,
                    isPlaying: isPlaying,
                    onPlay: playAudio,
                    onStop: stopAudio,
                    onSave: saveAudio
                )

                // MARK: - コード例
                CodeExampleSection()
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("音声生成（TTS）")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopAudio()
        }
    }

    // MARK: - Computed Properties

    private var isSpeechGenerationSupported: Bool {
        switch settings.selectedProvider {
        case .openai:
            return true  // TTS-1 / TTS-1 HD サポート
        case .gemini:
            return false  // Gemini TTS は別途対応が必要
        case .anthropic:
            return false  // Claude は音声生成非対応
        }
    }

    // MARK: - Actions

    private func generateSpeech() {
        state = .loading
        generatedAudio = nil
        errorDetails = nil
        stopAudio()

        Task {
            do {
                switch settings.selectedProvider {
                case .openai:
                    try await generateWithOpenAI()
                default:
                    throw SpeechGenerationError.notSupportedByProvider(settings.selectedProvider.shortName)
                }
            } catch let error as SpeechGenerationError {
                state = .error(error)
                errorDetails = error.errorDescription
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

        let audio = try await client.generateSpeech(
            input: LLMInput(inputText),
            model: selectedModel,
            voice: selectedVoice,
            speed: selectedSpeed,
            format: selectedFormat
        )

        generatedAudio = audio
        state = .success
    }

    private func playAudio() {
        guard let audio = generatedAudio else { return }

        do {
            // オーディオセッションを設定
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            guard let player = audio.audioPlayer else {
                errorDetails = "再生エラー: オーディオプレーヤーを作成できませんでした"
                return
            }
            audioPlayer = player
            audioPlayer?.delegate = AudioPlayerDelegate.shared
            AudioPlayerDelegate.shared.onFinish = {
                isPlaying = false
            }
            audioPlayer?.play()
            isPlaying = true
        } catch {
            errorDetails = "再生エラー: \(error.localizedDescription)"
        }
    }

    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    private func saveAudio() {
        guard let audio = generatedAudio else { return }

        // ドキュメントディレクトリに保存
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "generated_speech_\(Date().timeIntervalSince1970).\(audio.format.fileExtension)"
        let fileURL = documentsPath.appendingPathComponent(fileName)

        do {
            try audio.save(to: fileURL)
            errorDetails = nil
            // 保存成功のフィードバック
        } catch {
            errorDetails = "保存エラー: \(error.localizedDescription)"
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

// MARK: - Audio Player Delegate

@MainActor
private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    static let shared = AudioPlayerDelegate()
    var onFinish: (() -> Void)?

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.onFinish?()
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
            テキストから自然な音声を生成します。

            OpenAI TTS（Text-to-Speech）を使用：
            • 6種類の声から選択（Alloy, Echo, Fable, Onyx, Nova, Shimmer）
            • 再生速度の調整（0.25x〜4.0x）
            • 複数の出力フォーマット（MP3, WAV, OPUS, AAC, FLAC, PCM）
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
                    Text("TTS").font(.caption.bold())
                    Text("モデル").font(.caption.bold())
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
                    SupportIcon(supported: true)
                    Text("TTS-1, TTS-1 HD").font(.system(size: 9))
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
                    SupportIcon(supported: true, note: "予定")
                    Text("-").font(.system(size: 9))
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
                    SupportIcon(supported: false)
                    Text("-").font(.system(size: 9))
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
    @Binding var selectedModel: OpenAITTSModel
    @Binding var selectedVoice: OpenAIVoice
    @Binding var selectedSpeed: Double
    @Binding var selectedFormat: AudioOutputFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生成オプション")
                .font(.subheadline.bold())

            // モデル
            VStack(alignment: .leading, spacing: 4) {
                Text("モデル")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("モデル", selection: $selectedModel) {
                    Text("TTS-1（標準）").tag(OpenAITTSModel.tts1)
                    Text("TTS-1 HD（高品質）").tag(OpenAITTSModel.tts1HD)
                }
                .pickerStyle(.segmented)
            }

            // 声
            VStack(alignment: .leading, spacing: 4) {
                Text("声")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(OpenAIVoice.allCases, id: \.self) { voice in
                            VoiceButton(
                                voice: voice,
                                isSelected: selectedVoice == voice
                            ) {
                                selectedVoice = voice
                            }
                        }
                    }
                }
            }

            // 速度
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("速度")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(String(format: "%.1fx", selectedSpeed))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $selectedSpeed, in: 0.25...4.0, step: 0.25)
            }

            // フォーマット
            VStack(alignment: .leading, spacing: 4) {
                Text("出力フォーマット")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("フォーマット", selection: $selectedFormat) {
                    Text("MP3").tag(AudioOutputFormat.mp3)
                    Text("WAV").tag(AudioOutputFormat.wav)
                    Text("OPUS").tag(AudioOutputFormat.opus)
                    Text("AAC").tag(AudioOutputFormat.aac)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Voice Button

private struct VoiceButton: View {
    let voice: OpenAIVoice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: voiceIcon)
                    .font(.title3)
                Text(voice.displayName)
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var voiceIcon: String {
        switch voice {
        case .alloy: return "person.wave.2"
        case .echo: return "waveform"
        case .fable: return "book"
        case .onyx: return "diamond"
        case .nova: return "sparkle"
        case .shimmer: return "wand.and.stars"
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
    let state: SpeechGenerationDemo.SpeechGenerationState
    let generatedAudio: GeneratedAudio?
    let isPlaying: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("生成結果", systemImage: "speaker.wave.3.fill")
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
                        systemImage: "speaker.badge.exclamationmark",
                        description: Text("「実行」ボタンを押して音声を生成")
                    )

                case .loading:
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("音声を生成中...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)

                case .success:
                    if let audio = generatedAudio {
                        GeneratedAudioView(
                            audio: audio,
                            isPlaying: isPlaying,
                            onPlay: onPlay,
                            onStop: onStop,
                            onSave: onSave
                        )
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

// MARK: - Generated Audio View

private struct GeneratedAudioView: View {
    let audio: GeneratedAudio
    let isPlaying: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 音声情報
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("フォーマット: \(audio.format.rawValue.uppercased())")
                        .font(.caption)
                    Text("サイズ: \(formatBytes(audio.data.count))")
                        .font(.caption)
                    if let duration = audio.estimatedDuration {
                        Text("推定時間: \(String(format: "%.1f秒", duration))")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 再生コントロール
            HStack(spacing: 12) {
                Button {
                    if isPlaying {
                        onStop()
                    } else {
                        onPlay()
                    }
                } label: {
                    Label(
                        isPlaying ? "停止" : "再生",
                        systemImage: isPlaying ? "stop.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onSave()
                } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }

            // 元のテキスト
            if let transcript = audio.transcript {
                VStack(alignment: .leading, spacing: 4) {
                    Text("元のテキスト")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(transcript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
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
        import AVFoundation

        // OpenAI クライアントを作成
        let client = OpenAIClient(apiKey: "sk-...")

        // 音声を生成
        let audio = try await client.generateSpeech(
            input: "こんにちは、世界！",
            model: .tts1HD,
            voice: .nova,
            speed: 1.0,
            format: .mp3
        )

        // 音声を再生
        if let player = audio.audioPlayer {
            player.play()
        }

        // ファイルに保存
        try audio.save(to: fileURL)

        // Data として取得
        let data = audio.data
        """
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SpeechGenerationDemo()
    }
}
