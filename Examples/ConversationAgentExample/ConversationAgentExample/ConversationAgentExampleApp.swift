import SwiftUI

/// ConversationAgentExample アプリ
///
/// このサンプルアプリは `ConversationalAgentSession` と `LLMToolkits` を活用した
/// エージェント機能をデモンストレーションします。
///
/// ## 主な機能
///
/// 1. **LLMToolkits 統合**
///    - プリセット（ResearcherPreset, WriterPreset, CodingAssistantPreset）
///    - 共通出力型（AnalysisResult, Summary, CodeReview）
///    - 組み込みツール（TextAnalysisTool）
///
/// 2. **3つのシナリオ**
///    - リサーチ: Web検索による詳細調査 → AnalysisResult
///    - 記事要約: URLから記事を要約 → Summary
///    - コードレビュー: コードの品質評価 → CodeReview
///
/// 3. **マルチターン会話**
///    - 複数回のやり取りを通じた調査
///    - 前の会話を踏まえたフォローアップ
///
/// 4. **イベントストリーミング**
///    - セッションイベントのリアルタイム監視
///    - ステップごとの進捗表示
///
/// 5. **割り込み機能**
///    - 実行中のエージェントへの追加指示
///    - 動的な方向転換
///
/// ## 使用方法
///
/// 1. 設定画面で Anthropic API キーを設定
/// 2. 必要に応じて Brave Search API キーを設定（リサーチ用）
/// 3. 出力タイプを選択（リサーチ / 記事要約 / コードレビュー）
/// 4. プロンプトを入力して実行
/// 5. 必要に応じて割り込みで追加指示
/// 6. 結果を確認後、フォローアップ質問を送信可能
@main
struct ConversationAgentExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
