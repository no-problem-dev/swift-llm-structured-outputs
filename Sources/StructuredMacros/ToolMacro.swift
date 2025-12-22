import SwiftSyntax
import SwiftSyntaxMacros

/// `@Tool` マクロの実装
///
/// 構造体に対して以下を生成します：
/// - `toolName` インスタンスプロパティ
/// - `toolDescription` インスタンスプロパティ
/// - `inputSchema` インスタンスプロパティ
/// - `Arguments` ネスト型（@ToolArgument プロパティから）
/// - `arguments` プロパティ
/// - `init(arguments:)` イニシャライザ
/// - `execute(with:)` インスタンスメソッド
/// - `Tool`, `Sendable` への準拠
public struct ToolMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 構造体のみサポート
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw ToolMacroError.onlyApplicableToStruct
        }

        let typeName = structDecl.name.text

        // ツールの説明を取得
        let toolDescription = extractDescription(from: node)
            ?? "Tool: \(typeName)"

        // ツール名を取得（指定がなければ型名をスネークケースに変換）
        let toolName = extractToolName(from: node)
            ?? typeName.toSnakeCase()

        // @ToolArgument を持つプロパティを収集
        let arguments = collectToolArguments(from: structDecl)

        var members: [DeclSyntax] = []

        // toolName インスタンスプロパティ
        members.append("""
            public let toolName: String = "\(raw: toolName)"
            """)

        // toolDescription インスタンスプロパティ
        members.append("""
            public let toolDescription: String = "\(raw: toolDescription)"
            """)

        // Arguments 型を生成
        let argumentsDecl = generateArgumentsType(arguments: arguments)
        members.append(argumentsDecl)

        // inputSchema インスタンスプロパティ
        members.append("""
            public var inputSchema: JSONSchema {
                Arguments.jsonSchema
            }
            """)

        // arguments プロパティ
        members.append("""
            public var arguments: Arguments
            """)

        // init(arguments:) イニシャライザ
        let initDecl = generateInitializer(arguments: arguments)
        members.append(initDecl)

        // execute(with:) インスタンスメソッド
        let executeDecl = generateExecuteMethod(typeName: typeName, arguments: arguments)
        members.append(executeDecl)

        return members
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            return []
        }

        let protocolExtension: DeclSyntax = """
            extension \(type.trimmed): Tool, Sendable {}
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
              firstArg.label == nil,  // ラベルなし引数
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
            return nil
        }
        return segment.content.text
    }

    /// マクロ属性から name を抽出
    private static func extractToolName(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return nil
        }

        for arg in arguments {
            if arg.label?.text == "name",
               let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                return segment.content.text
            }
        }
        return nil
    }

    /// @ToolArgument を持つプロパティを収集
    private static func collectToolArguments(from structDecl: StructDeclSyntax) -> [ToolArgumentInfo] {
        var arguments: [ToolArgumentInfo] = []

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

            // @ToolArgument 属性を探す
            let argInfo = extractToolArgumentInfo(from: varDecl.attributes)

            // @ToolArgument がない場合はスキップ
            guard argInfo.hasAttribute else {
                continue
            }

            let propertyName = identifier.identifier.text
            let typeName = typeAnnotation.type.trimmedDescription
            let isOptional = typeAnnotation.type.is(OptionalTypeSyntax.self)
                || typeAnnotation.type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
            let isArray = isArrayType(typeAnnotation.type)
            let baseType = extractBaseType(from: typeAnnotation.type)

            arguments.append(ToolArgumentInfo(
                name: propertyName,
                typeName: typeName,
                baseType: baseType,
                isOptional: isOptional,
                isArray: isArray,
                description: argInfo.description,
                constraints: argInfo.constraints
            ))
        }

        return arguments
    }

    /// @ToolArgument 属性から情報を抽出
    private static func extractToolArgumentInfo(
        from attributes: AttributeListSyntax
    ) -> (hasAttribute: Bool, description: String?, constraints: [ConstraintInfo]) {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identifier.name.text == "ToolArgument",
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

            return (true, description, constraints)
        }

        return (false, nil, [])
    }

    /// 制約式をパース（StructuredMacro から流用）
    private static func parseConstraint(from expr: ExprSyntax) -> ConstraintInfo? {
        guard let funcCall = expr.as(FunctionCallExprSyntax.self),
              let memberAccess = funcCall.calledExpression.as(MemberAccessExprSyntax.self) else {
            return nil
        }

        let constraintName = memberAccess.declName.baseName.text

        guard let firstArg = funcCall.arguments.first else {
            return nil
        }

        if let intLiteral = firstArg.expression.as(IntegerLiteralExprSyntax.self) {
            let value = intLiteral.literal.text
            return ConstraintInfo(name: constraintName, intValue: Int(value))
        }

        if let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
           let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
            return ConstraintInfo(name: constraintName, stringValue: segment.content.text)
        }

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

    /// 基本型を抽出
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

    /// Arguments 型を生成
    private static func generateArgumentsType(arguments: [ToolArgumentInfo]) -> DeclSyntax {
        if arguments.isEmpty {
            // 引数なしの場合は EmptyArguments を typealias
            return """
                public typealias Arguments = EmptyArguments
                """
        }

        var propertiesCode = ""
        for arg in arguments {
            let defaultValue = defaultValueForType(arg.typeName, isOptional: arg.isOptional, isArray: arg.isArray)
            propertiesCode += "    @StructuredField(\"\(arg.description ?? arg.name)\")\n"
            propertiesCode += "    public var \(arg.name): \(arg.typeName) = \(defaultValue)\n"
        }

        return """
            @Structured
            public struct Arguments {
            \(raw: propertiesCode)}
            """
    }

    /// 初期化子を生成
    ///
    /// 引数なしの `init()` と `init(arguments:)` の両方を生成します。
    /// これにより、ToolSet への登録時は `MyTool()` で作成でき、
    /// 実行時は引数付きで再構築できます。
    private static func generateInitializer(arguments: [ToolArgumentInfo]) -> DeclSyntax {
        if arguments.isEmpty {
            return """
                public init(arguments: Arguments = EmptyArguments()) {
                    self.arguments = arguments
                }
                """
        }

        // 各引数のデフォルト値を生成
        var defaultValues: [String] = []
        for arg in arguments {
            let defaultValue = defaultValueForType(arg.typeName, isOptional: arg.isOptional, isArray: arg.isArray)
            defaultValues.append("self.\(arg.name) = \(defaultValue)")
        }
        let defaultAssignments = defaultValues.joined(separator: "\n    ")

        // arguments からの代入を生成
        var argAssignments = ""
        for arg in arguments {
            argAssignments += "    self.\(arg.name) = arguments.\(arg.name)\n"
        }

        // 引数なし init() を生成（ToolSet 登録用）
        // arguments プロパティは遅延初期化するため、ダミー値で初期化
        return """
            public init() {
                // ToolSet 登録時のデフォルト初期化
                // 実際の引数は execute(with:) で設定される
                \(raw: defaultAssignments)
                // arguments は execute 時に設定されるため、空の Arguments で初期化
                self.arguments = Arguments()
            }

            public init(arguments: Arguments) {
                self.arguments = arguments
            \(raw: argAssignments)}
            """
    }

    /// 型に応じたデフォルト値を返す
    private static func defaultValueForType(_ typeName: String, isOptional: Bool, isArray: Bool) -> String {
        if isOptional {
            return "nil"
        }
        if isArray {
            return "[]"
        }
        // 基本型のデフォルト値
        let baseType = typeName.replacing("?", with: "")
        switch baseType {
        case "String":
            return "\"\""
        case "Int", "Int8", "Int16", "Int32", "Int64",
             "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return "0"
        case "Double", "Float", "CGFloat":
            return "0.0"
        case "Bool":
            return "false"
        default:
            // カスタム型の場合はデフォルト初期化を試みる
            return "\(baseType)()"
        }
    }

    /// execute(with:) インスタンスメソッドを生成
    private static func generateExecuteMethod(typeName: String, arguments: [ToolArgumentInfo]) -> DeclSyntax {
        // 引数のコピー処理を生成
        var copyAssignments = ""
        for arg in arguments {
            copyAssignments += "    copy.\(arg.name) = args.\(arg.name)\n"
        }

        if arguments.isEmpty {
            // 引数なしの場合はシンプルに
            return """
                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let result = try await self.call()
                    return try result.toToolResult()
                }
                """
        }

        return """
            public func execute(with argumentsData: Data) async throws -> ToolResult {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let args = try decoder.decode(Arguments.self, from: argumentsData)
                var copy = self
                copy.arguments = args
            \(raw: copyAssignments)    let result = try await copy.call()
                return try result.toToolResult()
            }
            """
    }
}

// MARK: - ToolArgumentInfo

/// ツール引数の情報
struct ToolArgumentInfo {
    let name: String
    let typeName: String
    let baseType: String
    let isOptional: Bool
    let isArray: Bool
    let description: String?
    let constraints: [ConstraintInfo]
}

// MARK: - ToolMacroError

enum ToolMacroError: Error, CustomStringConvertible {
    case onlyApplicableToStruct

    var description: String {
        switch self {
        case .onlyApplicableToStruct:
            return "@Tool can only be applied to structs"
        }
    }
}
