import SwiftUI

/// 送信ボタン付きのテキスト入力フィールド
///
/// 汎用的な入力コンポーネント。プレースホルダー、アイコン、色などを
/// `Configuration`で指定することで様々な用途に対応する。
public struct InputField: View {

    /// 入力フィールドの表示設定
    public struct Configuration {
        public let placeholder: String
        public let submitIcon: String
        public let submitTint: Color
        public let allowEmptySubmit: Bool

        public init(
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
    public struct LeadingAction {
        public let icon: String
        public let tint: Color
        public let action: () -> Void

        public init(icon: String, tint: Color, action: @escaping () -> Void) {
            self.icon = icon
            self.tint = tint
            self.action = action
        }
    }

    public let configuration: Configuration
    @Binding public var text: String
    public let isEnabled: Bool
    public let onSubmit: () -> Void
    public var leadingAction: LeadingAction?

    public init(
        configuration: Configuration,
        text: Binding<String>,
        isEnabled: Bool,
        onSubmit: @escaping () -> Void,
        leadingAction: LeadingAction? = nil
    ) {
        self.configuration = configuration
        self._text = text
        self.isEnabled = isEnabled
        self.onSubmit = onSubmit
        self.leadingAction = leadingAction
    }

    private var canSubmit: Bool {
        isEnabled && (configuration.allowEmptySubmit || !text.isEmpty)
    }

    #if os(iOS)
    private var backgroundColor: Color { Color(.systemBackground) }
    private var borderColor: Color { Color(.systemGray4) }
    #else
    private var backgroundColor: Color { Color(nsColor: .textBackgroundColor) }
    private var borderColor: Color { Color(nsColor: .separatorColor) }
    #endif

    public var body: some View {
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
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
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
