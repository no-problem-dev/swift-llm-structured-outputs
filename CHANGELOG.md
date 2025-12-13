# Changelog

このプロジェクトの注目すべき変更点をすべてドキュメント化します。

フォーマットは [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/spec/v2.0.0.html) に従います。

## [未リリース]

## [1.0.5] - 2025-12-13

### 変更

- README.md を swift-firebase-server スタイルに統一
- すべてのドキュメントを日本語化
  - documentation/getting-started.md
  - documentation/providers.md
  - documentation/conversation.md
  - RELEASE_PROCESS.md
  - Documentation.docc 内のすべてのファイル

### 修正

- auto-release-on-merge.yml を swift-firebase-server の実装に合わせて修正
  - PR マージ時のトリガーに変更
  - ブランチ名からのバージョン抽出
  - 次バージョンブランチの自動作成
  - ドラフト PR の自動作成
- docc.yml を swift-firebase-server の実装に合わせて修正
  - maxim-lobanov/setup-xcode を使用
  - シングルジョブ構成に変更

## [1.0.4] - 2025-12-13

### 修正

- リリースワークフローのトリガー修正（CHANGELOG バージョン整合性）

## [1.0.0] - 2025-12-13

### 追加

#### マクロ
- `@Structured` マクロ: JSON Schema 自動生成による構造体ベースの構造化出力
- `@StructuredField` マクロ: 制約サポート（minimum, maximum, minLength, maxLength, minItems, maxItems, pattern, format, enum）
- `@StructuredEnum` マクロ: String ベースの enum サポート
- `@StructuredCase` マクロ: enum ケースの説明
- LLM プロンプト用の enum 説明自動生成
- `@Structured` マクロでのネスト型サポート

#### クライアント
- `AnthropicClient`: Claude モデル用
- `OpenAIClient`: GPT モデル用
- `GeminiClient`: Gemini モデル用
- `StructuredLLMClient` プロトコル: 統一 API

#### モデル
- 全プロバイダーのモデルエイリアス:
  - Claude: `.sonnet`, `.opus`, `.haiku`
  - GPT: `.gpt4o`, `.gpt4oMini`, `.o1`, `.o1Mini`, `.o3Mini`
  - Gemini: `.pro25`, `.flash25`, `.flash25Lite`, `.flash20`, `.pro15`, `.flash15`
- 固定バージョンサポート（例: `.sonnet_20250514`）
- 明示的バージョン文字列によるプレビューバージョンサポート
- `.custom(String)` ケースによるカスタムモデルサポート
- 後方互換性のための `RawRepresentable` 準拠

#### 会話
- `Conversation<Client>` クラス: マルチターン会話管理
- `ChatResponse<T>` 構造体: 完全なレスポンスメタデータ
- `TokenUsage` 構造体によるトークン使用量追跡
- `StopReason` enum: レスポンス終了理由
- `LLMMessage` 構造体: `.user()` と `.assistant()` ファクトリメソッド
- 会話継続用の全クライアント `chat()` メソッド

#### スキーマ
- `StructuredProtocol`: 手動 JSON Schema 定義
- `JSONSchema` enum: スキーマ構築
- `FieldConstraint` enum: フィールドバリデーション

#### インフラストラクチャ
- 完全な Swift 6 並行処理サポート（async/await、Sendable）
- iOS 17+ および macOS 14+ サポート
- `LLMError` enum: 包括的なエラーハンドリング
- DocC ドキュメント
- 自動リリースとドキュメント生成用 GitHub Actions

[未リリース]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.5...HEAD
[1.0.5]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.0...v1.0.4
[1.0.0]: https://github.com/no-problem-dev/swift-llm-structured-outputs/releases/tag/v1.0.0
