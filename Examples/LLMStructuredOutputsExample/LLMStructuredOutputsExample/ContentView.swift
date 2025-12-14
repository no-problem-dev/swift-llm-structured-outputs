//
//  ContentView.swift
//  LLMStructuredOutputsExample
//
//  メインナビゲーション画面
//

import SwiftUI

/// メインコンテンツビュー
///
/// 各デモへのナビゲーションと設定へのアクセスを提供します。
struct ContentView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            List {
                // MARK: - 現在の設定表示
                Section {
                    CurrentSettingsRow()
                } header: {
                    Text("現在の設定")
                }

                // MARK: - 基本機能デモ
                Section {
                    NavigationLink {
                        BasicStructuredOutputDemo()
                    } label: {
                        DemoRow(
                            icon: "doc.text.fill",
                            color: .blue,
                            title: "基本の構造化出力",
                            description: "@Structured マクロで型安全に情報を抽出"
                        )
                    }

                    NavigationLink {
                        FieldConstraintsDemo()
                    } label: {
                        DemoRow(
                            icon: "ruler.fill",
                            color: .orange,
                            title: "制約の活用",
                            description: "最小値・最大値・文字数制限などを設定"
                        )
                    }

                    NavigationLink {
                        EnumSupportDemo()
                    } label: {
                        DemoRow(
                            icon: "list.bullet.rectangle.fill",
                            color: .purple,
                            title: "Enum対応",
                            description: "選択肢を限定した分類・ステータス管理"
                        )
                    }
                } header: {
                    Text("基本機能")
                }

                // MARK: - プロンプト関連デモ
                Section {
                    NavigationLink {
                        PromptDSLDemo()
                    } label: {
                        DemoRow(
                            icon: "text.alignleft",
                            color: .green,
                            title: "Prompt DSL",
                            description: "構造化されたプロンプトの構築"
                        )
                    }

                    NavigationLink {
                        PromptBuilderDemo()
                    } label: {
                        DemoRow(
                            icon: "slider.horizontal.3",
                            color: .cyan,
                            title: "Prompt Builder",
                            description: "インタラクティブにプロンプトを組み立て"
                        )
                    }
                } header: {
                    Text("プロンプト")
                }

                // MARK: - 会話機能デモ
                Section {
                    NavigationLink {
                        ConversationDemo()
                    } label: {
                        DemoRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            color: .indigo,
                            title: "マルチターン会話",
                            description: "文脈を維持した連続的なやりとり"
                        )
                    }

                    NavigationLink {
                        EventStreamDemo()
                    } label: {
                        DemoRow(
                            icon: "waveform",
                            color: .pink,
                            title: "イベントストリーム",
                            description: "リアルタイムでイベントを監視"
                        )
                    }
                } header: {
                    Text("会話機能")
                }

                // MARK: - 高度な機能デモ
                Section {
                    NavigationLink {
                        ToolCallingDemo()
                    } label: {
                        DemoRow(
                            icon: "wrench.and.screwdriver.fill",
                            color: .teal,
                            title: "ツールコール",
                            description: "@Tool マクロでLLMに関数を呼び出させる"
                        )
                    }

                    NavigationLink {
                        AgentLoopDemo()
                    } label: {
                        DemoRow(
                            icon: "arrow.trianglehead.2.clockwise.rotate.90",
                            color: .mint,
                            title: "エージェントループ",
                            description: "ツール実行と構造化出力の自動ループ"
                        )
                    }

                    NavigationLink {
                        MultiProviderDemo()
                    } label: {
                        DemoRow(
                            icon: "square.stack.3d.up.fill",
                            color: .red,
                            title: "プロバイダー比較",
                            description: "同じ入力を複数のLLMで比較"
                        )
                    }
                } header: {
                    Text("高度な機能")
                }
            }
            .navigationTitle("LLM構造化出力")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
    }
}

// MARK: - CurrentSettingsRow

/// 現在の設定を表示する行
private struct CurrentSettingsRow: View {
    private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(settings.selectedProvider.shortName, systemImage: providerIcon)
                    .font(.subheadline.bold())

                Spacer()

                if settings.selectedProvider.hasAPIKey {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Text("APIキー未設定")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Text(settings.currentModelDisplayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var providerIcon: String {
        switch settings.selectedProvider {
        case .anthropic: return "brain.head.profile"
        case .openai: return "sparkles"
        case .gemini: return "diamond.fill"
        }
    }
}

// MARK: - DemoRow

/// デモ項目の行
private struct DemoRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
