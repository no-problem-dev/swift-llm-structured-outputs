//
//  ResultDisplayView.swift
//  LLMStructuredOutputsExample
//
//  構造化出力結果の表示コンポーネント
//

import SwiftUI
import LLMStructuredOutputs

// MARK: - LoadingState

/// ローディング状態
enum LoadingState<T> {
    case idle
    case loading
    case success(T)
    case error(Error)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var result: T? {
        if case .success(let value) = self { return value }
        return nil
    }

    var error: Error? {
        if case .error(let error) = self { return error }
        return nil
    }
}

// MARK: - ResultDisplayView

/// 結果表示ビュー
///
/// 構造化出力の結果をJSON形式で表示します。
struct ResultDisplayView<T: Encodable>: View {
    let state: LoadingState<T>
    let usage: TokenUsage?

    init(state: LoadingState<T>, usage: TokenUsage? = nil) {
        self.state = state
        self.usage = usage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Label("実行結果", systemImage: "doc.text")
                    .font(.headline)

                Spacer()

                if state.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            // コンテンツ
            Group {
                switch state {
                case .idle:
                    ContentUnavailableView(
                        "実行前",
                        systemImage: "play.circle",
                        description: Text("「実行」ボタンを押してAPIを呼び出してください")
                    )

                case .loading:
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("生成中...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)

                case .success(let result):
                    VStack(alignment: .leading, spacing: 8) {
                        // JSON表示
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(formatJSON(result))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        // トークン使用量
                        if let usage = usage {
                            TokenUsageView(usage: usage)
                        }
                    }

                case .error(let error):
                    ErrorView(error: error)
                }
            }
        }
        .animation(.default, value: state.isLoading)
    }

    /// 結果をJSON文字列にフォーマット
    private func formatJSON(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(value),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "JSONへの変換に失敗しました"
        }

        return jsonString
    }
}

// MARK: - TokenUsageView

/// トークン使用量表示
struct TokenUsageView: View {
    let usage: TokenUsage

    var body: some View {
        HStack(spacing: 16) {
            Label("入力: \(usage.inputTokens)", systemImage: "arrow.up.circle")
            Label("出力: \(usage.outputTokens)", systemImage: "arrow.down.circle")
            Label("合計: \(usage.totalTokens)", systemImage: "sum")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - ErrorView

/// エラー表示
struct ErrorView: View {
    let error: Error

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("エラーが発生しました", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.red)

            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let suggestion = errorSuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var errorMessage: String {
        if let llmError = error as? LLMError {
            return llmError.localizedDescription
        }
        return error.localizedDescription
    }

    private var errorSuggestion: String? {
        if let llmError = error as? LLMError {
            switch llmError {
            case .unauthorized:
                return "💡 APIキーが正しく設定されているか確認してください"
            case .rateLimitExceeded:
                return "💡 しばらく待ってから再試行してください"
            case .networkError:
                return "💡 インターネット接続を確認してください"
            case .decodingFailed:
                return "💡 出力形式が期待と異なります。プロンプトを調整してみてください"
            default:
                return nil
            }
        }
        return nil
    }
}

// MARK: - APIKeyRequiredView

/// APIキー未設定時の表示
struct APIKeyRequiredView: View {
    let provider: AppSettings.Provider
    @State private var showingGuide = false

    var body: some View {
        ContentUnavailableView {
            Label("APIキーが必要です", systemImage: "key.slash")
        } description: {
            Text("\(provider.shortName) を使用するには、APIキーを設定してください")
        } actions: {
            Button("設定方法を見る") {
                showingGuide = true
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showingGuide) {
            APIKeyGuideView()
        }
    }
}

// MARK: - SampleInputPicker

/// サンプル入力選択
struct SampleInputPicker: View {
    let samples: [String]
    let descriptions: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack {
            Text("サンプル入力")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Spacer()

            Picker("サンプル", selection: $selectedIndex) {
                ForEach(Array(descriptions.enumerated()), id: \.offset) { index, description in
                    Text(description).tag(index)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

// MARK: - InputTextEditor

/// 入力テキストエディタ
struct InputTextEditor: View {
    let title: String
    @Binding var text: String
    var minHeight: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - ExecuteButton

/// 実行ボタン
struct ExecuteButton: View {
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "play.fill")
                }
                Text(isLoading ? "生成中..." : "実行")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isEnabled || isLoading)
    }
}
