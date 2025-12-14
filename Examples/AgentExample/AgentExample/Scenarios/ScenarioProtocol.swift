//
//  ScenarioProtocol.swift
//  AgentExample
//
//  エージェントシナリオのプロトコル定義
//  カテゴリ・プロンプト・出力型を一箇所で定義する抽象化
//

import Foundation
import LLMStructuredOutputs

// MARK: - Scenario Protocol

/// エージェントシナリオのプロトコル
///
/// このプロトコルに準拠することで、カテゴリ・プロンプト・出力型を
/// 一箇所で定義し、型安全なエージェント実行を実現します。
///
/// ## 使用例
/// ```swift
/// enum ResearchScenario: AgentScenarioType {
///     typealias Output = ResearchReport
///
///     static let id = "research"
///     static let displayName = "リサーチ"
///     static let icon = "magnifyingglass"
///     static let description = "Web検索・情報収集"
///
///     static func systemPrompt() -> Prompt {
///         Prompt {
///             PromptComponent.role("リサーチアシスタント")
///             // ...
///         }
///     }
///
///     static let sampleScenarios: [SampleScenario] = [...]
/// }
/// ```
public protocol AgentScenarioType: Sendable {
    /// シナリオの出力型（StructuredProtocol準拠）
    associatedtype Output: StructuredProtocol & Equatable & Sendable

    // MARK: - メタ情報

    /// シナリオの一意識別子
    static var id: String { get }

    /// UI表示用の名前
    static var displayName: String { get }

    /// SF Symbolsのアイコン名
    static var icon: String { get }

    /// シナリオの説明文
    static var description: String { get }

    // MARK: - プロンプト生成

    /// このシナリオ用のシステムプロンプトを生成
    static func systemPrompt() -> Prompt

    // MARK: - サンプルシナリオ

    /// UI表示用のサンプルシナリオ一覧
    static var sampleScenarios: [SampleScenario] { get }
}

// MARK: - Sample Scenario

/// サンプルシナリオ（UI表示用）
///
/// ユーザーが選択できる具体的なタスク例を定義します。
public struct SampleScenario: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let prompt: String
    public let description: String

    public init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        description: String
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.description = description
    }
}

// MARK: - Scenario Info (Type-Erased Metadata)

/// シナリオのメタ情報（型消去版）
///
/// UI表示用に、ジェネリクスを使わずにシナリオ情報にアクセスするための構造体。
/// `AgentScenarioType` の静的プロパティを保持します。
public struct ScenarioInfo: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let icon: String
    public let description: String
    public let sampleScenarios: [SampleScenario]

    public init<S: AgentScenarioType>(_ type: S.Type) {
        self.id = S.id
        self.displayName = S.displayName
        self.icon = S.icon
        self.description = S.description
        self.sampleScenarios = S.sampleScenarios
    }
}
