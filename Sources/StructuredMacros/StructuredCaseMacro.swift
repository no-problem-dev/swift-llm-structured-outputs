import SwiftSyntax
import SwiftSyntaxMacros

/// `@StructuredCase` マクロの実装
///
/// enum のケースに説明を付与するための peer macro です。
/// このマクロ自体は何も生成せず、`@StructuredEnum` マクロが
/// ケースの説明を収集する際のマーカーとして機能します。
///
/// ## 使用例
///
/// ```swift
/// @StructuredEnum("優先度")
/// enum Priority: String {
///     @StructuredCase("緊急ではないタスク")
///     case low
///
///     @StructuredCase("通常のタスク")
///     case medium
///
///     @StructuredCase("緊急のタスク")
///     case high
/// }
/// ```
public struct StructuredCaseMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // enum case 以外に適用された場合はエラー
        guard declaration.is(EnumCaseDeclSyntax.self) else {
            throw StructuredCaseMacroError.onlyApplicableToEnumCase
        }

        // peer macro はマーカーとして機能するのみで、何も生成しない
        return []
    }
}

// MARK: - Errors

enum StructuredCaseMacroError: Error, CustomStringConvertible {
    case onlyApplicableToEnumCase

    var description: String {
        switch self {
        case .onlyApplicableToEnumCase:
            return "@StructuredCase can only be applied to enum cases"
        }
    }
}
