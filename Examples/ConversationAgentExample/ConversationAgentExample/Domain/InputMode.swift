import Foundation

/// 入力フィールドのモード
///
/// セッション状態から派生する入力モード。
/// UIの表示設定やアクションの分岐に使用する。
enum InputMode {
    /// 新規プロンプト入力
    case prompt
    /// 実行中の割り込み
    case interrupt
    /// 質問への回答
    case answer
    /// 再開可能状態（追加指示も可）
    case resume
}
