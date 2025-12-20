import SwiftUI
import UIRouting

/// アラートダイアログ
enum AppAlert: Alertable {
    case deleteAgent(name: String, onConfirm: () -> Void)
    case deleteSession(name: String, onConfirm: () -> Void)
    case discardChanges(onDiscard: () -> Void)
    case error(message: String)

    var title: String {
        switch self {
        case .deleteAgent: "エージェントを削除"
        case .deleteSession: "セッションを削除"
        case .discardChanges: "変更を破棄"
        case .error: "エラー"
        }
    }

    var message: String? {
        switch self {
        case .deleteAgent(let name, _):
            "「\(name)」を削除してもよろしいですか？関連するセッションも削除されます。"
        case .deleteSession(let name, _):
            "「\(name)」を削除してもよろしいですか？"
        case .discardChanges:
            "保存されていない変更があります。破棄してもよろしいですか？"
        case .error(let message):
            message
        }
    }

    var actions: [AlertAction] {
        switch self {
        case .deleteAgent(_, let onConfirm):
            [
                AlertAction(title: "キャンセル", role: .cancel) {},
                AlertAction(title: "削除", role: .destructive, action: onConfirm)
            ]
        case .deleteSession(_, let onConfirm):
            [
                AlertAction(title: "キャンセル", role: .cancel) {},
                AlertAction(title: "削除", role: .destructive, action: onConfirm)
            ]
        case .discardChanges(let onDiscard):
            [
                AlertAction(title: "編集を続ける", role: .cancel) {},
                AlertAction(title: "破棄", role: .destructive, action: onDiscard)
            ]
        case .error:
            [AlertAction(title: "OK") {}]
        }
    }
}
