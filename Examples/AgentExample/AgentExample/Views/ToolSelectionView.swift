//
//  ToolSelectionView.swift
//  AgentExample
//
//  ツール選択ビュー
//

import SwiftUI

/// ツール選択セクション
///
/// エージェントが使用するツールの有効/無効を切り替えるUI。
/// 各ツールをカード形式で表示し、タップで選択を切り替えます。
struct ToolSelectionSection: View {
    private var config = ToolConfiguration.shared

    /// 折りたたみ状態
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("使用するツール")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Spacer()

                    // 選択数バッジ
                    Text("\(config.usableCount)/\(ToolIdentifier.allCases.count)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(config.hasUsableTools ? Color.blue : Color.gray)
                        .clipShape(Capsule())

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // ツールグリッド
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(ToolIdentifier.allCases) { tool in
                        ToolCard(tool: tool)
                    }
                }

                // 一括操作
                HStack(spacing: 12) {
                    Button("すべて選択") {
                        config.enableAll()
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .disabled(config.enabledCount == ToolIdentifier.allCases.count)

                    Button("すべて解除") {
                        config.disableAll()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                    .disabled(config.enabledCount == 0)

                    Spacer()
                }
                .padding(.top, 4)

                // 警告メッセージ
                if !config.hasUsableTools {
                    Label("少なくとも1つのツールを選択してください", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if config.isEnabled(.webSearch) && !ToolIdentifier.webSearch.isAvailable {
                    Label("Web検索を使用するには Brave Search API キーを設定してください", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: - Tool Card

/// 個別ツールカード
fileprivate struct ToolCard: View {
    let tool: ToolIdentifier
    var config = ToolConfiguration.shared

    private var isEnabled: Bool {
        config.isEnabled(tool)
    }

    private var isAvailable: Bool {
        tool.isAvailable
    }

    private var isUsable: Bool {
        isEnabled && isAvailable
    }

    var body: some View {
        Button {
            config.toggle(tool)
        } label: {
            VStack(spacing: 6) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 36, height: 36)

                    Image(systemName: tool.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconForegroundColor)
                }

                // ツール名
                Text(tool.displayName)
                    .font(.caption2)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                    .lineLimit(1)

                // ステータスインジケーター
                if isEnabled && !isAvailable {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: isEnabled ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconBackgroundColor: Color {
        if isUsable {
            return .blue.opacity(0.15)
        } else if isEnabled {
            return .orange.opacity(0.15)
        } else {
            return Color(.systemGray5)
        }
    }

    private var iconForegroundColor: Color {
        if isUsable {
            return .blue
        } else if isEnabled {
            return .orange
        } else {
            return .secondary
        }
    }

    private var cardBackground: Color {
        if isEnabled {
            return Color(.systemGray6)
        } else {
            return Color(.systemGray6).opacity(0.5)
        }
    }

    private var borderColor: Color {
        if isUsable {
            return .blue.opacity(0.5)
        } else if isEnabled {
            return .orange.opacity(0.5)
        } else {
            return .clear
        }
    }
}

// MARK: - Compact Tool Selection (for Settings)

/// コンパクトなツール選択リスト（設定画面用）
struct ToolSelectionList: View {
    private var config = ToolConfiguration.shared

    var body: some View {
        ForEach(ToolIdentifier.allCases) { tool in
            ToolSelectionRow(tool: tool)
        }
    }
}

/// ツール選択行（設定画面用）
fileprivate struct ToolSelectionRow: View {
    let tool: ToolIdentifier
    var config = ToolConfiguration.shared

    var body: some View {
        Toggle(isOn: Binding(
            get: { config.isEnabled(tool) },
            set: { config.setEnabled(tool, enabled: $0) }
        )) {
            HStack(spacing: 12) {
                Image(systemName: tool.icon)
                    .font(.body)
                    .foregroundStyle(tool.isAvailable ? .blue : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.displayName)
                        .font(.body)

                    if !tool.isAvailable {
                        Text("APIキーが必要です")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .tint(.blue)
    }
}

// MARK: - Preview

#Preview("Selection Section") {
    ScrollView {
        ToolSelectionSection()
            .padding()
    }
}

#Preview("Selection List") {
    Form {
        Section("ツール選択") {
            ToolSelectionList()
        }
    }
}
