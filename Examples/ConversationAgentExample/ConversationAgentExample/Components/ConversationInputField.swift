import SwiftUI

struct ConversationInputField: View {
    enum Mode {
        case prompt
        case interrupt
        case answer
    }

    let mode: Mode
    @Binding var text: String
    let isEnabled: Bool
    let onSubmit: () -> Void
    var onStop: (() -> Void)?

    var body: some View {
        HStack {
            if mode == .interrupt, let onStop {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)

            Button(action: onSubmit) {
                Image(systemName: iconName)
            }
            .buttonStyle(.borderedProminent)
            .tint(tintColor)
            .disabled(!isEnabled || text.isEmpty)
        }
    }

    private var placeholder: String {
        switch mode {
        case .prompt: return "質問を入力..."
        case .interrupt: return "割り込みメッセージを入力..."
        case .answer: return "回答を入力..."
        }
    }

    private var iconName: String {
        switch mode {
        case .prompt: return "paperplane.fill"
        case .interrupt: return "bolt.fill"
        case .answer: return "arrowshape.turn.up.right.fill"
        }
    }

    private var tintColor: Color {
        switch mode {
        case .prompt: return .accentColor
        case .interrupt: return .orange
        case .answer: return .indigo
        }
    }
}
