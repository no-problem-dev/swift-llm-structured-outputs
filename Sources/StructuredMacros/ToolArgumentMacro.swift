import SwiftSyntax
import SwiftSyntaxMacros

/// `@ToolArgument` マクロの実装
///
/// このマクロはマーカーとして機能し、`@Tool` マクロがプロパティを
/// 認識して `Arguments` 型に含めるために使用されます。
///
/// 実際のコード生成は `@Tool` マクロ側で行われます。
public struct ToolArgumentMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // このマクロはマーカーとして機能
        // 実際の処理は @Tool マクロ側で行う
        return []
    }
}
