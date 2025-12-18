# 組み込みToolKit

公式MCPサーバーと同等の機能を提供するSwiftネイティブのToolKit実装。

## 概要

組み込みToolKitは、外部MCPサーバーを必要とせず、Swift内で直接利用できるツールセットです。
公式MCP Memory Server、Filesystem Serverなどと同等のAPIを提供しつつ、
セキュリティとプラットフォーム最適化を実現しています。

### 利用可能なToolKit

| ToolKit | 説明 | ツール数 | プラットフォーム |
|---------|------|---------|-----------------|
| ``MemoryToolKit`` | ナレッジグラフベースの永続メモリ | 9 | iOS / macOS |
| ``FileSystemToolKit`` | ファイルシステム操作 | 9 | iOS / macOS |
| ``WebToolKit`` | Webコンテンツ取得 | 3 | iOS / macOS |
| ``UtilityToolKit`` | 汎用ユーティリティ | 4 | iOS / macOS |

## MemoryToolKit

ナレッジグラフベースの永続メモリシステムを提供します。
エンティティ、リレーション、観察を管理し、エージェントに長期記憶を付与できます。

### 初期化

```swift
// メモリのみ（セッション終了で消失）
let memory = MemoryToolKit()

// ファイルに永続化
let persistentMemory = MemoryToolKit(
    persistencePath: "~/agent_memory.jsonl"
)
```

### 提供ツール

| ツール名 | 説明 | アノテーション |
|----------|------|--------------|
| `create_entities` | 新しいエンティティを作成 | 冪等書き込み |
| `create_relations` | エンティティ間のリレーションを作成 | 冪等書き込み |
| `add_observations` | 既存エンティティに観察を追加 | 冪等書き込み |
| `delete_entities` | エンティティを削除（関連リレーションも削除） | 破壊的 |
| `delete_observations` | 特定の観察を削除 | 破壊的 |
| `delete_relations` | 特定のリレーションを削除 | 破壊的 |
| `read_graph` | ナレッジグラフ全体を取得 | 読み取り専用 |
| `search_nodes` | ノードをクエリで検索 | 読み取り専用 |
| `open_nodes` | 特定のノードを名前で取得 | 読み取り専用 |

### 使用例

```swift
import LLMStructuredOutputs

let tools = ToolSet {
    MemoryToolKit(persistencePath: "~/memory.jsonl")
}

let client = AnthropicClient(apiKey: "sk-ant-...")

for try await step in client.runAgent(
    prompt: "田中さんは営業部で働いていて、鈴木さんの上司です。これを覚えてください。",
    model: .sonnet,
    tools: tools,
    systemPrompt: "ユーザーの情報をメモリに保存し、必要に応じて参照してください。"
) {
    // エージェントが create_entities, create_relations を自動的に呼び出す
}
```

### ナレッジグラフ構造

```
エンティティ (Entity)
├── name: 一意の識別子
├── entityType: エンティティの種類（person, organization, etc.）
└── observations: エンティティに関する観察のリスト

リレーション (Relation)
├── from: ソースエンティティ名
├── to: ターゲットエンティティ名
└── relationType: 関係の種類（能動態で記述）
```

## FileSystemToolKit

ファイルシステム操作を提供します。セキュリティのため、指定したパス内のみアクセス可能です。

### 初期化

```swift
// 許可するパスを指定（必須）
let fs = FileSystemToolKit(allowedPaths: [
    "/Users/user/projects",
    "/tmp",
    "~/Documents"  // チルダは自動展開
])
```

### 提供ツール

| ツール名 | 説明 | アノテーション |
|----------|------|--------------|
| `read_file` | ファイルを読み取り | 読み取り専用 |
| `read_multiple_files` | 複数ファイルを一括読み取り | 読み取り専用 |
| `write_file` | ファイルを作成/上書き | 冪等書き込み |
| `create_directory` | ディレクトリを作成 | 冪等書き込み |
| `list_directory` | ディレクトリ内容を一覧 | 読み取り専用 |
| `directory_tree` | ディレクトリツリーを表示 | 読み取り専用 |
| `move_file` | ファイルを移動/名前変更 | 破壊的 |
| `search_files` | パターンでファイルを検索 | 読み取り専用 |
| `get_file_info` | ファイル情報を取得 | 読み取り専用 |

### 使用例

```swift
let tools = ToolSet {
    FileSystemToolKit(allowedPaths: [
        NSHomeDirectory() + "/Documents"
    ])
}

for try await step in client.runAgent(
    prompt: "Documentsフォルダ内の.txtファイルを一覧して内容を要約して",
    model: .sonnet,
    tools: tools
) {
    // エージェントが list_directory, read_file を自動的に呼び出す
}
```

### セキュリティ

- 許可されたパス外へのアクセスは拒否されます
- シンボリックリンクを辿って許可パス外に出ることも防止されます
- パス検証は正規化後に行われます

