# LLMStructuredOutputs Integration Tests

実際のLLMプロバイダーAPIを使用して、`LLMStructuredOutputs`パッケージのすべての機能をテストする実行可能なSwiftパッケージです。

## 機能

以下の機能を3つのプロバイダー（Anthropic/OpenAI/Gemini）それぞれでテストします：

1. **基本的な構造化出力** - `@Structured`マクロによるデータ抽出
2. **Enum対応** - Swift enumの自動変換
3. **ネスト構造** - 配列やネストした構造体
4. **システムプロンプト** - カスタムシステムプロンプトの使用
5. **Prompt DSL** - `Prompt`ビルダーによるプロンプト構築
6. **イベントストリーム** - `chatStream()`によるストリーミング
7. **会話履歴** - `ConversationHistory`による複数ターンの会話

## セットアップ

### 1. APIキーの設定

`.env.example`をコピーして`.env`ファイルを作成し、APIキーを設定します：

```bash
cp .env.example .env
```

`.env`ファイルを編集：

```
ANTHROPIC_API_KEY=sk-ant-your-key-here
OPENAI_API_KEY=sk-your-key-here
GEMINI_API_KEY=AIza-your-key-here
```

### 2. 実行

```bash
swift run
```

または環境変数を直接指定：

```bash
ANTHROPIC_API_KEY=xxx OPENAI_API_KEY=xxx GEMINI_API_KEY=xxx swift run
```

## 出力例

```
╔══════════════════════════════════════════════════════════════╗
║     LLMStructuredOutputs Integration Tests                   ║
║     Testing all providers and features                       ║
╚══════════════════════════════════════════════════════════════╝

📋 API Key Status:
   ANTHROPIC_API_KEY: ✅ Set
   OPENAI_API_KEY:    ✅ Set
   GEMINI_API_KEY:    ✅ Set

============================================================
🟠 ANTHROPIC (Claude) Tests
============================================================

🧪 Testing: Basic Person Extraction
   --------------------------------------------------
   ✅ PASSED
   Result:
      {
        "age": 35,
        "name": "John Smith",
        "occupation": "software engineer"
      }

...

============================================================
📊 TEST SUMMARY
============================================================
   ✅ Passed:  21
   ❌ Failed:  0
   ⏭️  Skipped: 0
============================================================

🎉 All executed tests passed!
```

## 注意事項

- `.env`ファイルはGitにコミットされません（`.gitignore`に設定済み）
- 各テストはAPIを呼び出すため、料金が発生します
- レートリミットに注意してください
