//
//  APIKeyGuideView.swift
//  LLMStructuredOutputsExample
//
//  APIキー設定方法のガイド
//

import SwiftUI

/// APIキー設定方法のガイド画面
///
/// 環境変数でのAPIキー設定方法を説明します。
struct APIKeyGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - 概要
                    VStack(alignment: .leading, spacing: 8) {
                        Label("APIキーの設定方法", systemImage: "key.fill")
                            .font(.title2.bold())

                        Text("このアプリでは、セキュリティのためAPIキーを環境変数から読み込みます。Xcodeの設定で環境変数を追加してください。")
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // MARK: - 手順
                    VStack(alignment: .leading, spacing: 16) {
                        Text("設定手順")
                            .font(.headline)

                        StepView(
                            number: 1,
                            title: "Scheme設定を開く",
                            description: "Xcode のメニューから\nProduct → Scheme → Edit Scheme...\nを選択します（または ⌘<）"
                        )

                        StepView(
                            number: 2,
                            title: "Run タブを選択",
                            description: "左側のリストから「Run」を選択し、上部の「Arguments」タブをクリックします"
                        )

                        StepView(
                            number: 3,
                            title: "環境変数を追加",
                            description: "「Environment Variables」セクションで「+」ボタンをクリックし、以下の変数を追加します"
                        )
                    }

                    // MARK: - 環境変数一覧
                    VStack(alignment: .leading, spacing: 12) {
                        Text("追加する環境変数")
                            .font(.headline)

                        EnvironmentVariableRow(
                            name: "ANTHROPIC_API_KEY",
                            description: "Anthropic の APIキー",
                            example: "sk-ant-api03-..."
                        )

                        EnvironmentVariableRow(
                            name: "OPENAI_API_KEY",
                            description: "OpenAI の APIキー",
                            example: "sk-proj-..."
                        )

                        EnvironmentVariableRow(
                            name: "GEMINI_API_KEY",
                            description: "Google Gemini の APIキー",
                            example: "AIzaSy..."
                        )
                    }

                    // MARK: - APIキー取得先
                    VStack(alignment: .leading, spacing: 12) {
                        Text("APIキーの取得先")
                            .font(.headline)

                        APIKeySourceRow(
                            provider: "Anthropic",
                            url: "https://console.anthropic.com/settings/keys"
                        )

                        APIKeySourceRow(
                            provider: "OpenAI",
                            url: "https://platform.openai.com/api-keys"
                        )

                        APIKeySourceRow(
                            provider: "Google AI Studio",
                            url: "https://aistudio.google.com/app/apikey"
                        )
                    }

                    // MARK: - 注意事項
                    VStack(alignment: .leading, spacing: 8) {
                        Label("注意事項", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)

                        Text("• APIキーは絶対にソースコードにハードコードしないでください")
                        Text("• APIキーを含むファイルはGitにコミットしないでください")
                        Text("• 各プロバイダーの利用規約と料金体系を確認してください")
                        Text("• このアプリでAPIを呼び出すと料金が発生する場合があります")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("APIキー設定ガイド")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - StepView

/// 手順の1ステップを表示
private struct StepView: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - EnvironmentVariableRow

/// 環境変数の情報行
private struct EnvironmentVariableRow: View {
    let name: String
    let description: String
    let example: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("例: \(example)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - APIKeySourceRow

/// APIキー取得先の情報行
private struct APIKeySourceRow: View {
    let provider: String
    let url: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(provider)
                .font(.subheadline.bold())

            if let urlObject = URL(string: url) {
                Link(destination: urlObject) {
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            } else {
                Text(url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    APIKeyGuideView()
}
