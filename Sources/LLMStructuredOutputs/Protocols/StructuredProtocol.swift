/// LLMの構造化出力に対応した型が準拠するプロトコル
///
/// このプロトコルに準拠した型は、LLMに対してJSON Schemaとして
/// 自身の構造を説明することができます。
///
/// 通常は `@Structured` マクロを使用することで自動的に準拠されます。
///
/// ```swift
/// @Structured("ユーザー情報")
/// struct UserInfo {
///     @StructuredField("ユーザー名")
///     var name: String
///
///     @StructuredField("年齢", .minimum(0), .maximum(150))
///     var age: Int
/// }
/// ```
public protocol StructuredProtocol: Codable, Sendable {
    /// この型のJSON Schema表現
    static var jsonSchema: JSONSchema { get }
}
