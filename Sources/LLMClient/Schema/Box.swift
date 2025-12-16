import Foundation

// MARK: - Box

/// 再帰的な構造をサポートするためのボックス型
///
/// 値型（struct）内で再帰的な参照が必要な場合に使用します。
/// Swift の値型は直接的な再帰参照をサポートしないため、
/// 参照型（class）でラップすることで間接参照を実現します。
///
/// ## 使用例
///
/// ```swift
/// struct TreeNode {
///     let value: Int
///     let children: [Box<TreeNode>]?
/// }
///
/// let leaf = TreeNode(value: 1, children: nil)
/// let parent = TreeNode(value: 0, children: [Box(leaf)])
/// ```
///
/// ## JSON Schema での使用
///
/// ```swift
/// // 配列の items は再帰的に JSONSchema を参照
/// let arraySchema = JSONSchema(
///     type: .array,
///     items: innerSchema  // init 内で Box<JSONSchema> に変換される
/// )
/// ```
public final class Box<T: Sendable & Encodable & Equatable>: Sendable, Encodable, Equatable {
    /// ボックス内の値
    public let value: T

    // MARK: - Initializer

    /// Box を初期化
    ///
    /// - Parameter value: ボックスに格納する値
    public init(_ value: T) {
        self.value = value
    }

    // MARK: - Encodable

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }

    // MARK: - Equatable

    public static func == (lhs: Box<T>, rhs: Box<T>) -> Bool {
        lhs.value == rhs.value
    }
}
