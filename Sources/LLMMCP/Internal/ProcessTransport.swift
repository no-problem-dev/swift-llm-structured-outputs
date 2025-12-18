#if os(macOS)
import Foundation
import Logging
import MCP

/// 外部プロセスを起動してstdin/stdout経由で通信するトランスポート
///
/// MCPサーバープロセスを起動し、JSON-RPC通信を行います。
/// SDKの`StdioTransport`とは異なり、このトランスポートは
/// 外部プロセスを起動する側として動作します。
internal actor ProcessTransport: Transport {
    // MARK: - Properties

    public nonisolated let logger: Logger

    private let command: String
    private let arguments: [String]
    private let environment: [String: String]

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    private var isConnected = false
    private let messageStream: AsyncThrowingStream<Data, Swift.Error>
    private let messageContinuation: AsyncThrowingStream<Data, Swift.Error>.Continuation

    // MARK: - Initialization

    /// ProcessTransportを作成
    ///
    /// - Parameters:
    ///   - command: 実行するコマンドのパス
    ///   - arguments: コマンド引数
    ///   - environment: 追加の環境変数
    ///   - logger: ロガー
    init(
        command: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        logger: Logger? = nil
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.logger = logger ?? Logger(
            label: "mcp.transport.process",
            factory: { _ in SwiftLogNoOpLogHandler() }
        )

        // メッセージストリームを作成
        var continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation!
        self.messageStream = AsyncThrowingStream { continuation = $0 }
        self.messageContinuation = continuation
    }

    // MARK: - Transport Protocol

    /// プロセスを起動して接続を確立
    public func connect() async throws {
        guard !isConnected else { return }

        logger.debug("Starting MCP server process", metadata: [
            "command": "\(command)",
            "arguments": "\(arguments)"
        ])

        // パイプを作成
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        // プロセスを設定
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // 環境変数を設定
        var processEnvironment = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            processEnvironment[key] = value
        }
        process.environment = processEnvironment

        self.process = process

        // プロセスを起動
        do {
            try process.run()
            isConnected = true
            logger.debug("MCP server process started", metadata: ["pid": "\(process.processIdentifier)"])
        } catch {
            logger.error("Failed to start MCP server process", metadata: ["error": "\(error)"])
            throw MCP.MCPError.transportError(error)
        }

        // stderrを監視（デバッグ用）
        Task {
            await monitorStderr()
        }

        // stdoutからメッセージを読み取るループを開始
        Task {
            await readLoop()
        }
    }

    /// 接続を切断してプロセスを終了
    public func disconnect() async {
        guard isConnected else { return }
        isConnected = false

        logger.debug("Disconnecting MCP server process")

        // ストリームを終了
        messageContinuation.finish()

        // パイプを閉じる
        stdinPipe?.fileHandleForWriting.closeFile()
        stdoutPipe?.fileHandleForReading.closeFile()
        stderrPipe?.fileHandleForReading.closeFile()

        // プロセスを終了
        if let process = process, process.isRunning {
            process.terminate()
            // 少し待ってからkill
            try? await Task.sleep(for: .milliseconds(100))
            if process.isRunning {
                process.interrupt()
            }
        }

        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil

        logger.debug("MCP server process disconnected")
    }

    /// データを送信
    public func send(_ data: Data) async throws {
        guard isConnected else {
            throw MCP.MCPError.internalError("Transport not connected")
        }

        guard let stdinPipe = stdinPipe else {
            throw MCP.MCPError.internalError("stdin pipe not available")
        }

        // 改行を追加してJSON-RPCメッセージを区切る
        var messageData = data
        messageData.append(UInt8(ascii: "\n"))

        logger.trace("Sending message", metadata: ["size": "\(data.count)"])

        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: messageData)
        } catch {
            logger.error("Failed to send message", metadata: ["error": "\(error)"])
            throw MCP.MCPError.transportError(error)
        }
    }

    /// 受信メッセージのストリームを取得
    public func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        return messageStream
    }

    // MARK: - Private Methods

    /// stdoutからメッセージを読み取るループ
    private func readLoop() async {
        guard let stdoutPipe = stdoutPipe else { return }

        let fileHandle = stdoutPipe.fileHandleForReading
        var pendingData = Data()

        while isConnected && !Task.isCancelled {
            do {
                // availableDataを使用して非同期的に読み取る
                let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                    // FileHandleの読み取りをバックグラウンドで実行
                    DispatchQueue.global().async {
                        let data = fileHandle.availableData
                        continuation.resume(returning: data)
                    }
                }

                if data.isEmpty {
                    // EOF - プロセスが終了
                    logger.notice("EOF received from MCP server process")
                    break
                }

                pendingData.append(data)

                // 改行で区切られた完全なメッセージを処理
                while let newlineIndex = pendingData.firstIndex(of: UInt8(ascii: "\n")) {
                    let messageData = pendingData[..<newlineIndex]
                    pendingData = pendingData[(newlineIndex + 1)...]

                    if !messageData.isEmpty {
                        logger.trace("Message received", metadata: ["size": "\(messageData.count)"])
                        messageContinuation.yield(Data(messageData))
                    }
                }
            } catch {
                if !Task.isCancelled {
                    logger.error("Read error occurred", metadata: ["error": "\(error)"])
                }
                break
            }
        }

        messageContinuation.finish()
    }

    /// stderrを監視してログに出力
    private func monitorStderr() async {
        guard let stderrPipe = stderrPipe else { return }

        let fileHandle = stderrPipe.fileHandleForReading

        while isConnected && !Task.isCancelled {
            let data = fileHandle.availableData
            if data.isEmpty { break }

            if let message = String(data: data, encoding: .utf8) {
                logger.debug("MCP server stderr", metadata: ["message": "\(message.trimmingCharacters(in: .whitespacesAndNewlines))"])
            }
        }
    }
}
#endif
