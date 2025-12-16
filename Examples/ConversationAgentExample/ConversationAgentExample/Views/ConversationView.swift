//
//  ConversationView.swift
//  ConversationAgentExample
//
//  会話画面
//

import SwiftUI

/// 会話画面
///
/// ConversationalAgentSession を使用したマルチターン会話のデモ画面です。
struct ConversationView: View {
    @Bindable var controller: ConversationController
    @State private var promptText = ""
    @State private var interruptText = ""
    @State private var showEventLog = false
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // 中央: メインコンテンツ（ステップと結果）
            mainContentSection

            Divider()

            // 下部: 入力エリア
            inputSection
        }
        .navigationTitle("会話エージェント")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .disabled(controller.state.isRunning)
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    // ターン数表示
                    if controller.turnCount > 0 {
                        Text("ターン \(controller.turnCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // イベントログボタン
                    Button {
                        showEventLog.toggle()
                    } label: {
                        Image(systemName: showEventLog ? "list.bullet.circle.fill" : "list.bullet.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "セッションをクリア",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("クリア", role: .destructive) {
                Task {
                    await controller.clearSession()
                    controller.createSession()
                    promptText = ""
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在の会話履歴がすべて削除されます。この操作は取り消せません。")
        }
        .sheet(isPresented: $showEventLog) {
            NavigationStack {
                EventLogView(events: controller.events)
                    .navigationTitle("イベントログ")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") {
                                showEventLog = false
                            }
                        }
                    }
            }
        }
        .onAppear {
            controller.createSessionIfNeeded()
        }
    }

    // MARK: - Main Content Section

    private var mainContentSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 結果表示（完了時）
                if case .completed(let result) = controller.state {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("結果", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        ResultView(result: result)
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.vertical, 8)
                }

                // エラー表示
                if case .error(let message) = controller.state {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }

                // ステップリスト
                StepListView(
                    steps: controller.steps,
                    isLoading: controller.state.isRunning
                )
            }
            .padding(.vertical)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 12) {
            // 入力欄（状態に応じて切り替え）
            HStack {
                if controller.state.isRunning {
                    // 実行中: 割り込み入力
                    TextField("割り込みメッセージを入力...", text: $interruptText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)

                    Button {
                        sendInterrupt()
                    } label: {
                        Image(systemName: "bolt.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(interruptText.isEmpty)
                } else {
                    // 待機中・完了後: 質問入力
                    TextField("質問を入力...", text: $promptText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)

                    Button {
                        runQuery()
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canRun)
                }
            }

            // APIキー状態表示
            if !APIKeyManager.hasAnyLLMKey || !APIKeyManager.hasBraveSearchKey {
                HStack {
                    Spacer()

                    if !APIKeyManager.hasAnyLLMKey {
                        Label("APIキーが未設定", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if !APIKeyManager.hasBraveSearchKey {
                        Label("検索APIが未設定", systemImage: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Actions

    private var canRun: Bool {
        !promptText.isEmpty &&
        !controller.state.isRunning &&
        APIKeyManager.hasAnyLLMKey
    }

    private func runQuery() {
        guard canRun else { return }
        controller.run(prompt: promptText, outputType: .research)
        promptText = ""
    }

    private func sendInterrupt() {
        guard !interruptText.isEmpty else { return }
        Task {
            await controller.interrupt(message: interruptText)
            interruptText = ""
        }
    }
}

#Preview {
    @Previewable @State var controller = ConversationController()
    NavigationStack {
        ConversationView(controller: controller)
    }
}
