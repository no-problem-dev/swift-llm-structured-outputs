# StructuredBuilder パターン

Result Builder を活用した宣言的なスキーマ構築パターンを学びます。

@Metadata {
    @PageColor(purple)
}

## 概要

`StructuredBuilder` は Swift の Result Builder 機能を使用して、DSL スタイルでスキーマを定義できるようにします。このガイドでは、様々なパターンと活用方法を紹介します。

## 基本構文

`DynamicStructured` の初期化時に `@StructuredBuilder` クロージャを使用します。

```swift
let schema = DynamicStructured("MySchema") {
    // ここに NamedSchema を列挙
    JSONSchema.string(description: "フィールド1")
        .named("field1")

    JSONSchema.integer()
        .named("field2")
}
```

## フィールド定義のチェーン

### 基本パターン

```swift
// JSONSchema → .named() → NamedSchema
JSONSchema.string(description: "名前")
    .named("name")

// オプショナル指定
JSONSchema.string(description: "ニックネーム")
    .named("nickname")
    .optional()

// 明示的に必須指定
JSONSchema.string(description: "メール")
    .named("email")
    .required()
```

### 制約付きパターン

```swift
// 文字列制約
JSONSchema.string(
    description: "ユーザー名",
    minLength: 3,
    maxLength: 20,
    pattern: "^[a-zA-Z0-9_]+$"
).named("username")

// 数値制約
JSONSchema.integer(
    description: "年齢",
    minimum: 0,
    maximum: 150
).named("age")

// 配列制約
JSONSchema.array(
    items: .string(),
    description: "タグ",
    minItems: 1,
    maxItems: 5
).named("tags")
```

## 動的構築パターン

### 条件分岐

```swift
let includeAdmin = true
let userType = "premium"

let schema = DynamicStructured("User") {
    JSONSchema.string(description: "名前")
        .named("name")

    // if 文
    if includeAdmin {
        JSONSchema.boolean(description: "管理者権限")
            .named("isAdmin")
    }

    // if-else 文
    if userType == "premium" {
        JSONSchema.integer(description: "プレミアムポイント")
            .named("premiumPoints")
    } else {
        JSONSchema.integer(description: "通常ポイント")
            .named("normalPoints")
    }
}
```

### ループからの生成

```swift
struct FieldDefinition {
    let name: String
    let description: String
    let type: FieldType

    enum FieldType {
        case string, integer, boolean
    }
}

let customFields: [FieldDefinition] = [
    FieldDefinition(name: "field1", description: "フィールド1", type: .string),
    FieldDefinition(name: "field2", description: "フィールド2", type: .integer),
]

let schema = DynamicStructured("CustomForm") {
    // 固定フィールド
    JSONSchema.string(description: "フォーム名")
        .named("formName")

    // 動的フィールド
    for field in customFields {
        switch field.type {
        case .string:
            JSONSchema.string(description: field.description)
                .named(field.name)
        case .integer:
            JSONSchema.integer(description: field.description)
                .named(field.name)
        case .boolean:
            JSONSchema.boolean(description: field.description)
                .named(field.name)
        }
    }
}
```

## ファクトリパターン

### スキーマファクトリ

再利用可能なスキーマ構築ロジックをファクトリ関数として定義できます。

```swift
struct SchemaFactory {
    /// 共通のユーザーフィールドを生成
    static func commonUserFields() -> [NamedSchema] {
        return [
            JSONSchema.string(description: "ユーザーID")
                .named("userId"),
            JSONSchema.string(description: "メールアドレス")
                .named("email"),
            JSONSchema.string(description: "作成日時")
                .named("createdAt")
        ]
    }

    /// アプリケーション固有のフィールドを追加
    static func appSpecificFields(for appType: String) -> [NamedSchema] {
        switch appType {
        case "ecommerce":
            return [
                JSONSchema.array(items: .string(), description: "購入履歴")
                    .named("purchaseHistory"),
                JSONSchema.integer(description: "ポイント残高")
                    .named("pointBalance")
            ]
        case "social":
            return [
                JSONSchema.integer(description: "フォロワー数")
                    .named("followerCount"),
                JSONSchema.array(items: .string(), description: "投稿ID")
                    .named("postIds")
            ]
        default:
            return []
        }
    }
}

// 使用例
let schema = DynamicStructured(
    name: "EcommerceUser",
    description: "EC サイトのユーザー",
    fields: SchemaFactory.commonUserFields() + SchemaFactory.appSpecificFields(for: "ecommerce")
)
```

### 設定からのスキーマ生成

```swift
struct SchemaConfig: Codable {
    let name: String
    let description: String?
    let fields: [FieldConfig]

    struct FieldConfig: Codable {
        let name: String
        let type: String
        let description: String?
        let required: Bool
    }
}

extension SchemaConfig {
    func toDynamicStructured() -> DynamicStructured {
        DynamicStructured(
            name: name,
            description: description,
            fields: fields.map { field in
                let schema: JSONSchema
                switch field.type {
                case "string":
                    schema = .string(description: field.description)
                case "integer":
                    schema = .integer(description: field.description)
                case "boolean":
                    schema = .boolean(description: field.description)
                default:
                    schema = .string(description: field.description)
                }

                var namedSchema = schema.named(field.name)
                if !field.required {
                    namedSchema = namedSchema.optional()
                }
                return namedSchema
            }
        )
    }
}
```

## エラーハンドリングパターン

### バリデーション付きファクトリ

```swift
enum SchemaError: Error {
    case emptyName
    case duplicateFieldName(String)
    case invalidFieldType(String)
}

struct ValidatedSchemaBuilder {
    static func build(
        name: String,
        fields: [NamedSchema]
    ) throws -> DynamicStructured {
        // 名前の検証
        guard !name.isEmpty else {
            throw SchemaError.emptyName
        }

        // 重複フィールド名のチェック
        let fieldNames = fields.map { $0.name }
        let uniqueNames = Set(fieldNames)
        if fieldNames.count != uniqueNames.count {
            let duplicates = fieldNames.filter { name in
                fieldNames.filter { $0 == name }.count > 1
            }
            throw SchemaError.duplicateFieldName(duplicates.first!)
        }

        return DynamicStructured(
            name: name,
            description: nil,
            fields: fields
        )
    }
}
```

## 次のステップ

- <doc:ProviderIntegration> で各 LLM プロバイダーとの連携方法を学ぶ
