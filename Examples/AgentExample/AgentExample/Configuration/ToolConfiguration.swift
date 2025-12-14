//
//  ToolConfiguration.swift
//  AgentExample
//
//  ツール選択設定
//

import Foundation

/// 利用可能なツールの識別子
enum ToolIdentifier: String, CaseIterable, Identifiable {
    case webSearch = "web_search_tool"
    case fetchWebPage = "fetch_web_page"
    case weather = "get_weather"
    case calculator = "calculator"
    case currentTime = "get_current_time"

    var id: String { rawValue }

    /// 表示名
    var displayName: String {
        switch self {
        case .webSearch: return "Web検索"
        case .fetchWebPage: return "ページ取得"
        case .weather: return "天気情報"
        case .calculator: return "計算機"
        case .currentTime: return "現在時刻"
        }
    }

    /// 説明
    var description: String {
        switch self {
        case .webSearch: return "Webを検索して情報を取得"
        case .fetchWebPage: return "指定URLのページを取得"
        case .weather: return "都市の天気情報を取得"
        case .calculator: return "数式を計算"
        case .currentTime: return "現在の日時を取得"
        }
    }

    /// アイコン
    var icon: String {
        switch self {
        case .webSearch: return "magnifyingglass"
        case .fetchWebPage: return "doc.text"
        case .weather: return "cloud.sun.fill"
        case .calculator: return "function"
        case .currentTime: return "clock.fill"
        }
    }

    /// APIキーが必要かどうか
    var requiresAPIKey: Bool {
        switch self {
        case .webSearch: return true
        default: return false
        }
    }

    /// 現在利用可能かどうか（APIキー等の要件を満たしているか）
    var isAvailable: Bool {
        switch self {
        case .webSearch: return APIKeyManager.hasBraveSearchKey
        default: return true
        }
    }
}

/// ツール選択設定
///
/// 各ツールの有効/無効状態を管理し、UserDefaultsで永続化します。
@Observable @MainActor
final class ToolConfiguration {

    // MARK: - Singleton

    static let shared = ToolConfiguration()

    // MARK: - UserDefaults Key

    private let userDefaultsKey = "agentexample.enabledTools"

    // MARK: - Storage

    /// 有効なツールのセット
    private(set) var enabledTools: Set<ToolIdentifier>

    // MARK: - Initialization

    private init() {
        // UserDefaultsから復元
        if let savedRawValues = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            let restored = savedRawValues.compactMap { ToolIdentifier(rawValue: $0) }
            enabledTools = Set(restored)
        } else {
            // デフォルトはすべて有効
            enabledTools = Set(ToolIdentifier.allCases)
        }
    }

    // MARK: - Public Methods

    /// ツールが有効かどうか
    func isEnabled(_ tool: ToolIdentifier) -> Bool {
        enabledTools.contains(tool)
    }

    /// ツールが使用可能かどうか（有効かつAPIキー等の要件を満たしている）
    func isUsable(_ tool: ToolIdentifier) -> Bool {
        isEnabled(tool) && tool.isAvailable
    }

    /// ツールの有効/無効を切り替え
    func setEnabled(_ tool: ToolIdentifier, enabled: Bool) {
        if enabled {
            enabledTools.insert(tool)
        } else {
            enabledTools.remove(tool)
        }
        save()
    }

    /// ツールの有効/無効をトグル
    func toggle(_ tool: ToolIdentifier) {
        if enabledTools.contains(tool) {
            enabledTools.remove(tool)
        } else {
            enabledTools.insert(tool)
        }
        save()
    }

    /// すべてのツールを有効化
    func enableAll() {
        enabledTools = Set(ToolIdentifier.allCases)
        save()
    }

    /// すべてのツールを無効化
    func disableAll() {
        enabledTools.removeAll()
        save()
    }

    /// 有効なツールの数
    var enabledCount: Int {
        enabledTools.count
    }

    /// 使用可能なツールの数（有効かつAPIキー等の要件を満たしている）
    var usableCount: Int {
        enabledTools.filter { $0.isAvailable }.count
    }

    /// 少なくとも1つのツールが使用可能か
    var hasUsableTools: Bool {
        usableCount > 0
    }

    // MARK: - Private Methods

    private func save() {
        let rawValues = enabledTools.map { $0.rawValue }
        UserDefaults.standard.set(rawValues, forKey: userDefaultsKey)
    }
}