## WebToolKit

Webからコンテンツを取得するツールを提供します。

### 初期化

```swift
// すべてのドメインを許可（注意: セキュリティリスクあり）
let web = WebToolKit()

// 特定のドメインのみ許可（推奨）
let restrictedWeb = WebToolKit(
    allowedDomains: ["api.github.com", "example.com"]
)

// カスタム設定
let customWeb = WebToolKit(
    allowedDomains: ["api.example.com"],
    timeout: 30,
    maxContentSize: 5 * 1024 * 1024  // 5MB
)
```

### 提供ツール

| ツール名 | 説明 | アノテーション |
|----------|------|--------------|
| `fetch_url` | URLからコンテンツを取得 | 読み取り専用 |
| `fetch_json` | URLからJSONを取得・パース | 読み取り専用 |
| `fetch_headers` | HTTPヘッダーのみを取得 | 読み取り専用 |

### 使用例

```swift
let tools = ToolSet {
    WebToolKit(allowedDomains: ["api.github.com"])
}

for try await step in client.runAgent(
    prompt: "GitHub APIでoctocat/Hello-Worldリポジトリの情報を取得して",
    model: .sonnet,
    tools: tools
) {
    // エージェントが fetch_json を自動的に呼び出す
}
```

### セキュリティ

- HTTPとHTTPSのみサポート（file://等は拒否）
- ドメイン制限を推奨
- 最大コンテンツサイズ制限あり

## UtilityToolKit

汎用的なユーティリティ機能を提供します。

### 初期化

```swift
// デフォルト設定（ローカルタイムゾーン）
let utility = UtilityToolKit()

// タイムゾーン指定
let utcUtility = UtilityToolKit(timeZone: TimeZone(identifier: "UTC")!)
```

### 提供ツール

| ツール名 | 説明 | アノテーション |
|----------|------|--------------|
| `get_current_time` | 現在時刻を取得（フォーマット・タイムゾーン指定可） | 読み取り専用 |
| `calculate` | 基本的な数学計算（+, -, *, /, %, ^, sqrt） | 読み取り専用 |
| `generate_uuid` | ランダムなUUID v4を生成 | 読み取り専用 |
| `sleep` | 指定時間待機（最大60秒） | 読み取り専用 |

### 使用例

```swift
let tools = ToolSet {
    UtilityToolKit()
    MemoryToolKit()
}

for try await step in client.runAgent(
    prompt: "現在のUTC時刻を取得してメモリに保存して",
    model: .sonnet,
    tools: tools
) {
    // エージェントが get_current_time, create_entities を呼び出す
}
```

## ToolKitの組み合わせ

複数のToolKitを組み合わせて強力なエージェントを構築できます。

```swift
let tools = ToolSet {
    // メモリ管理
    MemoryToolKit(persistencePath: "~/agent_memory.jsonl")

    // ファイル操作
    FileSystemToolKit(allowedPaths: [
        NSHomeDirectory() + "/Documents",
        NSHomeDirectory() + "/Downloads"
    ])

    // Web取得
    WebToolKit(allowedDomains: [
        "api.github.com",
        "api.openweathermap.org"
    ])

    // ユーティリティ
    UtilityToolKit()

    // @Tool マクロで定義した個別ツールも追加可能
    CustomSearchTool()
}
```

## カスタムToolKitの作成

独自のToolKitを作成することもできます。

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
            // データベースクエリを実行
            let input = try JSONDecoder().decode(QueryInput.self, from: data)
            let result = try executeQuery(connectionString, input.sql)
            return .json(try JSONEncoder().encode(result))
        }
    }

    private var insertTool: BuiltInTool {
        // 書き込み操作...
    }
}
```

## ToolAnnotations

ツールの特性を示すアノテーションを指定できます。

### プリセット

```swift
// 読み取り専用（データを変更しない）
annotations: .readOnly

// 破壊的操作（データを削除・変更する）
annotations: .destructive

// 冪等な書き込み（同じ入力で同じ結果）
annotations: .idempotentWrite

// クローズドワールド（外部と通信しない）
annotations: .closedWorld
```

### カスタム設定

```swift
annotations: ToolAnnotations(
    title: "Query Database",
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false
)
```

### アノテーションの意味

| プロパティ | 説明 | デフォルト |
|-----------|------|----------|
| `readOnlyHint` | 環境を変更しない | `false` |
| `destructiveHint` | 破壊的な更新を行う可能性がある | `true` |
| `idempotentHint` | 同じ引数での繰り返し呼び出しは追加の効果を持たない | `false` |
| `openWorldHint` | 外部エンティティと対話する可能性がある | `true` |

## 関連項目

- <doc:MCPServerGuide>
- ``ToolKit``
- ``BuiltInTool``
- ``ToolAnnotations``
