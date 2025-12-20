# AgentBuilderExample 会話型エージェントUI 実装計画

## 1. 現状分析

### 1.1 AgentBuilderExample (現在)
- **ConversationView**: シングルショット生成 (`client.generate()`)
- 単一のプロンプト → 単一の結果
- ストリーミングなし
- 会話履歴なし

### 1.2 ConversationAgentExample
- **ConversationView**: 会話型エージェント (`ConversationalAgentSession`)
- 複数ターンの対話
- ストリーミング出力（フェーズごと）
- インタラクティブモード（AI質問への回答）
- セッション管理・永続化

## 2. 共通化可能なコンポーネント

### 2.1 ExamplesCommon に移行すべき（汎用UI）

| コンポーネント | 現在の場所 | 説明 | 移行難易度 |
|---------------|-----------|------|-----------|
| **InputField** | ConversationAgentExample | 設定駆動型の入力フィールド | ◎ 容易 |
| **CollapsibleText** | ConversationAgentExample | 折りたたみテキスト | ◎ 容易 |
| **ExecutionProgressBanner** | ConversationAgentExample | 実行進捗バナー | ○ 中程度 |

### 2.2 既に ExamplesCommon にあるもの

| コンポーネント | 状態 | 備考 |
|---------------|------|------|
| ErrorBanner | ✓ 存在 | リトライ機能なし版 |
| ExecutionLogView | ✓ 存在 | ログ表示用 |
| APIKeyField | ✓ 存在 | APIキー入力用 |
| DateFormatter.logTimestamp | ✓ 存在 | ログ用タイムスタンプ |

### 2.3 共通化困難（アプリ固有ロジック）

| コンポーネント | 理由 |
|---------------|------|
| StepRow | ステップ型が異なる（ConversationalAgentStep vs カスタム） |
| ActiveSessionBar | セッション管理方式が異なる |
| QuestionBanner | インタラクティブモード固有 |
| ResultView | 出力型が異なる（Markdown vs DynamicStructuredResult） |

## 3. 実装アプローチ選択

### オプション A: 完全な会話型エージェント実装
ConversationAgentExample と同等の機能を実装

**必要なもの:**
- ConversationalAgentSession を使用
- DynamicStructured を outputType として使用
- ストリーミング処理
- インタラクティブモード対応

**メリット:** フル機能
**デメリット:** 実装量大、共通化難しい

### オプション B: 簡易版ストリーミング実装（推奨）
シングルショットのまま、進捗表示とストリーミングを追加

**必要なもの:**
- LLMClient のストリーミングAPI使用
- 進捗バナー追加
- ステップ表示（生成開始 → 生成中 → 完了）

**メリット:** 実装シンプル、UIは充実
**デメリット:** 会話継続不可

### オプション C: ハイブリッド実装
AgentBuilderExample 固有の軽量会話型エージェント

**必要なもの:**
- SimpleAgentSession（新規作成）
- DynamicStructured 専用のステップ管理
- 最小限のインタラクティブモード

**メリット:** バランスが良い
**デメリット:** 新規設計が必要

## 4. 推奨実装計画（オプション B: 簡易版ストリーミング）

### Phase 1: 共通コンポーネントの ExamplesCommon 移行

```
ExamplesCommon/Sources/Presentation/
├── CommonComponents.swift (既存)
├── InputField.swift (新規追加)
├── CollapsibleText.swift (新規追加)
└── ExecutionProgressBanner.swift (新規追加)
```

#### 1.1 InputField の移行
- Configuration パターンを維持
- アプリ固有の InputMode は除外

#### 1.2 CollapsibleText の移行
- そのまま移行可能

#### 1.3 ExecutionProgressBanner の移行
- フェーズ型を汎用化（enum ExecutionPhase）

### Phase 2: AgentBuilderExample UI の強化

```
AgentBuilderExample/Presentation/Views/
└── ConversationView.swift (更新)
    - ExecutionProgressBanner 追加
    - ステップ表示追加
    - 結果表示の改善
```

#### 2.1 状態管理の追加

```swift
enum ExecutionPhase {
    case idle
    case preparing
    case generating
    case completed
    case error(String)
}

@State private var phase: ExecutionPhase = .idle
```

#### 2.2 UI構成の更新

```
┌─────────────────────────────────────┐
│ TypeInfoHeader                      │
├─────────────────────────────────────┤
│ ExecutionProgressBanner (生成中)    │
├─────────────────────────────────────┤
│ StepList                            │
│ - 準備完了                          │
│ - 生成中...                         │
│ - 完了                              │
├─────────────────────────────────────┤
│ ResultSection (完了時)              │
├─────────────────────────────────────┤
│ ErrorSection (エラー時)             │
├─────────────────────────────────────┤
│ InputField                          │
└─────────────────────────────────────┘
```

### Phase 3: 結果表示の改善

- JSON形式での結果表示オプション
- フィールドごとの展開/折りたたみ
- コピー機能

## 5. ファイル変更一覧

### ExamplesCommon (追加)
1. `Sources/Presentation/InputField.swift`
2. `Sources/Presentation/CollapsibleText.swift`
3. `Sources/Presentation/ExecutionProgressBanner.swift`
4. `Sources/Domain/ExecutionPhase.swift`

### AgentBuilderExample (更新)
1. `Presentation/Views/ConversationView.swift` - 大幅更新
2. `Domain/ConversationState.swift` - 新規（状態管理）

### ConversationAgentExample (更新)
1. ローカルの InputField 等を削除
2. ExamplesCommon からインポート

## 6. 実装順序

1. **ExamplesCommon に InputField を移行**
   - ConversationAgentExample からコピー
   - Configuration の汎用化

2. **ExamplesCommon に CollapsibleText を移行**
   - そのまま移行

3. **ExamplesCommon に ExecutionProgressBanner を移行**
   - フェーズ型の汎用化
   - アニメーションロジックの維持

4. **AgentBuilderExample の ConversationView を更新**
   - ExamplesCommon のコンポーネントを使用
   - ステップ表示の追加
   - 進捗バナーの追加

5. **ConversationAgentExample を更新**
   - ローカルコンポーネントを ExamplesCommon に置き換え

6. **両アプリのビルド確認**

## 7. 注意事項

### 7.1 型の違い
- ConversationAgentExample: `AgentOutputType` (Research/Summary/CodeReview)
- AgentBuilderExample: `BuiltType` (動的型定義)

→ 共通化する際は型パラメータまたはプロトコルで抽象化

### 7.2 セッション管理
- ConversationAgentExample: 永続化あり（SessionData, SessionRepository）
- AgentBuilderExample: 永続化なし（画面閉じたら終了）

→ セッション管理は共通化しない

### 7.3 インタラクティブモード
- ConversationAgentExample: あり（AI質問への回答）
- AgentBuilderExample: なし（シングルショット）

→ QuestionBanner 等は共通化しない
