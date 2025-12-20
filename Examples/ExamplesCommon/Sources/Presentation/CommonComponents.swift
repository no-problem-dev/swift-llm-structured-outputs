import SwiftUI

// MARK: - Optional Number Fields

/// オプショナルな整数値を入力するためのフィールド
public struct OptionalIntField: View {
    public let title: String
    @Binding public var value: Int?

    public init(title: String, value: Binding<Int?>) {
        self.title = title
        self._value = value
    }

    public var body: some View {
        HStack {
            Text(title)

            Spacer()

            TextField("未設定", text: Binding(
                get: { value.map { String($0) } ?? "" },
                set: { newValue in
                    if newValue.isEmpty {
                        value = nil
                    } else if let intValue = Int(newValue) {
                        value = intValue
                    }
                }
            ))
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
        }
    }
}

/// オプショナルな小数値を入力するためのフィールド
public struct OptionalDoubleField: View {
    public let title: String
    @Binding public var value: Double?

    public init(title: String, value: Binding<Double?>) {
        self.title = title
        self._value = value
    }

    public var body: some View {
        HStack {
            Text(title)

            Spacer()

            TextField("未設定", text: Binding(
                get: { value.map { String($0) } ?? "" },
                set: { newValue in
                    if newValue.isEmpty {
                        value = nil
                    } else if let doubleValue = Double(newValue) {
                        value = doubleValue
                    }
                }
            ))
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
        }
    }
}

// MARK: - API Key Field

/// APIキー入力用のセキュアフィールド
public struct APIKeyField: View {
    public let title: String
    public let placeholder: String
    @Binding public var text: String
    public let hasKey: Bool

    public init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        hasKey: Bool
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.hasKey = hasKey
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)

                Spacer()

                if hasKey {
                    Label("設定済み", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            SecureField(placeholder, text: $text)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - Error Banner

/// エラーを表示するバナー
public struct ErrorBanner: View {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("エラー", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Execution Log View

/// 実行ログを表示するビュー
public struct ExecutionLogView: View {
    public let logs: [String]

    public init(logs: [String]) {
        self.logs = logs
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("実行ログ")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(logs, id: \.self) { log in
                    Text(log)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Date Formatter

public extension DateFormatter {
    /// ログ用のタイムスタンプフォーマッター（HH:mm:ss）
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
