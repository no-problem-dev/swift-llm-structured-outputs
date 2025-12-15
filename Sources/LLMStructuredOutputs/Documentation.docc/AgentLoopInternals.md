# エージェントループ 内部実装ガイド

``AgentStepSequence`` の内部実装フローを詳細に解説します。

## 概要

エージェントループは以下のレイヤーで構成されています：

| レイヤー | コンポーネント | 役割 |
|---------|---------------|------|
| Public API | ``AgentStepSequence`` | AsyncSequence としてステップを提供 |
| Execution | `AgentLoopRunner` (Actor) | ループ実行の制御 |
| Policy | `AgentTerminationPolicy` | 終了条件の判定 |
| State | ``AgentContext``, `AgentLoopStateManager` | 状態管理 |

### 設計原則

- **Actor による並行安全性**: 状態管理は全て Actor で保護
- **Strategy Pattern**: 終了条件判定はポリシーとして抽象化
- **Decorator Pattern**: 重複検出は標準ポリシーをラップして拡張
- **AsyncSequence**: ストリーミング形式でステップを提供

## コンポーネント構成

### ファイル構成

```
Sources/LLMStructuredOutputs/Agent/
├── AgentStepSequence.swift      # メインエントリポイント + ループ実行
├── AgentTerminationPolicy.swift # 終了ポリシープロトコルと実装
├── AgentLoopState.swift         # 状態管理 Actor
├── AgentContext.swift           # メッセージ履歴・ツール管理
└── AgentTypes.swift             # 型定義（AgentStep, AgentError 等）
```

### コンポーネント関係

```
AgentStepSequence<Client, Output>
    │
    └─▶ AsyncIterator
            │
            └─▶ AgentLoopRunner<Client, Output> (Actor)
                    │
                    ├─▶ AgentTerminationPolicy (Protocol)
                    │       ├─▶ StandardTerminationPolicy
                    │       └─▶ DuplicateDetectionPolicy
                    │
                    ├─▶ AgentLoopStateManager (Actor)
                    │       └─ currentStep, toolCallHistory
                    │
                    └─▶ AgentContext (Actor)
                            └─ messages, tools
```

## メインループフロー

### nextStep() の処理フロー

`AgentLoopRunner.nextStep()` が呼ばれるたびに以下の処理が実行されます：

```
1. 保留中のイベントあり？
   ├─ Yes → 保留イベントを返す → 終了
   └─ No → 続行

2. ループ完了済み？
   ├─ Yes → nil を返す → 終了
   └─ No → 続行

3. ステップ上限到達？
   ├─ Yes → maxStepsExceeded エラーをスロー
   └─ No → 続行

4. ステップをインクリメント

5. LLM にリクエスト送信

6. レスポンスをコンテキストに追加

7. 終了ポリシーで判定

8. 判定結果を処理 → ステップ終了
```

### 判定結果の処理分岐

| TerminationDecision | 処理内容 |
|---------------------|----------|
| `continueWithTools` | ツール呼び出しを処理 → 履歴に記録 → イベントをキュー → ツール実行 → 結果追加 → 最初のイベントを返す |
| `continueWithThinking` | `.thinking` を返す |
| `terminateWithOutput` | フェーズに応じてデコード試行（後述） |
| `terminateImmediately` | 完了フラグを立てて `nil` を返す |

## 構造化出力フェーズ管理

Anthropic の推奨パターンに従い、エージェントループは2つのフェーズを持ちます。

### フェーズの種類（LoopPhase enum）

| LoopPhase | associated value | 説明 |
|-----------|------------------|------|
| `.toolUse` | なし | LLMがツールを呼び出し可能。responseSchemaは送信しない |
| `.finalOutput(retryCount: Int)` | リトライ回数 | ツールを無効化し、responseSchemaを送信。デコード再試行を追跡 |
| `.completed` | なし | ループ完了状態 |

### フェーズ遷移

