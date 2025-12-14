# LLMStructuredOutputsExample

`swift-llm-structured-outputs` パッケージの機能を体験できるiOSサンプルアプリです。

## 機能

- **基本の構造化出力**: `@Structured` マクロの基本的な使い方
- **フィールド制約**: minimum/maximum、文字数制限、配列サイズ制限など
- **Enum対応**: `@StructuredEnum` マクロによるカテゴリ分類
- **Prompt DSL**: 構造化プロンプトの宣言的な構築
- **Prompt Builder**: インタラクティブなプロンプト構築UI
- **マルチターン会話**: 会話履歴を活用した文脈理解
- **イベントストリーム**: リアルタイムイベント監視
- **プロバイダー比較**: Anthropic/OpenAI/Gemini の並列実行と比較

## セットアップ

### 1. プロジェクトを開く

```bash
open LLMStructuredOutputsExample.xcodeproj
```

### 2. APIキーを設定

**重要**: APIキーは絶対にソースコードやスキームファイルに直接記述しないでください。

#### 方法A: Xcodeの環境変数（推奨）

1. Xcode で **Product > Scheme > Edit Scheme...** を開く（⌘ + <）
2. 左側で **Run** を選択
3. **Arguments** タブを選択
4. **Environment Variables** セクションで以下を追加:

| Name | Value |
|------|-------|
| `ANTHROPIC_API_KEY` | あなたのAnthropic APIキー |
| `OPENAI_API_KEY` | あなたのOpenAI APIキー |
| `GEMINI_API_KEY` | あなたのGoogle Gemini APIキー |

> ⚠️ この設定はローカルの `xcuserdata` に保存され、Gitにコミットされません。

#### 方法B: シェル環境変数

ターミナルから Xcode を起動する場合：

```bash
export ANTHROPIC_API_KEY="your-key-here"
export OPENAI_API_KEY="your-key-here"
export GEMINI_API_KEY="your-key-here"
open LLMStructuredOutputsExample.xcodeproj
```

### 3. ビルドと実行

1. シミュレータまたは実機を選択
2. **Run**（⌘ + R）でアプリを起動

## APIキーの取得

- **Anthropic**: https://console.anthropic.com/
- **OpenAI**: https://platform.openai.com/api-keys
- **Google AI**: https://aistudio.google.com/apikey

## セキュリティに関する注意

- APIキーは **絶対に** Gitリポジトリにコミットしないでください
- スキームファイル（`.xcscheme`）に環境変数の値を直接設定しないでください
- 環境変数は Xcode の Edit Scheme から設定すると `xcuserdata` に保存され、`.gitignore` で除外されます

## トラブルシューティング

### APIキーが認識されない

- Xcode を再起動してみてください
- Edit Scheme で環境変数が正しく設定されているか確認してください
- アプリ内の「設定」画面でAPIキーの状態を確認できます

### ビルドエラー

Swift Package Manager の依存関係を更新してください：

```bash
# Xcode メニューから
File > Packages > Reset Package Caches
File > Packages > Resolve Package Versions
```
