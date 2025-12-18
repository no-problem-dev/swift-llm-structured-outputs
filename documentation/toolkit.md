# ToolKit

`ToolKit` は関連する複数のツールをグループ化して提供するためのプロトコルです。`@Tool` マクロで個別にツールを定義する代わりに、ToolKit を使用することで、まとまった機能セットを簡単に追加できます。

## 概要

`@Tool` マクロとの違い:

| 方式 | 特徴 |
|------|------|
| `@Tool` マクロ | 個別ツールを定義、型安全な引数 |
| `ToolKit` | 複数ツールをグループ化、設定可能、再利用性が高い |

## 組み込み ToolKit

以下の ToolKit が標準で提供されています:

| ToolKit | 説明 | 提供ツール数 |
|---------|------|-------------|
| `MemoryToolKit` | ナレッジグラフベースの永続メモリ | 9 |
| `FileSystemToolKit` | ファイルシステム操作 | 9 |
| `WebToolKit` | Web コンテンツ取得 | 3 |
| `UtilityToolKit` | 汎用ユーティリティ | 4 |

## 基本的な使い方

### 1. ToolKit を ToolSet に追加

```swift
import LLMStructuredOutputs

let tools = ToolSet {
    // 組み込み ToolKit
    MemoryToolKit()
    UtilityToolKit()

    // 個別ツールと併用可能
    GetWeather()
}
```

### 2. エージェントで使用

```swift
let client = AnthropicClient(apiKey: "sk-ant-...")

for try await step in client.runAgent(
    prompt: "現在時刻を教えて、メモリに保存して",
    model: .sonnet,
    tools: tools
) {
    // ...
}
```

## MemoryToolKit

ナレッジグラフベースのメモリシステムを提供します。エンティティ、リレーション、観察を管理できます。

### 初期化

```swift
// メモリのみ（セッション終了時に消える）
let memory = MemoryToolKit()

// ファイルに永続化（アプリ再起動後も保持）
let persistentMemory = MemoryToolKit(persistencePath: "~/memory.jsonl")
```

### 提供ツール

| ツール名 | 説明 |
|----------|------|
| `create_entities` | 新しいエンティティを作成 |
| `create_relations` | エンティティ間のリレーションを作成 |
| `add_observations` | 既存エンティティに観察を追加 |
| `delete_entities` | エンティティを削除（関連リレーションも削除） |
| `delete_observations` | 特定の観察を削除 |
| `delete_relations` | 特定のリレーションを削除 |
| `read_graph` | ナレッジグラフ全体を取得 |
| `search_nodes` | ノードを検索 |
| `open_nodes` | 特定のノードを名前で取得 |

### 使用例

```swift
let tools = ToolSet {
    MemoryToolKit(persistencePath: "~/agent_memory.jsonl")
}

// エージェントが自動的にメモリを活用
for try await step in client.runAgent(
    prompt: "田中さんは営業部で働いていて、鈴木さんの上司です。これを覚えて。",
    model: .sonnet,
    tools: tools,
    systemPrompt: "ユーザーの情報をメモリに保存し、必要に応じて参照してください。"
) {
    // ...
}
```

## FileSystemToolKit

ファイルシステム操作を提供します。セキュリティのため、許可されたパス内のみアクセス可能です。

### 初期化

```swift
// 許可するパスを指定
let fs = FileSystemToolKit(allowedPaths: [
    "/Users/user/projects",
    "/tmp"
])
```

### 提供ツール

| ツール名 | 説明 |
|----------|------|
| `read_file` | ファイルを読み取り |
| `read_multiple_files` | 複数ファイルを一括読み取り |
| `write_file` | ファイルを作成/上書き |
| `create_directory` | ディレクトリを作成 |
| `list_directory` | ディレクトリ内容を一覧 |
| `directory_tree` | ディレクトリツリーを表示 |
| `move_file` | ファイルを移動/名前変更 |
| `search_files` | パターンでファイルを検索 |
| `get_file_info` | ファイル情報を取得 |

### 使用例

