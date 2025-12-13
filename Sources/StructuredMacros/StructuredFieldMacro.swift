import SwiftSyntax
import SwiftSyntaxMacros

/// `@StructuredField` マクロの実装
///
/// このマクロは peer マクロとして機能し、プロパティにメタデータを付与します。
/// 実際の処理は `@Structured` マクロがプロパティを解析する際に行われます。
public struct StructuredFieldMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // @StructuredField は変数宣言にのみ適用可能
        guard declaration.is(VariableDeclSyntax.self) else {
            throw StructuredFieldMacroError.onlyApplicableToProperty
        }

        // このマクロ自体は何も生成しない
        // メタデータは @Structured マクロが読み取る
        return []
    }
}

// MARK: - Errors

enum StructuredFieldMacroError: Error, CustomStringConvertible {
    case onlyApplicableToProperty

    var description: String {
        switch self {
        case .onlyApplicableToProperty:
            return "@StructuredField can only be applied to properties"
        }
    }
}
