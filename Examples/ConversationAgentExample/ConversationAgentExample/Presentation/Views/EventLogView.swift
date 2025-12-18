import SwiftUI

/// イベントログビュー
///
/// セッションのイベントストリームを表示します。
struct EventLogView: View {
    let events: [ConversationStepInfo]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(events) { event in
                        EventRow(event: event)
                            .id(event.id)
                    }
                }
                .padding()
            }
            .onChange(of: events.count) { _, _ in
                if let lastEvent = events.last {
                    withAnimation {
                        proxy.scrollTo(lastEvent.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

/// イベント行
struct EventRow: View {
    let event: ConversationStepInfo

    var body: some View {
        HStack(spacing: 8) {
            Text(event.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 60, alignment: .leading)

            Text(event.content)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    EventLogView(events: [
        .init(type: .event, content: "セッションが作成されました"),
        .init(type: .event, content: "セッションが開始されました"),
        .init(type: .event, content: "ユーザーメッセージが追加されました"),
        .init(type: .event, content: "アシスタントメッセージが追加されました"),
        .init(type: .event, content: "セッションが完了しました")
    ])
}
