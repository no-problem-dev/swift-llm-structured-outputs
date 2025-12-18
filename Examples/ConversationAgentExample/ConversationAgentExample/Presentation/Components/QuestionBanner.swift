import SwiftUI

struct QuestionBanner: View {
    let question: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.bubble.fill")
                    .foregroundStyle(.indigo)
                Text("AI からの質問")
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
            }
            Text(question)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.indigo.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
