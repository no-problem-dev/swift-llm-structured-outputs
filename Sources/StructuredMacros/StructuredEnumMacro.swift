import SwiftSyntax
import SwiftSyntaxMacros

/// `@StructuredEnum` マクロの実装
///
/// String 型の RawRepresentable enum に対して以下を生成します：
/// - `jsonSchema` 静的プロパティ（enum 制約付き string スキーマ）
/// - `StructuredProtocol`, `Codable`, `Sendable` への準拠
///
/// ## 使用例
///
/// ```swift
/// @StructuredEnum("ステータス")
/// enum Status: String {
///     case active
///     case inactive
///     case pending
/// }
/// ```
///
/// 生成される JSON Schema:
/// ```json
/// {
///     "type": "string",
///     "description": "ステータス",
///     "enum": ["active", "inactive", "pending"]
/// }
/// ```
public struct StructuredEnumMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // enum のみサポート
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw StructuredEnumMacroError.onlyApplicableToEnum
        }

        // RawValue が String であることを確認
        guard hasStringRawValue(enumDecl) else {
            throw StructuredEnumMacroError.requiresStringRawValue
        }

        // 型の説明を取得
        let typeDescription = extractDescription(from: node)

        // enum ケースを収集
        let cases = collectEnumCases(from: enumDecl)

        guard !cases.isEmpty else {
            throw StructuredEnumMacroError.requiresAtLeastOneCase
        }

        // jsonSchema プロパティを生成
        let jsonSchemaDecl = generateJSONSchemaProperty(
            typeDescription: typeDescription,
            cases: cases
        )

        // enumDescription プロパティを生成
        let enumDescriptionDecl = generateEnumDescriptionProperty(
            typeDescription: typeDescription,
            cases: cases
        )

        return [DeclSyntax(jsonSchemaDecl), DeclSyntax(enumDescriptionDecl)]
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // enum 以外では extension を生成しない
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            return []
        }

        // String RawValue を持たない enum では extension を生成しない
        guard hasStringRawValue(enumDecl) else {
            return []
        }

        let protocolExtension: DeclSyntax = """
            extension \(type.trimmed): StructuredProtocol, Sendable {}
            """

        guard let extensionDecl = protocolExtension.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }

    // MARK: - Private Helpers

    /// マクロ属性から description を抽出
    private static func extractDescription(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
            return nil
        }
        return segment.content.text
    }

    /// enum が String の RawValue を持つかチェック
    private static func hasStringRawValue(_ enumDecl: EnumDeclSyntax) -> Bool {
        guard let inheritanceClause = enumDecl.inheritanceClause else {
            return false
        }

        for inheritedType in inheritanceClause.inheritedTypes {
            let typeName = inheritedType.type.trimmedDescription
            if typeName == "String" {
                return true
            }
        }

        return false
    }

    /// enum からケースを収集
    private static func collectEnumCases(from enumDecl: EnumDeclSyntax) -> [EnumCaseInfo] {
        var cases: [EnumCaseInfo] = []

        for member in enumDecl.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                continue
            }

            // @StructuredCase 属性から説明を取得
            let caseDescription = extractCaseDescription(from: caseDecl.attributes)

            for element in caseDecl.elements {
                let name = element.name.text

                // 明示的な rawValue があれば使用、なければ名前をそのまま使用
                let rawValue: String
                if let rawValueClause = element.rawValue,
                   let stringLiteral = rawValueClause.value.as(StringLiteralExprSyntax.self),
                   let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                    rawValue = segment.content.text
                } else {
                    rawValue = name
                }

                cases.append(EnumCaseInfo(name: name, rawValue: rawValue, description: caseDescription))
            }
        }

        return cases
    }

    /// @StructuredCase 属性から説明を抽出
    private static func extractCaseDescription(from attributes: AttributeListSyntax) -> String? {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identifier.name.text == "StructuredCase",
                  let arguments = attr.arguments?.as(LabeledExprListSyntax.self),
                  let firstArg = arguments.first,
                  let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
                  let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
                continue
            }
            return segment.content.text
        }
        return nil
    }

    /// jsonSchema プロパティを生成
    private static func generateJSONSchemaProperty(
        typeDescription: String?,
        cases: [EnumCaseInfo]
    ) -> VariableDeclSyntax {
        let enumValues = cases.map { "\"\($0.rawValue)\"" }.joined(separator: ", ")
        let descriptionArg = typeDescription.map { "description: \"\($0)\", " } ?? ""

        let code: DeclSyntax = """
            public static var jsonSchema: JSONSchema {
                JSONSchema(
                    type: .string,
                    \(raw: descriptionArg)enum: [\(raw: enumValues)]
                )
            }
            """

        return code.cast(VariableDeclSyntax.self)
    }

    /// enumDescription プロパティを生成
    ///
    /// ケースの説明を含むプロンプト用の文字列を生成します。
    /// 例:
    /// ```
    /// タスクの優先度:
    /// - low: 緊急ではないタスク
    /// - medium: 通常のタスク
    /// - high: 緊急のタスク
    /// ```
    private static func generateEnumDescriptionProperty(
        typeDescription: String?,
        cases: [EnumCaseInfo]
    ) -> VariableDeclSyntax {
        var lines: [String] = []

        // タイトル行（型の説明がある場合）
        if let desc = typeDescription {
            lines.append("\(desc):")
        }

        // 各ケースの説明
        for caseInfo in cases {
            if let caseDesc = caseInfo.description {
                lines.append("- \(caseInfo.rawValue): \(caseDesc)")
            } else {
                lines.append("- \(caseInfo.rawValue)")
            }
        }

        let description = lines.joined(separator: "\\n")

        let code: DeclSyntax = """
            public static var enumDescription: String {
                \"\(raw: description)\"
            }
            """

        return code.cast(VariableDeclSyntax.self)
    }
}

// MARK: - Supporting Types

/// enum ケース情報
struct EnumCaseInfo {
    let name: String
    let rawValue: String
    let description: String?
}

// MARK: - Errors

enum StructuredEnumMacroError: Error, CustomStringConvertible {
    case onlyApplicableToEnum
    case requiresStringRawValue
    case requiresAtLeastOneCase

    var description: String {
        switch self {
        case .onlyApplicableToEnum:
            return "@StructuredEnum can only be applied to enums"
        case .requiresStringRawValue:
            return "@StructuredEnum requires enum with String raw value"
        case .requiresAtLeastOneCase:
            return "@StructuredEnum requires at least one case"
        }
    }
}
