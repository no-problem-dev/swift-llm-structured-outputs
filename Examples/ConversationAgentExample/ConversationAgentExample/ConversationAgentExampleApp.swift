import SwiftUI

/// ConversationAgentExample アプリ
///
/// このサンプルアプリは `ConversationalAgentSession` の以下の機能をデモンストレーションします:
///
/// ## 主な機能
///
/// 1. **セッション管理**
///    - セッションの作成とクリア
///    - 会話履歴の自動管理
///
/// 2. **マルチターン会話**
///    - 複数回のやり取りを通じた調査
///    - 前の会話を踏まえたフォローアップ
///
/// 3. **イベントストリーミング**
///    - セッションイベントのリアルタイム監視
///    - ステップごとの進捗表示
///
/// 4. **複数の出力タイプ**
///    - ResearchReport: 詳細な調査レポート
///    - SummaryReport: シンプルな要約
///    - ComparisonReport: 比較分析
///
/// 5. **割り込み機能**
///    - 実行中のエージェントへの追加指示
///    - 動的な方向転換
///
/// ## 使用方法
///
/// 1. 設定画面で Anthropic API キーを設定
/// 2. 必要に応じて Brave Search API キーを設定（Web検索用）
/// 3. 出力タイプを選択
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
