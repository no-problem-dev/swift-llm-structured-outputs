import SwiftUI

/// AIからの質問を表示するバナー
struct QuestionBanner: View {
    let question: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.title2)
                .foregroundStyle(.indigo)

            VStack(alignment: .leading, spacing: 4) {
                Text("AIからの質問")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.indigo)

                Text(question)
                    .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.indigo.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.indigo.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
