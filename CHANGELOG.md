# Changelog

このプロジェクトの注目すべき変更点をすべてドキュメント化します。

フォーマットは [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/spec/v2.0.0.html) に従います。

## [未リリース]

## [1.0.8] - 2025-12-14

### 追加

- **iOS サンプルアプリ**: ライブラリの全機能を試せる iOS アプリを追加
  - 基本的な構造化出力デモ
  - フィールド制約デモ
  - 列挙型サポートデモ
  - 会話機能デモ
  - イベントストリームデモ
  - プロンプト DSL デモ
  - プロンプトビルダーデモ
  - プロバイダー比較デモ

- **プロバイダー比較機能**
  - Claude/GPT/Gemini の並列実行と結果比較
  - プロバイダーごとのモデル選択（Claude: Opus/Sonnet/Haiku, GPT: 4o/4o-mini/o1/o3-mini, Gemini: Pro/Flash/Flash-Lite）
  - 14種類のテストケース（5カテゴリ：情報抽出、推論、構造、品質、言語）
  - カスタム入力モード（任意のシステムプロンプト・テキストで比較可能）
  - レスポンス時間・トークン使用量の計測

- **Prompt DSL**: 構造化プロンプト構築機能
  - `Prompt { }` ビルダー
  - `PromptComponent` による構成要素定義

- **Conversation イベントストリーム**: ストリーミング応答機能
  - `chatStream()` メソッド
  - リアルタイムの進捗表示

- **CLI 統合テストツール**: `Examples/IntegrationTests`
  - 3プロバイダーの一括テスト
  - Docker 対応

- **ドキュメント**: サンプルアプリのドキュメント追加
  - DocC に `ExampleApp.md` 追加
  - README にサンプルアプリセクション追加

### 修正

- **OpenAI Structured Outputs**: 未サポートの JSON Schema 制約を除去
  - `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum` を除去
  - `minLength`, `maxLength`, `pattern`, `format` を除去
  - `sanitizedForOpenAI()` メソッドを追加

- **Gemini JSON Schema**: 互換性修正
  - `additionalProperties` を除去
  - `sanitizedForGemini()` メソッドを追加

- **iOS UX 改善**
  - キーボード自動dismissal
  - Picker UI の改善
  - 設定の UserDefaults 永続化

## [1.0.7] - 2025-12-13

### 修正

- Linux環境でのビルド対応
  - Provider/Client全ファイルに `FoundationNetworking` のインポートを追加
  - LinuxではURLRequest, URLResponse, HTTPURLResponseが `FoundationNetworking` モジュールにあるため必要
  - `#if canImport(FoundationNetworking)` による条件付きインポート

## [1.0.6] - 2025-12-13

### 修正

- Anthropic構造化出力APIの修正
  - ベータヘッダーを `structured-outputs-2025-11-13` に変更
  - `output_format` 構造を `schema` 直接指定に変更
  - `AnthropicJSONSchemaWrapper` を廃止

### 追加

- `JSONSchema.sanitizedForAnthropic()` メソッド
  - Anthropic APIでサポートされていない制約を自動的に除去
  - `maxItems`: 完全に除去
  - `minItems`: 0と1以外の値を除去
  - `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`: 除去
  - `minLength`, `maxLength`: 除去
  - 再帰的にネストされたスキーマもサニタイズ

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

[未リリース]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.8...HEAD
[1.0.8]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.0...v1.0.4
[1.0.0]: https://github.com/no-problem-dev/swift-llm-structured-outputs/releases/tag/v1.0.0

<!-- Auto-generated on 2025-12-13T09:37:38Z by release workflow -->

<!-- Auto-generated on 2025-12-13T10:51:06Z by release workflow -->

<!-- Auto-generated on 2025-12-13T11:27:10Z by release workflow -->
