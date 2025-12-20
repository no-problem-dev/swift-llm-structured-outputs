import Foundation

// MARK: - BuiltTypeUseCase

/// 型定義管理のユースケース
public protocol BuiltTypeUseCase: Sendable {
    /// 新規型定義を作成
    func create(name: String, description: String?) -> BuiltType

    /// 型定義を保存
    func save(_ type: BuiltType) throws

    /// 型定義を読み込み
    func load(id: UUID) throws -> BuiltType

    /// 全ての型定義を読み込み
    func loadAll() throws -> [BuiltType]

    /// 型定義を削除
    func delete(id: UUID) throws

    /// フィールドを追加
    func addField(to type: inout BuiltType, field: BuiltField)

    /// フィールドを更新
    func updateField(in type: inout BuiltType, field: BuiltField)

    /// フィールドを削除
    func deleteField(from type: inout BuiltType, fieldId: UUID)

    /// フィールドを並び替え
    func moveFields(in type: inout BuiltType, from: IndexSet, to: Int)
}

// MARK: - BuiltTypeUseCaseImpl

public final class BuiltTypeUseCaseImpl: BuiltTypeUseCase, Sendable {

    private let repository: BuiltTypeRepository

    public init(repository: BuiltTypeRepository) {
        self.repository = repository
    }

    public func create(name: String, description: String?) -> BuiltType {
        BuiltType(name: name, description: description)
    }

    public func save(_ type: BuiltType) throws {
        var updatedType = type
        updatedType.updatedAt = Date()
        try repository.save(updatedType)
    }

    public func load(id: UUID) throws -> BuiltType {
        try repository.load(id: id)
    }

    public func loadAll() throws -> [BuiltType] {
        try repository.loadAll()
    }

    public func delete(id: UUID) throws {
        try repository.delete(id: id)
    }

    public func addField(to type: inout BuiltType, field: BuiltField) {
        type.fields.append(field)
        type.updatedAt = Date()
    }

    public func updateField(in type: inout BuiltType, field: BuiltField) {
        guard let index = type.fields.firstIndex(where: { $0.id == field.id }) else {
            return
        }
        type.fields[index] = field
        type.updatedAt = Date()
    }

    public func deleteField(from type: inout BuiltType, fieldId: UUID) {
        type.fields.removeAll { $0.id == fieldId }
        type.updatedAt = Date()
    }

    public func moveFields(in type: inout BuiltType, from: IndexSet, to: Int) {
        // SwiftUIに依存しない手動実装
        var fields = type.fields
        let itemsToMove = from.sorted().map { fields[$0] }

        // 後ろから削除（インデックスがずれないように）
        for index in from.sorted().reversed() {
            fields.remove(at: index)
        }

        // 挿入位置を調整（削除した要素数を考慮）
        let insertionIndex = from.filter { $0 < to }.count
        let adjustedTo = to - insertionIndex

        // 挿入
        for (offset, item) in itemsToMove.enumerated() {
            fields.insert(item, at: adjustedTo + offset)
        }

        type.fields = fields
        type.updatedAt = Date()
    }
}
