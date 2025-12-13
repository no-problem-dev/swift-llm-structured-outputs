import SwiftSyntax
import SwiftSyntaxMacros

/// `@Structured` マクロの実装
///
/// 構造体に対して以下を生成します：
/// - `jsonSchema` 静的プロパティ
/// - `StructuredProtocol`, `Codable`, `Sendable` への準拠
public struct StructuredMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 構造体のみサポート
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw StructuredMacroError.onlyApplicableToStruct
        }

        // 型の説明を取得
        let typeDescription = extractDescription(from: node)

        // プロパティ情報を収集
        let properties = collectProperties(from: structDecl)

        // jsonSchema プロパティを生成
        let jsonSchemaDecl = generateJSONSchemaProperty(
            typeDescription: typeDescription,
            properties: properties
        )

        return [DeclSyntax(jsonSchemaDecl)]
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // 構造体以外では extension を生成しない
        guard declaration.is(StructDeclSyntax.self) else {
            return []
        }

        let protocolExtension: DeclSyntax = """
            extension \(type.trimmed): StructuredProtocol, Codable, Sendable {}
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

    /// 構造体からプロパティ情報を収集
    private static func collectProperties(from structDecl: StructDeclSyntax) -> [PropertyInfo] {
        var properties: [PropertyInfo] = []

        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation else {
                continue
            }

            // 計算プロパティは除外
            if binding.accessorBlock != nil {
                continue
            }

            let propertyName = identifier.identifier.text
            let typeName = typeAnnotation.type.trimmedDescription

            // @StructuredField 属性から情報を取得
            let fieldInfo = extractFieldInfo(from: varDecl.attributes)

            // オプショナル型かどうかを判定
            let isOptional = typeAnnotation.type.is(OptionalTypeSyntax.self)
                || typeAnnotation.type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)

            // 配列型かどうかを判定
            let isArray = isArrayType(typeAnnotation.type)

            // 基本型を取得
            let baseType = extractBaseType(from: typeAnnotation.type)

            // ネストされた型かどうかを判定（基本型でない場合）
            let isNestedType = !isPrimitiveType(baseType)

            properties.append(PropertyInfo(
                name: propertyName,
                typeName: typeName,
                baseType: baseType,
                isOptional: isOptional,
                isArray: isArray,
                isNestedType: isNestedType,
                description: fieldInfo.description,
                constraints: fieldInfo.constraints
            ))
        }

        return properties
    }

    /// @StructuredField 属性から情報を抽出
    private static func extractFieldInfo(from attributes: AttributeListSyntax) -> (description: String?, constraints: [ConstraintInfo]) {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identifier.name.text == "StructuredField",
                  let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else {
                continue
            }

            var description: String?
            var constraints: [ConstraintInfo] = []

            for (index, arg) in arguments.enumerated() {
                if index == 0 {
                    // 最初の引数は description
                    if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        description = segment.content.text
                    }
                } else {
                    // 残りは制約
                    if let constraint = parseConstraint(from: arg.expression) {
                        constraints.append(constraint)
                    }
                }
            }

            return (description, constraints)
        }

        return (nil, [])
    }

    /// 制約式をパース
    private static func parseConstraint(from expr: ExprSyntax) -> ConstraintInfo? {
        // .minItems(3) のような形式をパース
        guard let funcCall = expr.as(FunctionCallExprSyntax.self),
              let memberAccess = funcCall.calledExpression.as(MemberAccessExprSyntax.self) else {
            return nil
        }

        let constraintName = memberAccess.declName.baseName.text

        // 引数を取得
        guard let firstArg = funcCall.arguments.first else {
            return nil
        }

        // 整数値の場合
        if let intLiteral = firstArg.expression.as(IntegerLiteralExprSyntax.self) {
            let value = intLiteral.literal.text
            return ConstraintInfo(name: constraintName, intValue: Int(value))
        }

        // 文字列値の場合
        if let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
           let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
            return ConstraintInfo(name: constraintName, stringValue: segment.content.text)
        }

        // 配列の場合 (.enum(["a", "b"]))
        if let arrayExpr = firstArg.expression.as(ArrayExprSyntax.self) {
            var values: [String] = []
            for element in arrayExpr.elements {
                if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
                   let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                    values.append(segment.content.text)
                }
            }
            return ConstraintInfo(name: constraintName, arrayValue: values)
        }

        // .format(.email) のようなメンバーアクセスの場合
        if let memberAccess = firstArg.expression.as(MemberAccessExprSyntax.self) {
            let formatValue = memberAccess.declName.baseName.text
            return ConstraintInfo(name: constraintName, stringValue: formatValue)
        }

        return nil
    }

    /// 配列型かどうかを判定
    private static func isArrayType(_ type: TypeSyntax) -> Bool {
        if type.is(ArrayTypeSyntax.self) {
            return true
        }
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            return isArrayType(optionalType.wrappedType)
        }
        return false
    }

    /// 基本型を抽出（オプショナルや配列を除去）
    private static func extractBaseType(from type: TypeSyntax) -> String {
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            return extractBaseType(from: optionalType.wrappedType)
        }
        if let arrayType = type.as(ArrayTypeSyntax.self) {
            return extractBaseType(from: arrayType.element)
        }
        if let implicitOptional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return extractBaseType(from: implicitOptional.wrappedType)
        }
        return type.trimmedDescription
    }

    /// jsonSchema プロパティを生成
    private static func generateJSONSchemaProperty(
        typeDescription: String?,
        properties: [PropertyInfo]
    ) -> VariableDeclSyntax {
        var propertiesCode = ""
        var requiredFields: [String] = []

        for property in properties {
            let snakeCaseName = property.name.toSnakeCase()

            let schemaCode: String

            if property.isNestedType {
                // ネストされた型の場合、その型の jsonSchema を参照
                if property.isArray {
                    // 配列の場合
                    var args = ["type: .array", "items: \(property.baseType).jsonSchema"]
                    if let desc = property.description {
                        args.insert("description: \"\(desc)\"", at: 1)
                    }
                    // 配列制約を追加
                    for constraint in property.constraints {
                        if let constraintCode = generateConstraintCode(constraint) {
                            args.append(constraintCode)
                        }
                    }
                    schemaCode = "JSONSchema(\(args.joined(separator: ", ")))"
                } else {
                    // 単一オブジェクトの場合、そのまま参照
                    schemaCode = "\(property.baseType).jsonSchema"
                }
            } else {
                // 基本型の場合
                var schemaArgs: [String] = []

                // 配列の場合は type: .array、それ以外は基本型
                if property.isArray {
                    schemaArgs.append("type: .array")
                } else {
                    let schemaType = mapToSchemaType(property.baseType)
                    schemaArgs.append("type: .\(schemaType)")
                }

                // description
                if let desc = property.description {
                    schemaArgs.append("description: \"\(desc)\"")
                }

                // 配列の場合、items を追加
                if property.isArray {
                    let elementType = mapToSchemaType(property.baseType)
                    schemaArgs.append("items: JSONSchema(type: .\(elementType))")
                }

                // 制約を追加
                for constraint in property.constraints {
                    if let constraintCode = generateConstraintCode(constraint) {
                        schemaArgs.append(constraintCode)
                    }
                }

                schemaCode = "JSONSchema(\(schemaArgs.joined(separator: ", ")))"
            }

            propertiesCode += """
                        "\(snakeCaseName)": \(schemaCode),

            """

            // オプショナルでないフィールドは required
            if !property.isOptional {
                requiredFields.append("\"\(snakeCaseName)\"")
            }
        }

        // 末尾のカンマを削除
        if propertiesCode.hasSuffix(",\n") {
            propertiesCode = String(propertiesCode.dropLast(2)) + "\n"
        }

        let descriptionArg = typeDescription.map { "description: \"\($0)\"," } ?? ""
        let requiredArg = requiredFields.isEmpty ? "" : "required: [\(requiredFields.joined(separator: ", "))],"

        let code: DeclSyntax = """
            public static var jsonSchema: JSONSchema {
                JSONSchema(
                    type: .object,
                    \(raw: descriptionArg)
                    properties: [
            \(raw: propertiesCode)        ],
                    \(raw: requiredArg)
                    additionalProperties: false
                )
            }
            """

        return code.cast(VariableDeclSyntax.self)
    }

    /// Swift型をJSON Schema型にマッピング
    private static func mapToSchemaType(_ swiftType: String) -> String {
        switch swiftType {
        case "String":
            return "string"
        case "Int", "Int8", "Int16", "Int32", "Int64",
             "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return "integer"
        case "Float", "Double", "Decimal":
            return "number"
        case "Bool":
            return "boolean"
        default:
            // カスタム型はobjectとして扱う
            return "object"
        }
    }

    /// 基本型かどうかを判定
    private static func isPrimitiveType(_ swiftType: String) -> Bool {
        switch swiftType {
        case "String", "Int", "Int8", "Int16", "Int32", "Int64",
             "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
             "Float", "Double", "Decimal", "Bool":
            return true
        default:
            return false
        }
    }

    /// 制約をコードに変換
    private static func generateConstraintCode(_ constraint: ConstraintInfo) -> String? {
        switch constraint.name {
        case "minItems":
            return constraint.intValue.map { "minItems: \($0)" }
        case "maxItems":
            return constraint.intValue.map { "maxItems: \($0)" }
        case "minimum":
            return constraint.intValue.map { "minimum: \($0)" }
        case "maximum":
            return constraint.intValue.map { "maximum: \($0)" }
        case "exclusiveMinimum":
            return constraint.intValue.map { "exclusiveMinimum: \($0)" }
        case "exclusiveMaximum":
            return constraint.intValue.map { "exclusiveMaximum: \($0)" }
        case "minLength":
            return constraint.intValue.map { "minLength: \($0)" }
        case "maxLength":
            return constraint.intValue.map { "maxLength: \($0)" }
        case "pattern":
            return constraint.stringValue.map { "pattern: \"\($0)\"" }
        case "enum":
            if let values = constraint.arrayValue {
                let quoted = values.map { "\"\($0)\"" }.joined(separator: ", ")
                return "enum: [\(quoted)]"
            }
            return nil
        case "format":
            return constraint.stringValue.map { "format: \"\(formatToJSONSchemaFormat($0))\"" }
        default:
            return nil
        }
    }

    /// StringFormat enumの値をJSON Schema formatに変換
    private static func formatToJSONSchemaFormat(_ format: String) -> String {
        switch format {
        case "dateTime":
            return "date-time"
        default:
            return format
        }
    }
}

// MARK: - Supporting Types

/// プロパティ情報
struct PropertyInfo {
    let name: String
    let typeName: String
    let baseType: String
    let isOptional: Bool
    let isArray: Bool
    let isNestedType: Bool  // ネストされた StructuredProtocol 型かどうか
    let description: String?
    let constraints: [ConstraintInfo]
}

/// 制約情報
struct ConstraintInfo {
    let name: String
    var intValue: Int?
    var stringValue: String?
    var arrayValue: [String]?

    init(name: String, intValue: Int? = nil, stringValue: String? = nil, arrayValue: [String]? = nil) {
        self.name = name
        self.intValue = intValue
        self.stringValue = stringValue
        self.arrayValue = arrayValue
    }
}

// MARK: - String Extension

extension String {
    /// camelCase を snake_case に変換
    func toSnakeCase() -> String {
        var result = ""
        for (index, character) in self.enumerated() {
            if character.isUppercase {
                if index > 0 {
                    // 前の文字が小文字、または次の文字が小文字の場合にアンダースコアを挿入
                    let prevIndex = self.index(self.startIndex, offsetBy: index - 1)
                    let prevChar = self[prevIndex]
                    if prevChar.isLowercase {
                        result += "_"
                    } else if index + 1 < self.count {
                        let nextIndex = self.index(self.startIndex, offsetBy: index + 1)
                        let nextChar = self[nextIndex]
                        if nextChar.isLowercase {
                            result += "_"
                        }
                    }
                }
                result += character.lowercased()
            } else {
                result += String(character)
            }
        }
        return result
    }
}

// MARK: - Errors

enum StructuredMacroError: Error, CustomStringConvertible {
    case onlyApplicableToStruct

    var description: String {
        switch self {
        case .onlyApplicableToStruct:
            return "@Structured can only be applied to structs"
        }
    }
}