```
[開始] → .toolUse
            │
            ├─ ツール呼び出し継続 → .toolUse
            │
            ├─ endTurn + ツールあり → .finalOutput(retryCount: 0)
            │                              │
            │                              ├─ デコード失敗 (リトライ) → .finalOutput(retryCount+1)
            │                              │
            │                              └─ デコード成功 → .completed
            │
            └─ ツールなし + デコード成功 → .completed
                                              │
                                              └─ [終了] nil を返す
```

### なぜフェーズを分けるのか

ツール使用中に `responseSchema` を送ると、以下の問題が発生します：

1. LLMがテキスト応答を返した際、JSONとして解釈できずデコードエラー
2. 「Failed to decode output」エラーが頻発

**解決策**: Anthropic の Combined Usage パターンに従い：
- ツールが使用可能な間 → `responseSchema` を送らない
- ツールなし、または最終出力フェーズ → `responseSchema` を送る

### sendRequest() の動作

| フェーズ | ツール送信 | responseSchema送信 |
|---------|-----------|-------------------|
| `.toolUse` (ツールあり) | ✅ 送信 | ❌ 送信しない |
| `.toolUse` (ツールなし) | ❌ 送信しない | ✅ 送信 |
| `.finalOutput` | ❌ 送信しない | ✅ 送信 |
| `.completed` | - | invalidState エラー |

### decodeFinalOutput() の動作

#### .toolUse フェーズの場合

```
ツールあり？
├─ Yes → phase = .finalOutput(retryCount: 0)
│        → addFinalOutputRequest()
│        → .thinking を返す（次ステップで構造化出力要求）
│
└─ No → JSONデコード試行
        ├─ 成功 → phase = .completed → .finalResponse を返す
        └─ 失敗 → outputDecodingFailed エラー
```

#### .finalOutput フェーズの場合

```
JSONデコード試行
├─ 成功 → phase = .completed → .finalResponse を返す
│
└─ 失敗 → retryCount < maxDecodeRetries?
          ├─ Yes → retryCount + 1
          │        → addFinalOutputRequest()
          │        → .thinking を返す
          │
          └─ No → outputDecodingFailed エラーをスロー
```

#### .completed フェーズの場合

`nil` を返す（通常は到達しない）

## 終了ポリシーシステム

### プロバイダー間の差異への対応

異なる LLM プロバイダーは `stopReason` の扱いが異なります：

| プロバイダー | ツール呼び出し時の stopReason | 備考 |
|-------------|------------------------------|------|
| **Anthropic** | `.toolUse` | 明確に区別される |
| **OpenAI** | `.toolUse` (tool_calls) | 明確に区別される |
| **Gemini** | `.endTurn` (STOP) | 関数呼び出しでも STOP を返す |

この差異に対応するため、`StandardTerminationPolicy` は `.endTurn` の場合にもまずツール呼び出しの有無をチェックします。

### ポリシーの構造

```
入力: LLMResponse, AgentLoopContext
        │
        ▼
DuplicateDetectionPolicy
        │
        ▼
StandardTerminationPolicy
        │
        ▼
出力: TerminationDecision
```

### StandardTerminationPolicy の判定ロジック

| stopReason | 判定処理 |
|------------|----------|
| `.toolUse` | ツール抽出 → ツールあり: `continueWithTools` / なし: `terminateImmediately` |
| `.endTurn` | ツール抽出（※Gemini対応） → ツールあり: `continueWithTools` / なし: テキスト抽出 → `terminateWithOutput` or `completed` |
| `.maxTokens` | テキスト抽出 → あり: `terminateWithOutput` / なし: `terminateImmediately` |
| `.stopSequence` | テキスト抽出 → あり: `terminateWithOutput` / なし: `completed` |
| `nil` | フォールバック: ツール→テキスト→空の順でチェック |

### DuplicateDetectionPolicy の処理

重複するツール呼び出しを検出して無限ループを防止します：

```
ベースポリシーで判定
        │
        ▼
continueWithTools?
├─ No → そのまま返す
│
└─ Yes → 各ツール呼び出しをチェック
         │
         ▼
         入力の hashValue を計算
         → 重複回数をカウント
         │
         ▼
         count >= maxDuplicates?
         ├─ Yes → terminateImmediately(.duplicateToolCallDetected)
         └─ No → continueWithTools を返す
```