```swift
let tools = ToolSet {
    FileSystemToolKit(allowedPaths: [NSHomeDirectory() + "/Documents"])
}

for try await step in client.runAgent(
    prompt: "Documents フォルダ内の .txt ファイルを一覧して",
    model: .sonnet,
    tools: tools
) {
    // ...
}
```

## WebToolKit

Web コンテンツの取得を提供します。セキュリティのため、許可されたドメインのみアクセス可能です。

### 初期化

```swift
// 許可するドメインを指定
let web = WebToolKit(allowedDomains: [
    "api.github.com",
    "example.com"
])

// カスタム設定
let customWeb = WebToolKit(
    allowedDomains: ["api.example.com"],
    timeout: 30,
    maxContentSize: 5 * 1024 * 1024  // 5MB
)
```

### 提供ツール

| ツール名 | 説明 |
|----------|------|
| `fetch_url` | URL からコンテンツを取得 |
| `fetch_json` | URL から JSON を取得・パース |
| `fetch_headers` | HTTP ヘッダーのみを取得 |

### 使用例

```swift
let tools = ToolSet {
    WebToolKit(allowedDomains: ["api.github.com"])
}

for try await step in client.runAgent(
    prompt: "GitHub API でユーザー情報を取得して",
    model: .sonnet,
    tools: tools
) {
    // ...
}
```

## UtilityToolKit

汎用ユーティリティ機能を提供します。

### 初期化

```swift
let utility = UtilityToolKit()
```

### 提供ツール

| ツール名 | 説明 |
|----------|------|
| `get_current_time` | 現在時刻を取得（フォーマット・タイムゾーン指定可） |
| `calculate` | 基本的な数学計算 |
| `generate_uuid` | UUID を生成 |
| `sleep` | 指定時間待機 |

## 複数 ToolKit の組み合わせ

```swift
let tools = ToolSet {
    // 複数の ToolKit を組み合わせ
    MemoryToolKit(persistencePath: "~/memory.jsonl")
    FileSystemToolKit(allowedPaths: ["/Users/user/projects"])
    WebToolKit(allowedDomains: ["api.example.com"])
    UtilityToolKit()

    // 個別の @Tool も追加可能
    GetWeather()
    SendEmail()
}
```

## カスタム ToolKit の作成

独自の ToolKit を作成することもできます:

```swift
public struct DatabaseToolKit: ToolKit {
    public let name: String = "database"

    private let connectionString: String

    public init(connectionString: String) {
        self.connectionString = connectionString
    }

    public var tools: [any Tool] {
        [queryTool, insertTool]
    }

    private var queryTool: BuiltInTool {
        BuiltInTool(
            name: "query_database",
            description: "Execute a SELECT query",
            inputSchema: .object(
                properties: [
                    "sql": .string(description: "SQL query to execute")
                ],
                required: ["sql"]
            ),
            annotations: .readOnly
        ) { [connectionString] data in
            let input = try JSONDecoder().decode(QueryInput.self, from: data)
            // データベースクエリを実行
            let result = try executeQuery(connectionString, input.sql)
            return .json(try JSONEncoder().encode(result))
        }
    }

    private var insertTool: BuiltInTool {
        // ...
    }
}
```

## ToolAnnotations

ツールの特性を `ToolAnnotations` で指定できます:

```swift
// 読み取り専用（データを変更しない）
annotations: .readOnly

// 破壊的操作（データを削除・変更する）
annotations: .destructive

// 冪等な書き込み（同じ入力で同じ結果）
annotations: .idempotentWrite

// カスタム設定
annotations: ToolAnnotations(
    title: "Query Database",
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false
)
```

## プラットフォーム対応

| ToolKit | iOS | macOS |
|---------|-----|-------|
| MemoryToolKit | ✅ | ✅ |
| FileSystemToolKit | ✅ | ✅ |
| WebToolKit | ✅ | ✅ |
| UtilityToolKit | ✅ | ✅ |

すべての組み込み ToolKit は iOS と macOS の両方で動作します。

## 次のステップ

- [ツールコール](tool-calling.md) で `@Tool` マクロを使った個別ツール定義を確認
- [MCPサーバー統合](mcp-integration.md) で外部 MCP サーバーとの接続を確認
- [エージェントループ](agent-loop.md) でエージェント実行の詳細を確認
