# Changelog

このプロジェクトの注目すべき変更点をすべてドキュメント化します。

フォーマットは [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/spec/v2.0.0.html) に従います。

## [未リリース]

## [1.0.18] - 2025-12-19

### 追加

- **WebToolKit.fetch_page**: Web ページのコンテンツ取得ツールを追加
  - HTML テキスト抽出とページネーション対応
  - MCP ベストプラクティスに準拠した ToolAnnotations 設定
  - FetchWebPageTool を WebToolKit に統合

- **ConversationalAgentSession.initialMessages**: セッション復元パラメータを追加
  - セッション復元時に会話履歴を渡せるように改善
  - LLMMessage を Single Source of Truth として設計

### 変更

- **ConversationAgentExample の UX 改善**
  - セッション削除時の確認ダイアログを追加
  - セッション名変更機能を追加（コンテキストメニュー）
  - 「完了しました」表示のロジック修正（構造化出力完了時のみ）
  - スクロールビューを下基準に変更
  - ScrollView 二重問題を修正

- **ConversationAgentExample を State+UseCase アーキテクチャにリファクタリング**
  - SessionData: steps を messages に変更（永続化改善）
  - ActiveSessionState: liveSteps と messages 分離
  - 不要なファイルを削除（FetchWebPageTool, WebFetchService 等）

### 修正

- **空セッションではアクティブセッションバーを表示しない**: 空セッション時の UI 表示を改善

## [1.0.17] - 2025-12-18

### 追加

- **LLMMCP モジュール**: 公式 MCP SDK を統合した新モジュール
  - `MCPClientConnection`: MCP サーバーとの接続管理
  - `MCPToolBridge`: MCP ツールを LLMTool として利用可能に
  - OAuth 2.0 認証サポート（Authorization Code Flow with PKCE）
  - DocC ドキュメントを追加

- **ToolKit プロトコル**: ツールセットの組み込みとカスタマイズを簡素化
  - `MemoryToolKit`: メモリ管理ツール（read/write/list/delete）
  - `FileSystemToolKit`: ファイル操作ツール
  - `HTTPToolKit`: HTTP リクエストツール
  - `DateTimeToolKit`: 日時操作ツール
  - DocC ドキュメントを追加

- **スキーマ制約の Prompt DSL 統合**: 構造化出力の制約をプロンプトに自動反映
  - `ConstraintsSection`: 制約情報を自動生成するプロンプトコンポーネント
  - `RemovedConstraint` 抽出による API 互換性維持

### 変更

- **AgentExample アプリの改善**: MemoryToolKit シナリオを追加
  - iOS/macOS 両対応
  - ツールキットベースのシナリオ実行をサポート

### ドキュメント

- **DocC の改善**
  - TechnologyRoot ランディングページを追加
  - 全サブモジュールを combined documentation に統合
  - モジュールナビゲーションを改善
  - README に API リファレンスへのリンクを追加

## [1.0.16] - 2025-12-17

### 追加

- **LLMToolkits モジュール**: 高レベルなエージェント構築支援機能を追加
  - プリセット: `ResearcherPreset`, `WriterPreset`, `CodingAssistantPreset`
  - 共通出力型: `AnalysisResult`, `Summary`, `CodeReview`, `Classification` など
  - システムプロンプトビルダー: `SystemPromptBuilder`
  - ツール群: `WebSearchTool`, `FetchWebPageTool`, `TextAnalysisTool`
  - DocC ドキュメントを追加

### 変更

- **ConversationAgentExample の改善**: LLMToolkits を活用したリファクタリング
  - 3つのシナリオ（Research, Article Summary, Code Review）をサポート
  - セッション結果の永続化と復元機能を追加
  - 出力タイプ切り替え時にセッションを自動再作成

### 修正

- **CommonOutputs のスキーマ制約を削除**: Anthropic API 互換性の改善
  - `minimum`/`maximum` 制約を削除（API でサポートされていないため）
  - 制約情報はフィールド説明に記載

## [1.0.15] - 2025-12-16

### 変更

- **ToolSet のインスタンスベース登録方式への移行**: ツール登録APIを改善
  - 型ベース（`.self`）からインスタンスベース（`()`）の登録方式に変更
  - `LLMToolRegistrable` プロトコルを削除し、シンプルな設計に
  - ツール定義とインスタンス化を1ステップで完結可能に

- **ToolCapableClient を ToolCallableClient にリネーム**: 命名の一貫性を向上
  - プロトコル名をより直感的な名前に変更
  - 関連ファイル名を統一（`*+ToolCallable.swift`）

- **ConversationAgentExample の改善**: サンプルアプリの機能強化
  - セッション管理機能を追加
  - コード構造のリファクタリングと機能改善

### ドキュメント

