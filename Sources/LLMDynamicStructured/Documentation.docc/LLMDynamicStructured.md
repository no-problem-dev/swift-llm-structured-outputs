# ``LLMDynamicStructured``

ランタイムで構造化出力スキーマを動的に構築するためのモジュール。

@Metadata {
    @PageColor(purple)
}

## 概要

LLMDynamicStructured は、`@Structured` マクロを使わずに、プログラムの実行時に構造化出力の型を定義できるモジュールです。ユーザー入力やデータベースの情報に基づいて、動的にスキーマを構築するユースケースに最適です。

@Row {
    @Column(size: 2) {
        ### 主な特徴

        - **ランタイム定義** - コンパイル時にスキーマを決定する必要がない
        - **Result Builder** - 宣言的な DSL でスキーマを構築
        - **マルチプロバイダー** - Claude, GPT, Gemini すべてに対応
        - **型安全なアクセス** - 結果へのタイプセーフなアクセサ
    }

    @Column {
        ```swift
        let schema = DynamicStructured("UserInfo") {
            JSONSchema.string(description: "名前")
                .named("name")

            JSONSchema.integer(minimum: 0)
                .named("age")
                .optional()
        }
        ```
    }
}

## クイックスタート

### 1. スキーマを定義

```swift
import LLMDynamicStructured

let userInfo = DynamicStructured("UserInfo", description: "ユーザー情報") {
    JSONSchema.string(description: "ユーザー名", minLength: 1)
        .named("name")

    JSONSchema.integer(description: "年齢", minimum: 0, maximum: 150)
        .named("age")
        .optional()

    JSONSchema.enum(["admin", "user", "guest"], description: "権限")
        .named("role")
}
```

### 2. LLM で生成

@TabNavigator {
    @Tab("Claude") {
        ```swift
        let client = AnthropicClient(apiKey: "sk-ant-...")

        let result = try await client.generate(
            prompt: "田中太郎さん（35歳、管理者）の情報を抽出",
            model: .sonnet,
            output: userInfo
        )
        ```
    }

    @Tab("GPT") {
        ```swift
        let client = OpenAIClient(apiKey: "sk-...")

        let result = try await client.generate(
            prompt: "田中太郎さん（35歳、管理者）の情報を抽出",
            model: .gpt4o,
            output: userInfo
        )
        ```
    }

    @Tab("Gemini") {
        ```swift
        let client = GeminiClient(apiKey: "...")

        let result = try await client.generate(
            prompt: "田中太郎さん（35歳、管理者）の情報を抽出",
            model: .flash,
            output: userInfo
        )
        ```
    }
}

### 3. 結果にアクセス

```swift
// 型安全なアクセサ
let name = result.string("name")   // Optional("田中太郎")
let age = result.int("age")        // Optional(35)
let role = result.string("role")   // Optional("admin")

// subscript アクセス
let rawValue = result["name"]      // Any?
```

## ユースケース

LLMDynamicStructured は以下のようなシナリオで活躍します：

- **エージェントビルダー** - ユーザーが UI 上でスキーマを設計
- **動的フォーム** - ユーザー入力に基づくスキーマ生成
- **設定ベース** - JSON/YAML 設定からスキーマを読み込み
- **プラグインシステム** - 外部プラグインが出力形式を定義

## `@Structured` マクロとの比較

| 特徴 | `@Structured` マクロ | `DynamicStructured` |
|------|---------------------|---------------------|
| 定義タイミング | コンパイル時 | ランタイム |
| 型安全性 | 完全（Swift 型） | 部分的（アクセサ経由） |
| 柔軟性 | 固定 | 動的変更可能 |
| ユースケース | 事前定義スキーマ | 動的スキーマ |

## Topics

### 基本

- ``DynamicStructured``
- ``NamedSchema``
- ``StructuredBuilder``

### 結果の操作

- ``DynamicStructuredResult``
- ``DynamicStructuredResultError``

### ガイド

- <doc:DynamicSchemaBuilding>
- <doc:BuilderPatterns>
- <doc:ProviderIntegration>
