# エージェントループ 内部実装ガイド

このドキュメントでは、エージェントループの内部実装フローを詳細に解説します。

> **Note**: 外部向け API は `AgentStepStream` プロトコルです。
> 内部実装の `AgentStepSequence` や `AgentLoopRunner` は直接参照できません。

## 目次

1. [アーキテクチャ概要](#アーキテクチャ概要)
2. [コンポーネント構成](#コンポーネント構成)
3. [メインループフロー](#メインループフロー)
4. [終了ポリシーシステム](#終了ポリシーシステム)
5. [状態管理](#状態管理)
6. [イベントキューイング](#イベントキューイング)
7. [エラーハンドリング](#エラーハンドリング)

---

## アーキテクチャ概要

エージェントループは以下のレイヤーで構成されています：

```mermaid
graph TB
    subgraph "Public API Layer"
        ASP[AgentStepStream<br/>Protocol]
    end

    subgraph "Internal Implementation Layer"
        ASS[AgentStepSequence<br/>AsyncSequence]
        ALR[AgentLoopRunner<br/>Actor]
    end

    subgraph "Policy Layer"
        TP[TerminationPolicy<br/>Protocol]
        STP[StandardTerminationPolicy]
        DDP[DuplicateDetectionPolicy]
    end

    subgraph "State Layer"
        AC[AgentContext<br/>Actor]
        ALSM[AgentLoopStateManager<br/>Actor]
    end

    subgraph "External"
        LLM[LLM Client]
        TOOLS[ToolSet]
    end

    ASP --> ASS
    ASS --> ALR
    ALR --> TP
    TP --> STP
    TP --> DDP
    ALR --> AC
    ALR --> ALSM
    ALR --> LLM
    AC --> TOOLS
```

### 設計原則

- **Actor による並行安全性**: 状態管理は全て Actor で保護
- **Strategy Pattern**: 終了条件判定はポリシーとして抽象化
- **Decorator Pattern**: 重複検出は標準ポリシーをラップして拡張
- **AsyncSequence**: ストリーミング形式でステップを提供

---

## コンポーネント構成

### ファイル構成

```
Sources/LLMStructuredOutputs/Agent/
├── AgentStepStream.swift        # 公開プロトコル
├── AgentContext.swift           # メッセージ履歴・ツール管理
├── AgentTypes.swift             # 型定義（AgentStep, AgentError 等）
└── Internal/                    # 内部実装
    ├── AgentStepSequence.swift      # 内部実装の AsyncSequence
    ├── AgentLoopRunner.swift        # ループ実行 Actor
    ├── AgentTerminationPolicy.swift # 終了ポリシープロトコルと実装
    └── AgentLoopState.swift         # 状態管理 Actor
```

### コンポーネント関係図

```mermaid
classDiagram
    class AgentStepStream~Output~ {
        <<protocol>>
        +Element = AgentStep~Output~
    }

    class AgentStepSequence~Client,Output~ {
        <<internal>>
        -client: Client
        -model: Client.Model
        -context: AgentContext
        +makeAsyncIterator() AsyncIterator
    }

    class AsyncIterator {
        -runner: AgentLoopRunner
        +next() AgentStep?
    }

    class AgentLoopRunner~Client,Output~ {
        <<internal actor>>
        -client: Client
        -model: Client.Model
        -context: AgentContext
        -terminationPolicy: AgentTerminationPolicy
        -stateManager: AgentLoopStateManager
        -pendingEvents: [PendingEvent]
        -phase: LoopPhase
        +nextStep() AgentStep?
    }

    class AgentTerminationPolicy {
        <<protocol>>
        +shouldTerminate(response, context) TerminationDecision
    }

    class AgentLoopStateManager {
        <<actor>>
        -currentStep: Int
        -maxSteps: Int
        -toolCallHistory: [ToolCallRecord]
        +incrementStep()
        +recordToolCall(call)
        +countDuplicateToolCalls(name, inputHash)
    }

    class AgentContext {
        <<actor>>
        -messages: [LLMMessage]
        -tools: ToolSet
        +addAssistantResponse(response)
        +addToolResults(results)
        +executeTool(name, input)
    }

    AgentStepStream <|.. AgentStepSequence : implements
    AgentStepSequence --> AsyncIterator
    AsyncIterator --> AgentLoopRunner
    AgentLoopRunner --> AgentTerminationPolicy
    AgentLoopRunner --> AgentLoopStateManager
    AgentLoopRunner --> AgentContext
```

---

## メインループフロー

### nextStep() の処理フロー

`AgentLoopRunner.nextStep()` が呼ばれるたびに以下の処理が実行されます：

```mermaid
flowchart TD
    START([nextStep 呼び出し]) --> CHECK_PENDING{保留中の<br/>イベントあり?}

    CHECK_PENDING -->|Yes| RETURN_PENDING[保留イベントを返す]
    RETURN_PENDING --> END_STEP([ステップ終了])

    CHECK_PENDING -->|No| CHECK_COMPLETED{ループ<br/>完了済み?}
    CHECK_COMPLETED -->|Yes| RETURN_NIL[nil を返す]
    RETURN_NIL --> END_STEP

    CHECK_COMPLETED -->|No| CHECK_LIMIT{ステップ<br/>上限到達?}
    CHECK_LIMIT -->|Yes| THROW_ERROR[maxStepsExceeded<br/>エラーをスロー]
    THROW_ERROR --> END_STEP

    CHECK_LIMIT -->|No| INCREMENT[ステップをインクリメント]
    INCREMENT --> SEND_REQUEST[LLM にリクエスト送信]
    SEND_REQUEST --> ADD_RESPONSE[レスポンスを<br/>コンテキストに追加]
    ADD_RESPONSE --> EVALUATE_POLICY[終了ポリシーで判定]
    EVALUATE_POLICY --> HANDLE_DECISION[判定結果を処理]
    HANDLE_DECISION --> END_STEP
```

### 判定結果の処理分岐

```mermaid
flowchart TD
    DECISION{TerminationDecision}

    DECISION -->|continueWithTools| PROCESS_TOOLS[ツール呼び出しを処理]
    PROCESS_TOOLS --> RECORD_CALLS[履歴に記録]
    RECORD_CALLS --> QUEUE_EVENTS[イベントをキュー]
    QUEUE_EVENTS --> EXECUTE_TOOLS[ツールを実行]
    EXECUTE_TOOLS --> ADD_RESULTS[結果をコンテキストに追加]
    ADD_RESULTS --> RETURN_FIRST[最初のイベントを返す]

    DECISION -->|continueWithThinking| RETURN_THINKING[.thinking を返す]

    DECISION -->|terminateWithOutput| CHECK_PHASE{最終出力<br/>フェーズ?}
    CHECK_PHASE -->|No, ツールあり| TRANSITION_PHASE[最終出力フェーズへ遷移]
    TRANSITION_PHASE --> RETURN_THINKING2[.thinking を返す]
    CHECK_PHASE -->|Yes or ツールなし| DECODE_OUTPUT[JSON デコード試行]
    DECODE_OUTPUT -->|成功| RETURN_FINAL[.finalResponse を返す]
    DECODE_OUTPUT -->|失敗, リトライ可| RETURN_THINKING3[.thinking を返す]
    DECODE_OUTPUT -->|失敗, リトライ上限| THROW_DECODE_ERROR[outputDecodingFailed<br/>エラーをスロー]

    DECISION -->|terminateImmediately| MARK_COMPLETE[完了フラグを立てる]
    MARK_COMPLETE --> RETURN_NIL2[nil を返す]
```

---

## 構造化出力フェーズ管理

Anthropic の推奨パターンに従い、エージェントループは2つのフェーズを持ちます：

### フェーズの種類（LoopPhase enum）

```mermaid
stateDiagram-v2
    [*] --> toolUse: ループ開始
    toolUse --> toolUse: ツール呼び出し継続
    toolUse --> finalOutput: endTurn + ツールあり
    toolUse --> completed: ツールなし + デコード成功
    finalOutput --> finalOutput: デコード失敗 (リトライ)
    finalOutput --> completed: デコード成功
    completed --> [*]: nil を返す
```

| LoopPhase | associated value | 説明 |
|-----------|------------------|------|
| `.toolUse` | なし | LLMがツールを呼び出し可能。responseSchemaは送信しない |
| `.finalOutput(retryCount: Int)` | リトライ回数 | ツールを無効化し、responseSchemaを送信。デコード再試行を追跡 |
| `.completed` | なし | ループ完了状態 |

| フェーズ | responseSchema | tools | 説明 |
|---------|---------------|-------|------|
| **ツール使用フェーズ** | 送らない | 送る | LLMがツールを自由に呼び出せる |
| **最終出力フェーズ** | 送る | 送らない | 構造化JSONを要求 |

### なぜフェーズを分けるのか

ツール使用中に `responseSchema` を送ると、以下の問題が発生します：

1. LLMがテキスト応答を返した際、JSONとして解釈できずデコードエラー
2. 「Failed to decode output」エラーが頻発

**解決策**: Anthropic の Combined Usage パターンに従い：
- ツールが使用可能な間 → `responseSchema` を送らない
- ツールなし、または最終出力フェーズ → `responseSchema` を送る

### sendRequest() の動作

```mermaid
flowchart TD
    START([sendRequest]) --> CHECK_PHASE{phase?}

    CHECK_PHASE -->|.toolUse| CHECK_TOOLS{ツールあり?}
    CHECK_TOOLS -->|Yes| TOOL_REQ[ツール + responseSchemaなし]
    TOOL_REQ --> SEND2[リクエスト送信]
    CHECK_TOOLS -->|No| DIRECT_REQ[ツールなし + responseSchema]
    DIRECT_REQ --> SEND3[リクエスト送信]

    CHECK_PHASE -->|.finalOutput| FINAL_REQ[ツールなし + responseSchema]
    FINAL_REQ --> SEND1[リクエスト送信]

    CHECK_PHASE -->|.completed| THROW_ERROR[invalidState エラー]
```

### decodeFinalOutput() の動作

```mermaid
flowchart TD
    START([decodeFinalOutput]) --> CHECK_PHASE{phase?}

    %% .toolUse フェーズ
    CHECK_PHASE -->|.toolUse| CHECK_TOOLS{ツールあり?}
    CHECK_TOOLS -->|Yes| TRANSITION[phase = .finalOutput]
    TRANSITION --> ADD_REQ1[addFinalOutputRequest]
    ADD_REQ1 --> RETURN_THINKING[.thinking を返す]

    CHECK_TOOLS -->|No| DECODE_TOOLUSE[JSONデコード試行]
    DECODE_TOOLUSE -->|成功| SET_COMPLETE1[phase = .completed]
    SET_COMPLETE1 --> RETURN_FINAL1[.finalResponse を返す]

    %% .finalOutput フェーズ
    CHECK_PHASE -->|.finalOutput| DECODE_FINAL[JSONデコード試行]
    DECODE_FINAL -->|成功| SET_COMPLETE2[phase = .completed]
    SET_COMPLETE2 --> RETURN_FINAL2[.finalResponse を返す]
    DECODE_FINAL -->|失敗| CHECK_RETRY{retryCount<br/>< maxDecodeRetries?}
    CHECK_RETRY -->|Yes| INCREMENT[retryCount + 1]
    INCREMENT --> ADD_REQ2[addFinalOutputRequest]
    ADD_REQ2 --> RETURN_THINKING2[.thinking を返す]
    CHECK_RETRY -->|No| THROW_ERROR[outputDecodingFailed<br/>エラーをスロー]

    %% .completed フェーズ
    CHECK_PHASE -->|.completed| RETURN_NIL[nil を返す]
```

---

## 終了ポリシーシステム

### プロバイダー間の差異への対応

異なる LLM プロバイダーは `stopReason` の扱いが異なります：

| プロバイダー | ツール呼び出し時の stopReason | 備考 |
|-------------|------------------------------|------|
| **Anthropic** | `.toolUse` | 明確に区別される |
| **OpenAI** | `.toolUse` (tool_calls) | 明確に区別される |
| **Gemini** | `.endTurn` (STOP) | 関数呼び出しでも STOP を返す |

この差異に対応するため、`StandardTerminationPolicy` は `.endTurn` の場合にも
まずツール呼び出しの有無をチェックします。

### ポリシーの構造

```mermaid
graph LR
    subgraph "デフォルト構成"
        DDP[DuplicateDetectionPolicy] --> STP[StandardTerminationPolicy]
    end

    subgraph "入力"
        RESP[LLMResponse]
        CTX[AgentLoopContext]
    end

    subgraph "出力"
        TD[TerminationDecision]
    end

    RESP --> DDP
    CTX --> DDP
    DDP --> TD
```

### StandardTerminationPolicy の判定ロジック

`stopReason` に基づいて終了/継続を判定します：

```mermaid
flowchart TD
    START([判定開始]) --> CHECK_LIMIT{ステップ<br/>上限到達?}

    CHECK_LIMIT -->|Yes| TERMINATE_LIMIT[terminateImmediately<br/>maxStepsReached]

    CHECK_LIMIT -->|No| CHECK_STOP{stopReason?}

    CHECK_STOP -->|.toolUse| EXTRACT_TOOLS[ツール呼び出しを抽出]
    EXTRACT_TOOLS --> HAS_TOOLS{ツールあり?}
    HAS_TOOLS -->|Yes| CONTINUE_TOOLS[continueWithTools]
    HAS_TOOLS -->|No| TERMINATE_UNEXPECTED[terminateImmediately<br/>unexpectedStopReason]

    CHECK_STOP -->|.endTurn| CHECK_ENDTURN_TOOLS[ツール呼び出しを抽出<br/>※Gemini対応]
    CHECK_ENDTURN_TOOLS --> HAS_ENDTURN_TOOLS{ツールあり?}
    HAS_ENDTURN_TOOLS -->|Yes| CONTINUE_TOOLS3[continueWithTools]
    HAS_ENDTURN_TOOLS -->|No| EXTRACT_TEXT[テキストを抽出]
    EXTRACT_TEXT --> HAS_TEXT{テキストあり?}
    HAS_TEXT -->|Yes| TERMINATE_OUTPUT[terminateWithOutput]
    HAS_TEXT -->|No| TERMINATE_COMPLETE[terminateImmediately<br/>completed]

    CHECK_STOP -->|.maxTokens| EXTRACT_TEXT2[テキストを抽出]
    EXTRACT_TEXT2 --> HAS_TEXT2{テキストあり?}
    HAS_TEXT2 -->|Yes| TERMINATE_OUTPUT2[terminateWithOutput]
    HAS_TEXT2 -->|No| TERMINATE_MAX[terminateImmediately<br/>unexpectedStopReason]

    CHECK_STOP -->|.stopSequence| EXTRACT_TEXT3[テキストを抽出]
    EXTRACT_TEXT3 --> HAS_TEXT3{テキストあり?}
    HAS_TEXT3 -->|Yes| TERMINATE_OUTPUT3[terminateWithOutput]
    HAS_TEXT3 -->|No| TERMINATE_SEQ[terminateImmediately<br/>completed]

    CHECK_STOP -->|nil| FALLBACK[フォールバック処理]
    FALLBACK --> CHECK_FALLBACK_TOOLS{ツールあり?}
    CHECK_FALLBACK_TOOLS -->|Yes| CONTINUE_TOOLS2[continueWithTools]
    CHECK_FALLBACK_TOOLS -->|No| CHECK_FALLBACK_TEXT{テキストあり?}
    CHECK_FALLBACK_TEXT -->|Yes| TERMINATE_OUTPUT4[terminateWithOutput]
    CHECK_FALLBACK_TEXT -->|No| TERMINATE_EMPTY[terminateImmediately<br/>emptyResponse]
```

### DuplicateDetectionPolicy の処理

重複するツール呼び出しを検出して無限ループを防止します：

```mermaid
flowchart TD
    START([判定開始]) --> BASE_POLICY[ベースポリシーで判定]
    BASE_POLICY --> CHECK_CONTINUE{continueWithTools?}

    CHECK_CONTINUE -->|No| RETURN_AS_IS[そのまま返す]

    CHECK_CONTINUE -->|Yes| LOOP_CALLS[各ツール呼び出しをチェック]
    LOOP_CALLS --> CALC_HASH[入力の hashValue を計算]
    CALC_HASH --> COUNT_DUPS[重複回数をカウント]
    COUNT_DUPS --> CHECK_DUP{count >= maxDuplicates?}

    CHECK_DUP -->|Yes| TERMINATE_DUP[terminateImmediately<br/>duplicateToolCallDetected]
    CHECK_DUP -->|No| NEXT_CALL{次のツール?}
    NEXT_CALL -->|Yes| LOOP_CALLS
    NEXT_CALL -->|No| RETURN_CONTINUE[continueWithTools を返す]
```

### TerminationDecision の種類

| Decision | 説明 | 次のアクション |
|----------|------|----------------|
| `continueWithTools([ToolCallInfo])` | ツール呼び出しを処理してループ継続 | ツール実行 → 次ステップ |
| `continueWithThinking` | 思考プロセスを返してループ継続 | `.thinking` を返す |
| `terminateWithOutput(String)` | テキストをデコードして終了 | `.finalResponse` を返す |
| `terminateImmediately(TerminationReason)` | 即座にループ終了 | `nil` を返す |

---

## 状態管理

### AgentLoopStateManager の役割

```mermaid
stateDiagram-v2
    [*] --> Initialized: init(configuration)

    Initialized --> Running: incrementStep()
    Running --> Running: incrementStep()
    Running --> AtLimit: currentStep >= maxSteps
    Running --> Completed: markCompleted()
    AtLimit --> [*]: エラーまたは終了
    Completed --> [*]

    state Running {
        [*] --> Recording
        Recording --> Recording: recordToolCall()
        Recording --> Counting: countDuplicateToolCalls()
        Counting --> Recording
    }
```

### ツール呼び出し履歴の追跡

```mermaid
sequenceDiagram
    participant ALR as AgentLoopRunner
    participant ALSM as AgentLoopStateManager
    participant DDP as DuplicateDetectionPolicy

    ALR->>ALSM: recordToolCall(call)
    Note over ALSM: ToolCallRecord を作成<br/>(name, inputHash, timestamp)
    ALSM-->>ALSM: toolCallHistory に追加

    ALR->>DDP: shouldTerminate(response, context)
    DDP->>ALSM: countDuplicateToolCalls(name, inputHash)
    ALSM-->>DDP: 重複回数を返す

    alt 重複回数 >= maxDuplicates
        DDP-->>ALR: terminateImmediately(.duplicateToolCallDetected)
    else 重複回数 < maxDuplicates
        DDP-->>ALR: continueWithTools
    end
```

---

## イベントキューイング

ツール呼び出しが複数ある場合、イベントを順次返すためにキューイングを行います：

```mermaid
sequenceDiagram
    participant User as 呼び出し元
    participant ALR as AgentLoopRunner
    participant Queue as pendingEvents
    participant AC as AgentContext

    User->>ALR: nextStep()
    Note over ALR: LLM が 2 つのツールを要求

    loop 各ツール呼び出し
        ALR->>Queue: append(.toolCall(call))
        ALR->>AC: executeTool(name, input)
        AC-->>ALR: result
        ALR->>Queue: append(.toolResult(result))
    end

    ALR->>AC: addToolResults(results)
    ALR->>Queue: removeFirst()
    Queue-->>ALR: .toolCall(call1)
    ALR-->>User: .toolCall(call1)

    User->>ALR: nextStep()
    ALR->>Queue: removeFirst()
    Queue-->>ALR: .toolResult(result1)
    ALR-->>User: .toolResult(result1)

    User->>ALR: nextStep()
    ALR->>Queue: removeFirst()
    Queue-->>ALR: .toolCall(call2)
    ALR-->>User: .toolCall(call2)

    User->>ALR: nextStep()
    ALR->>Queue: removeFirst()
    Queue-->>ALR: .toolResult(result2)
    ALR-->>User: .toolResult(result2)

    User->>ALR: nextStep()
    Note over ALR: キューが空なので<br/>次の LLM リクエストへ
```

---

## エラーハンドリング

### エラーフロー図

```mermaid
flowchart TD
    subgraph LLM_REQ["LLM リクエスト"]
        SEND[sendRequest]
        SEND -->|LLMError| WRAP_LLM[AgentError.llmError でラップ]
    end

    subgraph STEP_MGR["ステップ管理"]
        INCREMENT[incrementStep]
        INCREMENT -->|上限超過| MAX_STEPS[AgentError.maxStepsExceeded]
    end

    subgraph TOOL_EXEC["ツール実行"]
        EXEC[executeToolSafely]
        EXEC -->|エラー| SAFE_RESULT["ToolResultInfo に<br/>isError: true で格納<br/>(LLM にリカバリを試行させる)"]
    end

    subgraph OUTPUT_DEC["出力デコード"]
        DECODE[decodeFinalOutput]
        DECODE -->|失敗| DECODE_ERROR[AgentError.outputDecodingFailed]
    end
```

### エラー種別と発生箇所

| エラー | 発生箇所 | 説明 |
|--------|----------|------|
| `maxStepsExceeded` | `nextStep()` | ステップ数が上限に達した |
| `llmError` | `sendRequest()` | LLM API 呼び出し失敗 |
| `outputDecodingFailed` | `decodeFinalOutput()` | JSON デコード失敗 |
| `toolNotFound` | `AgentContext.executeTool()` | 指定ツールが存在しない |
| `toolExecutionFailed` | `AgentContext.executeTool()` | ツール実行中のエラー |

---

## 完全なシーケンス例

### 天気検索の完全フロー

```mermaid
sequenceDiagram
    participant U as User
    participant ASS as AgentStepSequence
    participant ALR as AgentLoopRunner
    participant TP as TerminationPolicy
    participant ALSM as StateManager
    participant AC as AgentContext
    participant LLM as LLM API
    participant Tool as GetWeather

    U->>ASS: for await step in sequence
    ASS->>ALR: nextStep()

    Note over ALR: ステップ 1
    ALR->>ALSM: incrementStep()
    ALR->>AC: getMessages(), getTools()
    ALR->>LLM: executeAgentStep()
    LLM-->>ALR: Response (stopReason: .toolUse)
    ALR->>AC: addAssistantResponse()
    ALR->>TP: shouldTerminate()
    TP-->>ALR: continueWithTools([GetWeather])

    ALR->>ALSM: recordToolCall(GetWeather)
    ALR->>Tool: call() with {"location": "Tokyo"}
    Tool-->>ALR: "Tokyo: 晴れ、25°C"
    ALR->>AC: addToolResults()
    ALR-->>ASS: .toolCall(GetWeather)
    ASS-->>U: step = .toolCall

    U->>ASS: 次のイテレーション
    ASS->>ALR: nextStep()
    ALR-->>ASS: .toolResult("Tokyo: 晴れ、25°C")
    ASS-->>U: step = .toolResult

    U->>ASS: 次のイテレーション
    ASS->>ALR: nextStep()

    Note over ALR: ステップ 2
    ALR->>ALSM: incrementStep()
    ALR->>LLM: executeAgentStep()
    LLM-->>ALR: Response (stopReason: .endTurn, JSON output)
    ALR->>AC: addAssistantResponse()
    ALR->>TP: shouldTerminate()
    TP-->>ALR: terminateWithOutput(json)

    ALR->>ALR: JSONDecoder.decode()
    ALR-->>ASS: .finalResponse(WeatherReport)
    ASS-->>U: step = .finalResponse

    U->>ASS: 次のイテレーション
    ASS->>ALR: nextStep()
    ALR-->>ASS: nil
    ASS-->>U: ループ終了
```

---

## 設定パラメータ

### AgentConfiguration

| パラメータ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `maxSteps` | `Int` | 10 | 最大ステップ数（無限ループ防止） |
| `autoExecuteTools` | `Bool` | true | ツール自動実行の有効/無効 |
| `maxDuplicateToolCalls` | `Int` | 2 | 重複ツール呼び出しの許容回数（同一ツール・同一入力） |
| `maxToolCallsPerTool` | `Int?` | 5 | 同一ツールの最大総呼び出し回数（異なる引数でも）。`nil` で無制限 |

### 無限ループ防止メカニズム

1. **ステップ数制限**: `maxSteps` を超えると `AgentError.maxStepsExceeded`
2. **重複検出**: 同一ツール・同一引数の呼び出しが `maxDuplicateToolCalls` を超えると終了
3. **総呼び出し回数制限**: 同一ツールが `maxToolCallsPerTool` 回を超えて呼ばれると終了（異なる引数でも）
4. **stopReason 判定**: LLM の `endTurn` シグナルで正常終了
5. **デコード再試行**: JSON デコード失敗時は最大2回まで再試行（`.thinking` として返して LLM に再度要求）

---

## 参照

- [エージェントループ 使用ガイド](agent-loop.md) - 基本的な使い方
- [ツールコール](tool-calling.md) - ツール定義の詳細
- [はじめに](getting-started.md) - セットアップ手順
