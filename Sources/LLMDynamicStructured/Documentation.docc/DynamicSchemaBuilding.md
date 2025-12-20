# 動的スキーマの構築

ランタイムで構造化出力のスキーマを定義する方法を学びます。

@Metadata {
    @PageColor(purple)
}

## 概要

`DynamicStructured` を使用すると、コンパイル時ではなく実行時にスキーマを定義できます。これにより、ユーザー入力やデータベースの情報に基づいて柔軟にスキーマを構築できます。

## 基本的なスキーマ定義

### シンプルな構造

```swift
import LLMDynamicStructured

let bookInfo = DynamicStructured("BookInfo", description: "書籍情報") {
    JSONSchema.string(description: "タイトル")
        .named("title")

    JSONSchema.string(description: "著者名")
        .named("author")

    JSONSchema.integer(description: "出版年", minimum: 1000, maximum: 2100)
        .named("year")
}
```

### フィールドタイプ

@Row {
    @Column {
        **プリミティブ型**

        ```swift
        // 文字列
        JSONSchema.string(description: "名前")
            .named("name")

        // 整数
        JSONSchema.integer(minimum: 0)
            .named("count")

        // 数値（浮動小数点）
        JSONSchema.number(minimum: 0.0)
            .named("price")

        // 真偽値
        JSONSchema.boolean(description: "有効")
            .named("isActive")
        ```
    }

    @Column {
        **複合型**

        ```swift
        // 列挙型
        JSONSchema.enum(
            ["draft", "published", "archived"],
            description: "ステータス"
        ).named("status")

        // 文字列配列
        JSONSchema.array(
            items: .string(),
            description: "タグ"
        ).named("tags")

        // 整数配列
        JSONSchema.array(
            items: .integer(),
            description: "スコア"
        ).named("scores")
        ```
    }
}

## 必須・オプショナルフィールド

デフォルトでは全てのフィールドが必須です。`.optional()` を使用してオプショナルに変更できます。

```swift
let userProfile = DynamicStructured("UserProfile") {
    // 必須フィールド（デフォルト）
    JSONSchema.string(description: "ユーザー名")
        .named("username")

    // オプショナルフィールド
    JSONSchema.string(description: "自己紹介")
        .named("bio")
        .optional()

    // 明示的に必須を指定
    JSONSchema.string(description: "メールアドレス")
        .named("email")
        .required()
}
```

## 制約の設定

### 文字列の制約

```swift
JSONSchema.string(
    description: "ユーザー名",
    minLength: 3,        // 最小文字数
    maxLength: 20,       // 最大文字数
    pattern: "^[a-z]+$"  // 正規表現パターン
).named("username")
```

### 数値の制約

```swift
JSONSchema.integer(
    description: "年齢",
    minimum: 0,          // 最小値
    maximum: 150         // 最大値
).named("age")

JSONSchema.number(
    description: "価格",
    minimum: 0.0,
    maximum: 1000000.0
).named("price")
```

### 配列の制約

```swift
JSONSchema.array(
    items: .string(),
    description: "タグ",
    minItems: 1,         // 最小要素数
    maxItems: 10         // 最大要素数
).named("tags")
```

## 条件付きフィールド

`StructuredBuilder` は Swift の制御構文をサポートしています。

```swift
let formSchema = DynamicStructured("Form") {
    JSONSchema.string(description: "名前")
        .named("name")

    // 条件付きフィールド
    if includeEmail {
        JSONSchema.string(description: "メール")
            .named("email")
    }

    // if-else
    if isAdminForm {
        JSONSchema.string(description: "管理者コード")
            .named("adminCode")
    } else {
        JSONSchema.string(description: "ユーザーコード")
            .named("userCode")
    }

    // ループから生成
    for field in customFields {
        JSONSchema.string(description: field.description)
            .named(field.name)
    }
}
```

## ネストされた構造

オブジェクト内にオブジェクトを持つ構造も定義できます。

```swift
let orderSchema = DynamicStructured("Order") {
    JSONSchema.string(description: "注文ID")
        .named("orderId")

    // ネストされたオブジェクト
    JSONSchema.object(
        description: "配送先住所",
        properties: [
            "prefecture": .string(description: "都道府県"),
            "city": .string(description: "市区町村"),
            "address": .string(description: "番地")
        ],
        required: ["prefecture", "city", "address"]
    ).named("shippingAddress")

    // オブジェクトの配列
    JSONSchema.array(
        items: .object(
            properties: [
                "productId": .string(),
                "quantity": .integer(minimum: 1)
            ],
            required: ["productId", "quantity"]
        ),
        description: "注文商品"
    ).named("items")
}
```

## JSON Schema への変換

`DynamicStructured` は内部で JSON Schema に変換されます。

```swift
let schema = bookInfo.toJSONSchema()

// デバッグ出力
print(schema.toJSONString(prettyPrinted: true))
```

出力例:

```json
{
  "type": "object",
  "description": "書籍情報",
  "properties": {
    "title": { "type": "string", "description": "タイトル" },
    "author": { "type": "string", "description": "著者名" },
    "year": { "type": "integer", "description": "出版年", "minimum": 1000, "maximum": 2100 }
  },
  "required": ["title", "author", "year"],
  "additionalProperties": false
}
```

## 次のステップ

- <doc:BuilderPatterns> で StructuredBuilder の詳細を学ぶ
- <doc:ProviderIntegration> で各プロバイダーとの連携方法を確認
