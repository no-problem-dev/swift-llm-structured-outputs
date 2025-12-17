import Foundation

// MARK: - RemovedConstraint to PromptComponent Conversion

extension RemovedConstraint {
    /// 除去された制約を PromptComponent に変換
    ///
    /// JSON Schema でサポートされていない制約を、LLM が理解できる
    /// 自然言語の指示に変換します。
    ///
    /// - Returns: outputConstraint タイプの PromptComponent
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let constraint = RemovedConstraint(
    ///     type: .minItems,
    ///     fieldPath: "tags",
    ///     value: .int(1)
    /// )
    /// let component = constraint.toPromptComponent()
    /// // → .outputConstraint("The 'tags' array must have at least 1 item(s).")
    /// ```
    package func toPromptComponent() -> PromptComponent {
        .outputConstraint(toConstraintDescription())
    }

    /// 制約を自然言語の説明に変換
    ///
    /// - Returns: 制約を説明する文字列
    private func toConstraintDescription() -> String {
        let field = formatFieldPath(fieldPath)

        switch type {
        case .minimum:
            return "The '\(field)' field must be at least \(value.stringValue)."

        case .maximum:
            return "The '\(field)' field must be at most \(value.stringValue)."

        case .exclusiveMinimum:
            return "The '\(field)' field must be greater than \(value.stringValue) (exclusive)."

        case .exclusiveMaximum:
            return "The '\(field)' field must be less than \(value.stringValue) (exclusive)."

        case .minItems:
            return "The '\(field)' array must have at least \(value.stringValue) item(s)."

        case .maxItems:
            return "The '\(field)' array must have at most \(value.stringValue) item(s)."

        case .minLength:
            return "The '\(field)' field must be at least \(value.stringValue) character(s) long."

        case .maxLength:
            return "The '\(field)' field must be at most \(value.stringValue) character(s) long."

        case .pattern:
            return "The '\(field)' field must match the pattern: \(value.stringValue)"

        case .format:
            return "The '\(field)' field must be in \(value.stringValue) format."
        }
    }

    /// フィールドパスを読みやすい形式にフォーマット
    private func formatFieldPath(_ path: String) -> String {
        // ルートの場合は "response" と表示
        if path.isEmpty || path == "$" {
            return "response"
        }
        return path
    }
}

// MARK: - Array Extension

extension Array where Element == RemovedConstraint {
    /// 除去された制約の配列を PromptComponent の配列に変換
    ///
    /// - Returns: outputConstraint タイプの PromptComponent 配列
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let constraints = [
    ///     RemovedConstraint(type: .minItems, fieldPath: "tags", value: .int(1)),
    ///     RemovedConstraint(type: .maxItems, fieldPath: "tags", value: .int(5))
    /// ]
    /// let components = constraints.toPromptComponents()
    /// ```
    package func toPromptComponents() -> [PromptComponent] {
        map { $0.toPromptComponent() }
    }

    /// 除去された制約の配列を Prompt に変換
    ///
    /// - Returns: outputConstraint コンポーネントで構成された Prompt
    ///            制約がない場合は nil
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// if let constraintPrompt = removedConstraints.toPrompt() {
    ///     let finalPrompt = systemPrompt + constraintPrompt
    /// }
    /// ```
    package func toPrompt() -> Prompt? {
        guard !isEmpty else { return nil }
        return Prompt(components: toPromptComponents())
    }
}

// MARK: - SchemaAdaptationResult Extension

extension SchemaAdaptationResult {
    /// 除去された制約を Prompt に変換
    ///
    /// - Returns: outputConstraint コンポーネントで構成された Prompt
    ///            制約がない場合は nil
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let adapter = OpenAISchemaAdapter()
    /// let result = adapter.adaptWithConstraints(schema)
    ///
    /// if let constraintPrompt = result.toConstraintPrompt() {
    ///     // システムプロンプトに制約を追加
    ///     let effectiveSystemPrompt = systemPrompt + constraintPrompt
    /// }
    /// ```
    package func toConstraintPrompt() -> Prompt? {
        removedConstraints.toPrompt()
    }
}
