# MCPサーバー統合ガイド

外部MCPサーバーへの接続と認証設定。

## 概要

``MCPServer`` は、Model Context Protocol（MCP）に準拠した外部サーバーに接続し、
ツールを動的に取得・実行する機能を提供します。
macOSではstdio接続、iOS/macOS共通でHTTP接続をサポートします。

## トランスポート

MCPは2種類のトランスポートをサポートしています。

### stdio（macOSのみ）

ローカルで実行されるMCPサーバーに標準入出力経由で接続します。

```swift
#if os(macOS)
let tools = ToolSet {
    MCPServer(
        command: "npx",
        arguments: ["-y", "@anthropic/mcp-server-filesystem", "/path/to/dir"]
    )
}
#endif
```

**利点**:
- ローカル実行で低レイテンシ
- ネットワーク不要
- 認証設定が不要

**制限**:
- macOSのみ（iOSでは利用不可）
- Node.js等の実行環境が必要

### HTTP（Streamable HTTP）

リモートまたはローカルのMCPサーバーにHTTP経由で接続します。

```swift
let tools = ToolSet {
    MCPServer(
        url: URL(string: "https://example.com/mcp")!
    )
}
```

**利点**:
- iOS/macOS両方で利用可能
- リモートサーバーに接続可能
- 認証によるアクセス制御

**制限**:
- ネットワーク接続が必要
- レイテンシが発生する可能性

## 認証

HTTPトランスポートでは、様々な認証方式をサポートしています。

### Bearer トークン（OAuth 2.1）

最も一般的な認証方式です。

```swift
let server = MCPServer(
    url: URL(string: "https://mcp.example.com")!,
    authorization: .bearer("your-access-token")
)
```

### カスタムヘッダー

APIキーなど、カスタムヘッダーによる認証に対応。

```swift
// 単一ヘッダー
let server = MCPServer(
    url: url,
    authorization: .header("X-API-Key", "your-api-key")
)

// 複数ヘッダー
let server = MCPServer(
    url: url,
    authorization: .headers([
        "X-API-Key": "your-api-key",
        "X-Workspace-ID": "workspace-123"
    ])
)
```

### 認証なし

公開サーバーや内部ネットワークのサーバー用。

```swift
let server = MCPServer(
    url: url,
    authorization: .none  // デフォルト
)
```

## ツール選択

MCPサーバーが提供するすべてのツールを使用するか、フィルタリングできます。

### すべてのツール

```swift
let server = MCPServer(command: "...", arguments: [...])
    .all  // デフォルト
```

### 読み取り専用ツールのみ

```swift
let server = MCPServer(command: "...", arguments: [...])
    .readOnly
```

### 安全なツールのみ（危険な操作を除外）

```swift
let server = MCPServer(command: "...", arguments: [...])
    .safe
```

### 特定ツールのみ含める

```swift
let server = MCPServer(command: "...", arguments: [...])
    .including("read_file", "list_directory")
```

### 特定ツールを除外

```swift
let server = MCPServer(command: "...", arguments: [...])
    .excluding("delete_file", "write_file")
```

## プリセット

よく使用されるMCPサーバーへの接続プリセットを提供しています。

### Notion

Notion公式ホステッドMCPサーバーに接続します。

```swift
let notion = MCPServer.notion(token: "ntn_xxxxx")

let tools = ToolSet {
    notion
}
```

**事前準備**:
1. https://www.notion.so/profile/integrations でインテグレーションを作成
2. インテグレーションシークレット（`ntn_`で始まる）を取得
3. 対象のページ/データベースにインテグレーションを接続

## 使用例

### Filesystem サーバー（macOS）

```swift
#if os(macOS)
import LLMStructuredOutputs

let client = AnthropicClient(apiKey: "sk-ant-...")

let tools = ToolSet {
    MCPServer(
        command: "npx",
        arguments: ["-y", "@anthropic/mcp-server-filesystem", "/Users/user/projects"]
    ).readOnly
}

for try await step in client.runAgent(
    prompt: "プロジェクトフォルダ内のREADME.mdを読んで要約して",
    model: .sonnet,
    tools: tools
) {
    switch step {
    case .toolCall(let call):
        print("🔧 \(call.name)")
    case .finalResponse(let output):
        print("✅ \(output)")
    default:
        break
    }
}
#endif
```

### Brave Search サーバー（macOS）

```swift
#if os(macOS)
let tools = ToolSet {
    MCPServer(
        command: "npx",
        arguments: ["-y", "@anthropic/mcp-server-brave"],
        environment: ["BRAVE_API_KEY": "your-api-key"]
    )
}

for try await step in client.runAgent(
    prompt: "最新のSwift 6の機能について検索して",
    model: .sonnet,
    tools: tools
) {
    // ...
}
#endif
```

### HTTPサーバー（iOS/macOS）

```swift
let tools = ToolSet {
    MCPServer(
        url: URL(string: "https://mcp.example.com")!,
        authorization: .bearer("token")
    )
    .excluding("dangerous_operation")
}

for try await step in client.runAgent(
    prompt: "タスクを実行して",
    model: .sonnet,
    tools: tools
) {
    // ...
}
```

### 複数サーバーの組み合わせ

```swift
let tools = ToolSet {
    // Notion統合
    MCPServer.notion(token: "ntn_xxxxx")

    // カスタムMCPサーバー
    MCPServer(
        url: URL(string: "https://mcp.mycompany.com")!,
        authorization: .bearer("internal-token")
    )

    // 組み込みToolKit
    MemoryToolKit()
    UtilityToolKit()
}
```

## エラーハンドリング

MCPサーバーとの通信で発生する可能性のあるエラー：

```swift
do {
    for try await step in client.runAgent(..., tools: tools) {
        // ...
    }
} catch {
    // MCPサーバー接続エラー
    // タイムアウト
    // 認証失敗
    // ツール実行エラー
    print("Error: \(error)")
}
```

## 設定オプション

### タイムアウト

```swift
let server = MCPServer(
    url: url,
    timeout: 60  // 秒（デフォルト: 30）
)
```

### 環境変数（stdioのみ）

```swift
#if os(macOS)
let server = MCPServer(
    command: "npx",
    arguments: ["-y", "@anthropic/mcp-server-brave"],
    environment: [
        "BRAVE_API_KEY": "your-api-key",
        "LOG_LEVEL": "debug"
    ]
)
#endif
```

### サーバー名

```swift
let server = MCPServer(
    url: url,
    name: "my-custom-server"  // ログ・デバッグ用
)
```

## プラットフォーム考慮事項

| 機能 | iOS | macOS |
|------|-----|-------|
| stdio トランスポート | ❌ | ✅ |
| HTTP トランスポート | ✅ | ✅ |
| Bearer 認証 | ✅ | ✅ |
| カスタムヘッダー認証 | ✅ | ✅ |
| ツール選択 | ✅ | ✅ |

iOSアプリでMCPサーバーを使用する場合は、HTTPトランスポートを使用してください。

## ベストプラクティス

1. **最小権限の原則**: `.readOnly`や`.safe`で不要なツールを制限
2. **タイムアウト設定**: 長時間操作には適切なタイムアウトを設定
3. **エラーハンドリング**: ネットワークエラーや認証エラーに対応
4. **認証情報の管理**: トークンはKeychain等で安全に保管
5. **プラットフォーム対応**: `#if os(macOS)`でstdioを条件付き使用

## 関連項目

- <doc:BuiltInToolKits>
- ``MCPServer``
- ``MCPAuthorization``
- ``MCPToolSelection``
- ``MCPConfiguration``
