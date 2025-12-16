import SwiftUI
import MarkdownUI

struct ResultSheet: View {
    let result: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                Markdown(result)
                    .markdownTheme(.gitHub)
                    .padding()
            }
            .navigationTitle("リサーチ結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: onDismiss)
                }
                ToolbarItem(placement: .cancellationAction) {
                    ShareLink(item: result) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