- **README の改善**
  - 「プロンプト DSL」を「プロンプトビルダー」にリネーム
  - 「会話」セクションを追加（ConversationHistory の使用例）
  - サンプルアプリセクションを削除（肥大化のため）
  - Linux/Docker 対応を要件に追加

## [1.0.14] - 2025-12-16

### 追加

- **ConversationalAgentSession API**: 会話エージェントのセッション管理機能を追加
  - マルチターン会話でのエージェント実行をサポート
  - セッションベースの状態管理
  - サンプルアプリ（ConversationAgentExample）を追加

- **ConversationalAgent ドキュメント**: 会話エージェント機能の包括的なドキュメントを追加

### 変更

- **エージェント機能のリトライ対応と構造化出力フェーズ管理**: エージェントループの信頼性を向上
  - リトライ機能の強化
  - 構造化出力フェーズの管理を改善

- **モジュール分離によるパッケージ構成の最適化**: SPMパッケージ構造を改善
  - モジュール間の依存関係を整理
  - ビルド時間とコード保守性を向上

- **API 名修正**: より直感的な命名への改善

### 修正

- **マルチターン会話でステップ履歴を保持するように修正**: 会話継続時のコンテキスト保持問題を解決
  - 複数ターンにわたる会話で履歴が正しく維持されるように修正

## [1.0.13] - 2025-12-15

### 追加

- **ConversationEvent.error**: 会話イベントにエラーイベントを追加
  - エラー発生時の通知機能を強化
  - エラーハンドリングの柔軟性を向上

### 変更

- **ConversationHistory の再設計**: 会話履歴管理の内部実装を刷新
  - APIの簡素化と使いやすさ向上
  - ドキュメントの更新

- **JSONSchema の責務分離とアクセス制御の最適化**: スキーマ関連の内部構造を改善
  - 責務の明確化によりコードの保守性向上
  - アクセス制御の最適化

- **ToolCall/ToolResponse 型の統合とディレクトリ再編成**: ツール関連型の整理
  - 型の統合による一貫性向上
  - ファイル構造の最適化

## [1.0.12] - 2025-12-15

### 変更

- **AgentStepStreamプロトコルの導入**: エージェントステップのストリーミング処理を抽象化
  - `AgentStepStream`プロトコル: `AsyncSequence`と`AsyncStream`を統一的に扱うインターフェース
  - `AgentStepSequence`の拡張により既存コードとの後方互換性を維持
  - Agentモジュールの再編成とファイル構造の整理

- **AgentContextの改善**: `configurationSync` workaroundを削除
  - Swift 6準拠のクリーンな実装に移行
  - コードの簡素化と保守性向上

### 修正

- **サンプルアプリの更新**: AgentStepStreamプロトコルに対応
  - AgentExampleアプリのエージェント実行コードを更新

### ドキュメント

- **AgentStepStreamドキュメント追加**: 新プロトコルの使用方法と移行ガイド

## [1.0.11] - 2025-12-15

### 追加

- **DocC ドキュメント**: AgentLoopInternals.md（エージェントループ内部実装ガイド）
  - MermaidをテキストとASCII図で代替したDocC対応版
  - フェーズ管理、終了ポリシー、状態管理の詳細解説

### 変更

- **AgentExampleアプリのリファクタリング**: AgentScenarioTypeプロトコルによるシナリオ抽象化
  - シナリオ定義の統一化と拡張性向上
  - コードの重複削減

### 修正

- **DocCビルド警告の修正**
  - シンボルリンクの不整合を修正（ToolArgument, StopReason等）
  - Topics循環参照を解消
  - internal型への参照をコード表記に変更

- **Mermaid図の修正**: decodeFinalOutput()フローの複数パス同一ノード接続問題を解消

## [1.0.10] - 2025-12-15

### 追加

- **自動リトライ機能**: APIレート制限（429エラー）および5xxサーバーエラー時の自動リトライ
  - 指数バックオフ + ジッターによる待機時間計算
  - 各プロバイダーのレート制限ヘッダー解析（OpenAI/Anthropic/Gemini対応）
  - `RetryConfiguration`: リトライ設定（`.default`, `.disabled`, `.aggressive`, `.conservative`）
  - `RetryEvent` / `RetryEventHandler`: リトライイベント通知コールバック

- **Gemini エージェントループ対応**: Geminiプロバイダーでのエージェントループ実行をサポート
  - Gemini特有の終了判定（関数呼び出し時のfinishReason処理）に対応

- **エージェント終了ポリシー**: エージェントループの終了判定を拡張
  - `StandardTerminationPolicy`: 標準的な終了判定
  - `DuplicateDetectionPolicy`: 重複ツール呼び出し検出

- **エージェント実行制御**: 実行ライフサイクル管理機能
  - `AgentExecutionController`: 開始/キャンセル/状態管理
  - エージェント実行のキャンセル機能