### TerminationDecision の種類

| Decision | 説明 | 次のアクション |
|----------|------|----------------|
| `continueWithTools([ToolCallInfo])` | ツール呼び出しを処理してループ継続 | ツール実行 → 次ステップ |
| `continueWithThinking` | 思考プロセスを返してループ継続 | `.thinking` を返す |
| `terminateWithOutput(String)` | テキストをデコードして終了 | `.finalResponse` を返す |
| `terminateImmediately(TerminationReason)` | 即座にループ終了 | `nil` を返す |

## 状態管理

### AgentLoopStateManager の役割

```
[初期化] init(configuration)
    │
    ▼
[Initialized]
    │ incrementStep()
    ▼
[Running] ◄─────────────────┐
    │                       │
    ├─ recordToolCall()  ───┘
    ├─ countDuplicateToolCalls()
    │
    ├─ currentStep >= maxSteps → [AtLimit] → エラーまたは終了
    │
    └─ markCompleted() → [Completed] → 終了
```

### ツール呼び出し履歴の追跡

1. `AgentLoopRunner` が `recordToolCall(call)` を呼び出し
2. `AgentLoopStateManager` が `ToolCallRecord` を作成（name, inputHash, timestamp）
3. `toolCallHistory` に追加
4. `DuplicateDetectionPolicy` が `countDuplicateToolCalls(name, inputHash)` でチェック
5. 重複回数に応じて継続/終了を判定

## イベントキューイング

ツール呼び出しが複数ある場合、イベントを順次返すためにキューイングを行います：

```swift
// LLM が 2 つのツールを要求した場合の流れ

// 1回目の nextStep()
// → .toolCall(call1) を返す

// 2回目の nextStep()
// → .toolResult(result1) を返す

// 3回目の nextStep()
// → .toolCall(call2) を返す

// 4回目の nextStep()
// → .toolResult(result2) を返す

// 5回目の nextStep()
// → キューが空なので次の LLM リクエストへ
```

## エラーハンドリング

### エラー種別と発生箇所

| エラー | 発生箇所 | 説明 |
|--------|----------|------|
| ``AgentError/maxStepsExceeded(steps:)`` | `nextStep()` | ステップ数が上限に達した |
| ``AgentError/llmError(_:)`` | `sendRequest()` | LLM API 呼び出し失敗 |
| ``AgentError/outputDecodingFailed(_:)`` | `decodeFinalOutput()` | JSON デコード失敗 |
| ``AgentError/toolNotFound(name:)`` | `AgentContext.executeTool()` | 指定ツールが存在しない |
| ``AgentError/toolExecutionFailed(name:underlyingError:)`` | `AgentContext.executeTool()` | ツール実行中のエラー |

### ツールエラーの扱い

ツール実行エラーは `ToolResultInfo` に `isError: true` で格納され、LLM に伝播させてリカバリを試行します。

## 設定パラメータ

### AgentConfiguration

| パラメータ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `maxSteps` | `Int` | 10 | 最大ステップ数（無限ループ防止） |
| `autoExecuteTools` | `Bool` | true | ツール自動実行の有効/無効 |
| `maxDuplicateToolCalls` | `Int` | 2 | 重複ツール呼び出しの許容回数（同一ツール・同一入力） |
| `maxToolCallsPerTool` | `Int?` | 5 | 同一ツールの最大総呼び出し回数。`nil` で無制限 |

### 無限ループ防止メカニズム

1. **ステップ数制限**: `maxSteps` を超えると ``AgentError/maxStepsExceeded(steps:)``
2. **重複検出**: 同一ツール・同一引数の呼び出しが `maxDuplicateToolCalls` を超えると終了
3. **総呼び出し回数制限**: 同一ツールが `maxToolCallsPerTool` 回を超えて呼ばれると終了
4. **stopReason 判定**: LLM の `endTurn` シグナルで正常終了
5. **デコード再試行**: JSON デコード失敗時は最大2回まで再試行

## Topics

### 型

- ``AgentStepSequence``
- ``AgentStep``
- ``AgentConfiguration``
- ``AgentContext``
- ``AgentError``
