import Foundation

// MARK: - SSEEvent (Internal)

/// Server-Sent Events のパース済みイベント
internal struct SSEParsedEvent: Sendable {
    let event: String?
    let data: String
}

// MARK: - SSELineParser

/// Server-Sent Events フォーマットのラインパーサー
///
/// SSE 仕様に従い、`data:` / `event:` 行をパースし、
/// 空行でイベント区切りとして確定する。
internal struct SSELineParser: Sendable {
    private var currentEvent: String?
    private var currentData: [String] = []

    /// 1行を処理し、イベントが確定した場合に返す
    mutating func parseLine(_ line: String) -> SSEParsedEvent? {
        // 空行 = イベント区切り
        if line.isEmpty {
            guard !currentData.isEmpty else { return nil }
            let event = SSEParsedEvent(
                event: currentEvent,
                data: currentData.joined(separator: "\n")
            )
            currentEvent = nil
            currentData = []
            return event
        }

        // コメント行
        if line.hasPrefix(":") {
            return nil
        }

        // フィールドをパース
        if line.hasPrefix("event:") {
            currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            currentData.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
        }
        // id:, retry: は現時点では無視

        return nil
    }
}

// MARK: - DataToLines

/// Data チャンクをバッファリングして行単位に分割するユーティリティ
internal struct DataLineBuffer: Sendable {
    private var buffer = ""

    /// Data チャンクを追加し、完成した行を返す
    mutating func append(_ data: Data) -> [String] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        buffer += text

        var lines: [String] = []
        // \r\n は Swift で1つの Character として扱われるため、先に検索する
        while let newlineRange = buffer.range(of: "\r\n") ?? buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
            lines.append(line)
            buffer = String(buffer[newlineRange.upperBound...])
        }
        return lines
    }
}
