import SwiftUI

struct APIKeyStatusBar: View {
    let hasLLMKey: Bool
    let hasSearchKey: Bool

    var body: some View {
        if !hasLLMKey || !hasSearchKey {
            HStack {
                Spacer()

                if !hasLLMKey {
                    Label("APIキーが未設定", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !hasSearchKey {
                    Label("検索APIが未設定", systemImage: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