- **ドキュメント**
  - documentation/agent-loop-internals.md: エージェントループ内部実装ガイド

### 変更

- **エージェントループのsystemPrompt**: `String?` から `Prompt?` 型に変更
  - Prompt DSLで構築したプロンプトを直接渡せるように改善
  - `ExpressibleByStringLiteral` により文字列リテラルも引き続き使用可能

- **エージェントループのフェーズ管理**: 複数のブール値フラグを `LoopPhase` enumに統合
  - 状態の排他性をコンパイル時に保証
  - リトライ回数をassociated valueで管理

- **AgentExampleアプリの大幅改善**
  - カテゴリ別構造化出力型（ResearchReport, CalculationReport, TemporalReport, MultiToolReport, ReasoningReport）
  - 新規ツール追加（UnitConverterTool, RandomGeneratorTool, StringManipulationTool）
  - ToolSelectionView: グリッド形式のツール選択UI
  - ExecutionProgressBanner: フェーズ別進行状況バナーとリアルタイム経過時間表示

### 修正

- **OpenAI構造化出力**: メッセージ配列がassistantで終わる場合のエラーを修正
- **snake_caseデコード**: AgentStepSequence, AgentTypes, LLMProviderでのsnake_case対応

## [1.0.9] - 2025-12-14

### 追加

- **ツールコール機能**: LLMにツール（関数）の選択と引数決定を計画させる機能
  - `@Tool` マクロ: ツール定義用の構造体マクロ
  - `@ToolArgument` マクロ: ツール引数の説明・制約定義
  - `ToolSet` Result Builder: 複数ツールの登録
  - `planToolCalls()` API: Claude/GPT/Gemini 対応
  - `ToolChoice`: 自動選択・強制指定・無効化の制御
  - `ToolResult`: ツール実行結果の型安全な管理
  - ToolCallingDemo: iOSサンプルアプリにデモ追加

- **エージェントループ機能**: LLMが自動的にツールを選択・実行し、構造化出力を生成するまでループする機能
  - `AgentStep`: エージェントステップの列挙型（thinking, toolCall, toolResult, finalResponse）
  - `AgentStepSequence`: ステップを返すAsyncSequence
  - `AgentContext`: エージェントループの内部状態管理（Actor）
  - `AgentConfiguration`: 設定（maxSteps, autoExecuteTools）
  - `AgentCapableClient`: エージェント機能を持つクライアントのプロトコル
  - `runAgent()`: エージェントループを実行するメソッド（Anthropic/OpenAI対応、Gemini非対応）
  - AgentLoopDemo: iOSサンプルアプリにエージェントデモ追加

- **ドキュメント**
  - documentation/tool-calling.md: ツールコール詳細ガイド
  - documentation/agent-loop.md: エージェントループ詳細ガイド
  - DocC: AgentLoop.md 追加

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

[未リリース]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.18...HEAD
[1.0.18]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.17...v1.0.18
[1.0.17]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.16...v1.0.17
[1.0.16]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.15...v1.0.16
[1.0.15]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.14...v1.0.15
[1.0.14]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.13...v1.0.14
[1.0.13]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.12...v1.0.13
[1.0.12]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.11...v1.0.12
[1.0.11]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.10...v1.0.11
[1.0.10]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.9...v1.0.10
[1.0.9]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/no-problem-dev/swift-llm-structured-outputs/compare/v1.0.0...v1.0.4
[1.0.0]: https://github.com/no-problem-dev/swift-llm-structured-outputs/releases/tag/v1.0.0

<!-- Auto-generated on 2025-12-13T09:37:38Z by release workflow -->

<!-- Auto-generated on 2025-12-13T10:51:06Z by release workflow -->

<!-- Auto-generated on 2025-12-13T11:27:10Z by release workflow -->

<!-- Auto-generated on 2025-12-14T03:13:27Z by release workflow -->

<!-- Auto-generated on 2025-12-14T06:19:39Z by release workflow -->

<!-- Auto-generated on 2025-12-14T22:47:37Z by release workflow -->

<!-- Auto-generated on 2025-12-15T00:06:39Z by release workflow -->

<!-- Auto-generated on 2025-12-15T03:15:02Z by release workflow -->

<!-- Auto-generated on 2025-12-15T14:05:33Z by release workflow -->

<!-- Auto-generated on 2025-12-16T01:03:39Z by release workflow -->

<!-- Auto-generated on 2025-12-16T12:58:40Z by release workflow -->

<!-- Auto-generated on 2025-12-16T15:12:51Z by release workflow -->

<!-- Auto-generated on 2025-12-18T01:03:17Z by release workflow -->

<!-- Auto-generated on 2025-12-18T23:39:00Z by release workflow -->
