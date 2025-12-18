import SwiftUI

/// セッション再開バナー
///
/// 停止中のセッションを再開するためのバナーコンポーネント。
/// 会話履歴がある状態で停止した場合に表示される。
struct ResumeSessionBanner: View {
    let onResume: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pause.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("セッションが一時停止中です")
                    .font(.subheadline.bold())
                Text("続きから再開できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onResume()
            } label: {
                Label("再開", systemImage: "play.fill")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ResumeSessionBanner(onResume: {})
        .padding()
}
