import Foundation

/// 出力スキーマ管理のユースケース
public protocol OutputSchemaUseCase: Sendable {
    func create(name: String, description: String?) -> OutputSchema
    func save(_ schema: OutputSchema) throws
    func load(id: UUID) throws -> OutputSchema
    func loadAll() throws -> [OutputSchema]
    func delete(id: UUID) throws
    func addField(to schema: inout OutputSchema, field: Field)
    func updateField(in schema: inout OutputSchema, field: Field)
    func deleteField(from schema: inout OutputSchema, fieldId: UUID)
    func moveFields(in schema: inout OutputSchema, from: IndexSet, to: Int)
}

public final class OutputSchemaUseCaseImpl: OutputSchemaUseCase, Sendable {
    private let repository: OutputSchemaRepository

    public init(repository: OutputSchemaRepository) {
        self.repository = repository
    }

    public func create(name: String, description: String?) -> OutputSchema {
        OutputSchema(name: name, description: description)
    }

    public func save(_ schema: OutputSchema) throws {
        var updated = schema
        updated.updatedAt = Date()
        try repository.save(updated)
    }

    public func load(id: UUID) throws -> OutputSchema {
        try repository.load(id: id)
    }

    public func loadAll() throws -> [OutputSchema] {
        try repository.loadAll()
    }

    public func delete(id: UUID) throws {
        try repository.delete(id: id)
    }

    public func addField(to schema: inout OutputSchema, field: Field) {
        schema.fields.append(field)
        schema.updatedAt = Date()
    }

    public func updateField(in schema: inout OutputSchema, field: Field) {
        guard let index = schema.fields.firstIndex(where: { $0.id == field.id }) else { return }
        schema.fields[index] = field
        schema.updatedAt = Date()
    }

    public func deleteField(from schema: inout OutputSchema, fieldId: UUID) {
        schema.fields.removeAll { $0.id == fieldId }
        schema.updatedAt = Date()
    }

    public func moveFields(in schema: inout OutputSchema, from: IndexSet, to: Int) {
        var fields = schema.fields
        let itemsToMove = from.sorted().map { fields[$0] }
        for index in from.sorted().reversed() { fields.remove(at: index) }
        let insertionIndex = from.filter { $0 < to }.count
        let adjustedTo = to - insertionIndex
        for (offset, item) in itemsToMove.enumerated() {
            fields.insert(item, at: adjustedTo + offset)
        }
        schema.fields = fields
        schema.updatedAt = Date()
    }
}
