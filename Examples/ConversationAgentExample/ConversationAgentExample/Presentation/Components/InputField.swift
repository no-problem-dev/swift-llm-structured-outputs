import SwiftUI

/// 送信ボタン付きのテキスト入力フィールド
///
/// 汎用的な入力コンポーネント。プレースホルダー、アイコン、色などを
/// `Configuration`で指定することで様々な用途に対応する。
struct InputField: View {

    /// 入力フィールドの表示設定
    struct Configuration {
        let placeholder: String
        let submitIcon: String
        let submitTint: Color
        let allowEmptySubmit: Bool

        init(
            placeholder: String,
            submitIcon: String,
            submitTint: Color,
            allowEmptySubmit: Bool = false
        ) {
            self.placeholder = placeholder
            self.submitIcon = submitIcon
            self.submitTint = submitTint
            self.allowEmptySubmit = allowEmptySubmit
        }
    }

    /// 入力フィールドの左側に表示するアクションボタン
    struct LeadingAction {
        let icon: String
        let tint: Color
        let action: () -> Void
    }

    let configuration: Configuration
    @Binding var text: String
    let isEnabled: Bool
    let onSubmit: () -> Void
    var leadingAction: LeadingAction?

    private var canSubmit: Bool {
        isEnabled && (configuration.allowEmptySubmit || !text.isEmpty)
    }

    var body: some View {
        HStack {
            if let action = leadingAction {
                Button(action: action.action) {
                    Image(systemName: action.icon)
                }
                .buttonStyle(.borderedProminent)
                .tint(action.tint)
            }

            TextField(configuration.placeholder, text: $text, axis: .vertical)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .lineLimit(1...5)
                .onSubmit {
                    if canSubmit {
                        onSubmit()
                    }
                }

            Button(action: onSubmit) {
                Image(systemName: configuration.submitIcon)
            }
            .buttonStyle(.borderedProminent)
            .tint(configuration.submitTint)
            .disabled(!canSubmit)
        }
    }
}

#Preview("Standard") {
    InputField(
        configuration: .init(
            placeholder: "Enter text...",
            submitIcon: "paperplane.fill",
            submitTint: .accentColor
        ),
        text: .constant(""),
        isEnabled: true,
        onSubmit: {}
    )
    .padding()
}

#Preview("With Leading Action") {
    InputField(
        configuration: .init(
            placeholder: "Enter text...",
            submitIcon: "bolt.fill",
            submitTint: .orange
        ),
        text: .constant("Hello"),
        isEnabled: true,
        onSubmit: {},
        leadingAction: .init(icon: "stop.fill", tint: .red, action: {})
    )
    .padding()
}

#Preview("Allow Empty Submit") {
    InputField(
        configuration: .init(
            placeholder: "Optional input...",
            submitIcon: "play.fill",
            submitTint: .green,
            allowEmptySubmit: true
        ),
        text: .constant(""),
        isEnabled: true,
        onSubmit: {}
    )
    .padding()
}
