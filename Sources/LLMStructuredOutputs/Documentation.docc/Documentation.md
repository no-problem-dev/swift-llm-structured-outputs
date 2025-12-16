# swift-llm-structured-outputs

型安全な構造化出力を生成する Swift LLM クライアントライブラリ

@Metadata {
    @TechnologyRoot
}

## 概要

LLMStructuredOutputs は、大規模言語モデルから型安全な構造化出力を生成できる Swift ライブラリです。Swift マクロを使用して、完全なバリデーション制約付きの出力型を定義でき、ライブラリが自動的に JSON Schema を生成し、複数の LLM プロバイダーからのレスポンスを処理します。

## Topics

### フレームワーク

- ``/LLMClient``
- ``/LLMTool``
- ``/LLMConversation``
- ``/LLMAgent``
- ``/LLMConversationalAgent``

> Tip: 高レベルツールキット（プリセット、組み込みツール）は **LLMToolkits** モジュールで提供されています。サイドバーから参照できます。

### ガイド

- <doc:GettingStarted>
- <doc:PromptBuilding>
- <doc:Providers>
- <doc:Conversations>
- <doc:AgentLoop>
- <doc:ConversationalAgent>
