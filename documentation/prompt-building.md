# プロンプト構築

DSL を使用してプロンプトエンジニアリング技法を組み合わせた構造化プロンプトを構築します。

## 概要

`Prompt` と `PromptComponent` を使用すると、プロンプトエンジニアリングのベストプラクティスに基づいた構造化プロンプトを宣言的に構築できます。XML タグ形式でレンダリングされ、LLM の理解精度が向上します。

## 基本的な使い方

`Prompt` イニシャライザ内で `PromptComponent` を並べて記述します：

```swift
let prompt = Prompt {
    PromptComponent.role("データ分析の専門家")
    PromptComponent.objective("ユーザー情報を抽出する")
    PromptComponent.instruction("名前は敬称を除いて抽出")
}

let result: UserInfo = try await client.generate(
    prompt: prompt,
    model: .sonnet
)
```

## コンポーネントの種類

### ペルソナ系

LLM に特定の役割や専門性を与えます。

```swift
Prompt {
    PromptComponent.role("経験豊富な Swift エンジニア")
    PromptComponent.expertise("iOS アプリ開発")
    PromptComponent.expertise("パフォーマンス最適化")
    PromptComponent.behavior("簡潔かつ実用的なアドバイスを提供する")
}
```

| コンポーネント | 説明 |
|---------------|------|
| `role` | LLM の役割を定義 |
| `expertise` | 専門知識やスキルを指定 |
| `behavior` | 回答のスタイルや態度を指定 |

### タスク定義系

タスクの目的や制約を明確にします。

```swift
Prompt {
    PromptComponent.objective("ユーザー情報を JSON 形式で抽出する")
    PromptComponent.context("入力は日本語の SNS 投稿文です")
    PromptComponent.instruction("名前は敬称（さん、様など）を除いて抽出する")
    PromptComponent.instruction("年齢は数値のみ抽出する")
    PromptComponent.constraint("推測はしない")
    PromptComponent.constraint("明示的に記載された情報のみ使用する")
}
```

| コンポーネント | 説明 |
|---------------|------|
| `objective` | タスクの主要な目的やゴール |
| `context` | タスクに関連する背景情報 |
| `instruction` | 具体的な手順や方法 |
| `constraint` | 回答に対する制限や禁止事項 |

### 思考誘導系（Chain-of-Thought）

LLM に特定の思考プロセスを促します。

```swift
Prompt {
    PromptComponent.thinkingStep("まずテキスト内の人名を特定する")
    PromptComponent.thinkingStep("次に年齢に関する記述を探す")
    PromptComponent.thinkingStep("最後に住所情報を抽出する")
    PromptComponent.reasoning("敬称を除くのは、データベースの正規化のためです")
}
```

| コンポーネント | 説明 |
|---------------|------|
| `thinkingStep` | 思考のステップを定義 |
| `reasoning` | 処理の理由や根拠を説明 |

### 例示系（Few-shot）

入出力の例を提供してパターンを学習させます。

```swift
Prompt {
    PromptComponent.example(
        input: "佐藤花子さん（28）は東京在住",
        output: #"{"name": "佐藤花子", "age": 28, "location": "東京"}"#
    )
    PromptComponent.example(
        input: "鈴木一郎氏、45歳、大阪出身",
        output: #"{"name": "鈴木一郎", "age": 45, "location": "大阪"}"#
    )
}
```

| コンポーネント | 説明 |
|---------------|------|
| `example` | 入力と期待する出力のペア |

### メタ指示系

特に重要な指示や補足情報を強調します。

```swift
Prompt {
    PromptComponent.important("不明な情報は必ず null を返してください")
    PromptComponent.note("西暦と和暦が混在している場合があります")
}
```

| コンポーネント | 説明 |
|---------------|------|
| `important` | 特に重要な指示や注意点 |
| `note` | 補足的な情報やヒント |

## 条件分岐とループ

Swift の制御構文を使用して動的にプロンプトを構築できます。

### 条件分岐

```swift
let needsExamples = true

let prompt = Prompt {
    PromptComponent.objective("情報抽出")

    if needsExamples {
        PromptComponent.example(input: "入力例", output: "出力例")
    }
}
```

### ループ

```swift
let thinkingSteps = ["データを読み取る", "パターンを分析する", "結果を出力する"]

let prompt = Prompt {
    PromptComponent.objective("データ分析")

    for step in thinkingSteps {
        PromptComponent.thinkingStep(step)
    }
}
```

## システムプロンプトとの組み合わせ

ユーザープロンプトとシステムプロンプトの両方に DSL を使用できます。

```swift
let systemPrompt = Prompt {
    PromptComponent.role("データ分析の専門家")
    PromptComponent.behavior("正確性を最優先する")
    PromptComponent.constraint("推測をしない")
}

let userPrompt = Prompt {
    PromptComponent.objective("ユーザー情報を抽出する")
    PromptComponent.context("山田太郎さんは35歳です")
}

let result: UserInfo = try await client.generate(
    prompt: userPrompt,
    model: .sonnet,
    systemPrompt: systemPrompt
)
```

## レンダリング結果

プロンプトは XML タグ形式でレンダリングされます。Claude を含む多くの LLM で、XML 形式は構造の理解精度が向上することが知られています。

```swift
let prompt = Prompt {
    PromptComponent.role("データアナリスト")
    PromptComponent.objective("情報抽出")
}

print(prompt.render())
```

出力：

```xml
<role>
データアナリスト
</role>

<objective>
情報抽出
</objective>
```

## 実践的な例

### 情報抽出タスク

```swift
let extractionPrompt = Prompt {
    // ペルソナ
    PromptComponent.role("データ抽出の専門家")
    PromptComponent.expertise("自然言語処理")

    // タスク定義
    PromptComponent.objective("テキストからユーザー情報を抽出する")
    PromptComponent.context("入力は日本語の自己紹介文です")

    // 指示
    PromptComponent.instruction("名前は敬称を除いて抽出")
    PromptComponent.instruction("年齢は数値のみ抽出")
    PromptComponent.instruction("職業が明記されている場合のみ抽出")

    // 制約
    PromptComponent.constraint("推測や補完はしない")
    PromptComponent.constraint("明示的な情報のみを使用")

    // 例示
    PromptComponent.example(
        input: "佐藤花子さん（28）はエンジニアです",
        output: #"{"name": "佐藤花子", "age": 28, "occupation": "エンジニア"}"#
    )

    // 重要事項
    PromptComponent.important("不明な項目は null を設定")
}
```

### 分類タスク

```swift
let classificationPrompt = Prompt {
    PromptComponent.role("感情分析の専門家")

    PromptComponent.objective("テキストの感情を分類する")

    PromptComponent.thinkingStep("テキスト全体のトーンを把握する")
    PromptComponent.thinkingStep("ポジティブ/ネガティブな表現を特定する")
    PromptComponent.thinkingStep("総合的な感情を判定する")

    PromptComponent.example(input: "今日は最高の一日だった！", output: "positive")
    PromptComponent.example(input: "残念な結果になった", output: "negative")
    PromptComponent.example(input: "明日は晴れるらしい", output: "neutral")
}
```

## 次のステップ

- [はじめに](getting-started.md) で基本的な使い方を確認
- [プロバイダー](providers.md) で各プロバイダーとモデルについて学ぶ
- [会話](conversation.md) でマルチターン会話を実装する
