# ``LLMMCP``

MCP（Model Context Protocol）サーバーおよび組み込みToolKitの統合モジュール。

## 概要

LLMMCP は、外部 MCP サーバーへの接続と、MCP サーバーと同等の機能を提供する Swift ネイティブ ToolKit を統合するモジュールです。エージェントが利用できるツールを大幅に拡張します。

### 主な機能

- **MCPサーバー統合** - 外部 MCP サーバーに接続し、ツールを動的に取得・実行
- **組み込みToolKit** - ファイルシステム、メモリ、Web、ユーティリティなどの標準機能
- **柔軟な認証** - OAuth 2.1 Bearer トークン、カスタムヘッダー認証をサポート
- **ツール選択** - 読み取り専用、安全なツールのみ、特定ツールの包含/除外

### 設計原則

- **MCP仕様準拠**: Model Context Protocol 仕様に従ったツール定義・実行
- **プラットフォーム適応**: macOS では stdio、iOS/macOS 共通で HTTP トランスポート
- **セキュリティ重視**: 許可パス、許可ドメインによるサンドボックス設計

## クイックスタート

### 外部MCPサーバーの利用

```swift
import LLMStructuredOutputs

#if os(macOS)
// stdio接続（macOSのみ）
let tools = ToolSet {
    MCPServer(command: "npx", arguments: ["-y", "@anthropic/mcp-server-filesystem", "/path"])
        .readOnly
}
#endif

// HTTP接続（iOS/macOS）
let httpTools = ToolSet {
    MCPServer(url: URL(string: "https://example.com/mcp")!)
        .excluding("dangerous_tool")
}
```

### 組み込みToolKitの利用

```swift
let tools = ToolSet {
    // メモリ管理（ナレッジグラフ）
    MemoryToolKit(persistencePath: "~/memory.jsonl")

    // ファイルシステム操作
    FileSystemToolKit(allowedPaths: ["/Users/user/Documents"])

    // Web コンテンツ取得
    WebToolKit(allowedDomains: ["api.github.com"])

    // ユーティリティ
    UtilityToolKit()
}
```

### 認証付きMCPサーバー

```swift
// Notion MCP（プリセット）
let notion = MCPServer.notion(token: "ntn_xxxxx")

// カスタム認証
let customServer = MCPServer(
    url: URL(string: "https://mcp.example.com")!,
    authorization: .bearer("your-access-token")
)

let tools = ToolSet {
    notion
    customServer
}
```

### エージェントでの使用

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")

for try await step in client.runAgent(
    prompt: "ドキュメントフォルダ内のファイル一覧を見せて",
    model: .sonnet,
    tools: tools
) {
    switch step {
    case .toolCall(let call):
        print("🔧 ツール: \(call.name)")
    case .toolResult(let result):
        print("📄 結果: \(result.output)")
    case .finalResponse(let output):
        print("✅ 完了: \(output)")
    default:
        break
    }
}
```

## Topics

### 基本ガイド

- <doc:BuiltInToolKits>
- <doc:MCPServerGuide>

### MCPサーバー

- ``MCPServer``
- ``MCPServerProtocol``
- ``MCPConfiguration``
- ``MCPTransport``
- ``MCPAuthorization``
- ``MCPToolSelection``
- ``MCPToolCapabilities``

### 組み込みToolKit

- ``ToolKit``
- ``MemoryToolKit``
- ``FileSystemToolKit``
- ``WebToolKit``
- ``UtilityToolKit``
- ``BuiltInTool``
- ``ToolAnnotations``

### MCPツール

- ``MCPTool``
