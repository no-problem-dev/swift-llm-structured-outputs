import Foundation
import LLMTool

// MARK: - ToolSetBuilder Extension for ToolKit

extension ToolSetBuilder {
    /// ToolKitを配列として構築
    ///
    /// ToolSetBuilder内でToolKitを直接使用できるようにします。
    /// ToolKitが提供するすべてのツールがToolSetに追加されます。
    ///
    /// ```swift
    /// let tools = ToolSet {
    ///     MemoryToolKit()      // ToolKitのすべてのツールが追加される
    ///     GetWeatherTool()     // 通常のToolも混在可能
    /// }
    /// ```
    ///
    /// - Parameter toolkit: ToolKitに準拠したインスタンス
    /// - Returns: ToolKitが提供するツールの配列
    public static func buildExpression(_ toolkit: some ToolKit) -> [any Tool] {
        toolkit.tools
    }
}

// MARK: - ToolSet Extension for ToolKit

extension ToolSet {
    /// ToolKitを追加した新しいToolSetを返す
    ///
    /// - Parameter toolkit: 追加するToolKit
    /// - Returns: ToolKitのツールが追加されたToolSet
    public func appending(_ toolkit: some ToolKit) -> ToolSet {
        ToolSet(tools: self.tools + toolkit.tools)
    }

    /// ToolSetにToolKitを追加
    ///
    /// - Parameters:
    ///   - lhs: ToolSet
    ///   - rhs: 追加するToolKit
    /// - Returns: ToolKitのツールが追加されたToolSet
    public static func + (lhs: ToolSet, rhs: some ToolKit) -> ToolSet {
        ToolSet(tools: lhs.tools + rhs.tools)
    }

    /// このToolSetに含まれるToolKitのツール数を取得
    ///
    /// - Parameter toolkitName: ToolKit名
    /// - Returns: 該当するToolKitのツール数（ToolKit情報がない場合は0）
    public func toolCount(for toolkitName: String) -> Int {
        // Note: 現在の実装ではToolKitの追跡は行わないため、
        // この機能は将来の拡張用に予約されています
        0
    }
}

// MARK: - Array Extension for ToolKit

extension Array where Element == any Tool {
    /// ToolKitからツール配列を作成
    ///
    /// - Parameter toolkit: ToolKit
    /// - Returns: ツール配列
    public init(_ toolkit: some ToolKit) {
        self = toolkit.tools
    }
}
