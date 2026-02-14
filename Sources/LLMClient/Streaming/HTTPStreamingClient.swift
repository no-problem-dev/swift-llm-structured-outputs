import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - HTTPStreamingClient

/// HTTP ストリーミングレスポンスを Data チャンクの AsyncThrowingStream として提供
///
/// プラットフォームに応じて実装を切り替える:
/// - Apple (Darwin): `URLSession.bytes(for:)` ベース
/// - Linux: `URLSessionDataDelegate` ベース
internal enum HTTPStreamingClient {

    /// HTTP リクエストを送信し、レスポンスボディを Data チャンクのストリームとして返す
    ///
    /// - Parameters:
    ///   - request: 送信する URLRequest
    ///   - session: 使用する URLSession（Apple プラットフォームのみ）
    /// - Returns: Data チャンクの AsyncThrowingStream
    static func stream(
        request: URLRequest,
        session: URLSession = .shared
    ) -> AsyncThrowingStream<Data, Error> {
        #if canImport(Darwin)
        return streamWithURLSessionBytes(request: request, session: session)
        #else
        return streamWithDelegate(request: request)
        #endif
    }

    // MARK: - Apple Platform (URLSession.bytes)

    #if canImport(Darwin)
    private static func streamWithURLSessionBytes(
        request: URLRequest,
        session: URLSession
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: LLMError.invalidRequest("Invalid response type"))
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        // エラーレスポンスのボディを収集
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                        }
                        let error = Self.handleErrorStatus(
                            statusCode: httpResponse.statusCode,
                            data: errorData
                        )
                        continuation.finish(throwing: error)
                        return
                    }

                    // バイトストリームを Data チャンクに変換
                    // URLSession.bytes は 1 バイトずつ返すため、
                    // 改行で区切ってチャンク化する
                    var lineBuffer = Data()
                    for try await byte in bytes {
                        lineBuffer.append(byte)
                        // 改行を検出したら行データを yield
                        if byte == UInt8(ascii: "\n") {
                            continuation.yield(lineBuffer)
                            lineBuffer = Data()
                        }
                    }
                    // 残りのバッファを flush
                    if !lineBuffer.isEmpty {
                        continuation.yield(lineBuffer)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    #endif

    // MARK: - Linux Platform (URLSessionDataDelegate)

    #if !canImport(Darwin)
    private static func streamWithDelegate(
        request: URLRequest
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let delegate = StreamingSessionDelegate(continuation: continuation)
            let session = URLSession(
                configuration: .default,
                delegate: delegate,
                delegateQueue: nil
            )
            let task = session.dataTask(with: request)
            delegate.task = task
            task.resume()

            continuation.onTermination = { _ in
                task.cancel()
                session.invalidateAndCancel()
            }
        }
    }

    /// URLSessionDataDelegate を使用してデータチャンクを AsyncThrowingStream に中継
    private final class StreamingSessionDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        private let continuation: AsyncThrowingStream<Data, Error>.Continuation
        var task: URLSessionDataTask?
        private var httpResponse: HTTPURLResponse?
        private var errorData = Data()
        private var isError = false

        init(continuation: AsyncThrowingStream<Data, Error>.Continuation) {
            self.continuation = continuation
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive response: URLResponse,
            completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
        ) {
            if let httpResponse = response as? HTTPURLResponse {
                self.httpResponse = httpResponse
                if httpResponse.statusCode != 200 {
                    isError = true
                }
            }
            completionHandler(.allow)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            if isError {
                errorData.append(data)
            } else {
                continuation.yield(data)
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                continuation.finish(throwing: LLMError.networkError(error))
            } else if isError, let httpResponse = httpResponse {
                let llmError = HTTPStreamingClient.handleErrorStatus(
                    statusCode: httpResponse.statusCode,
                    data: errorData
                )
                continuation.finish(throwing: llmError)
            } else {
                continuation.finish()
            }
            session.invalidateAndCancel()
        }
    }
    #endif

    // MARK: - Error Handling

    /// HTTP エラーステータスコードを LLMError に変換
    fileprivate static func handleErrorStatus(statusCode: Int, data: Data) -> LLMError {
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        switch statusCode {
        case 401:
            return .unauthorized
        case 429:
            return .rateLimitExceeded
        case 400:
            return .invalidRequest(errorMessage)
        case 404:
            return .modelNotFound(errorMessage)
        case 500...599:
            return .serverError(statusCode, errorMessage)
        default:
            return .serverError(statusCode, "Unexpected status code: \(statusCode)")
        }
    }
}
