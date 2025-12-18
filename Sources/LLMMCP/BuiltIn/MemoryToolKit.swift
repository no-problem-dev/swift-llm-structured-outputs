import Foundation
import LLMClient
import LLMTool

// MARK: - MemoryToolKit

/// ナレッジグラフベースの永続メモリシステム
///
/// 公式MCP Memory Serverに準拠した実装です。
/// エンティティ、リレーション、観察を管理するナレッジグラフを提供します。
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     MemoryToolKit()
/// }
///
/// // または永続化ファイルを指定
/// let persistentTools = ToolSet {
///     MemoryToolKit(persistencePath: "~/memory.jsonl")
/// }
/// ```
///
/// ## 提供されるツール
///
/// - `create_entities`: 新しいエンティティを作成
/// - `create_relations`: エンティティ間のリレーションを作成
/// - `add_observations`: 既存エンティティに観察を追加
/// - `delete_entities`: エンティティを削除（関連リレーションも削除）
/// - `delete_observations`: 特定の観察を削除
/// - `delete_relations`: 特定のリレーションを削除
/// - `read_graph`: ナレッジグラフ全体を取得
/// - `search_nodes`: ノードを検索
/// - `open_nodes`: 特定のノードを名前で取得
public final class MemoryToolKit: ToolKit, @unchecked Sendable {
    // MARK: - Properties

    public let name: String = "memory"

    /// ナレッジグラフマネージャー
    private let graphManager: KnowledgeGraphManager

    // MARK: - Initialization

    /// MemoryToolKitを作成
    ///
    /// - Parameter persistencePath: 永続化ファイルパス（nilの場合はメモリのみ）
    public init(persistencePath: String? = nil) {
        self.graphManager = KnowledgeGraphManager(persistencePath: persistencePath)
    }

    // MARK: - ToolKit Protocol

    public var tools: [any Tool] {
        [
            createEntitiesTool,
            createRelationsTool,
            addObservationsTool,
            deleteEntitiesTool,
            deleteObservationsTool,
            deleteRelationsTool,
            readGraphTool,
            searchNodesTool,
            openNodesTool
        ]
    }

    // MARK: - Tool Definitions

    /// create_entities ツール
    private var createEntitiesTool: BuiltInTool {
        BuiltInTool(
            name: "create_entities",
            description: "Create multiple new entities in the knowledge graph",
            inputSchema: .object(
                properties: [
                    "entities": .array(
                        description: "Array of entities to create",
                        items: .object(
                            properties: [
                                "name": .string(description: "Unique name of the entity"),
                                "entityType": .string(description: "Type of the entity (e.g., 'person', 'organization')"),
                                "observations": .array(
                                    description: "Initial observations about the entity",
                                    items: .string()
                                )
                            ],
                            required: ["name", "entityType"]
                        )
                    )
                ],
                required: ["entities"]
            ),
            annotations: ToolAnnotations(
                title: "Create Entities",
                readOnlyHint: false,
                idempotentHint: true,
                openWorldHint: false
            )
        ) { [graphManager] data in
            let input = try JSONDecoder().decode(CreateEntitiesInput.self, from: data)
            let created = await graphManager.createEntities(input.entities)
            let output = try JSONEncoder().encode(created)
            return .json(output)
        }
    }

    /// create_relations ツール
    private var createRelationsTool: BuiltInTool {
        BuiltInTool(
            name: "create_relations",
            description: "Create multiple new relations between entities in the knowledge graph. Relations should be in active voice",
            inputSchema: .object(
                properties: [
                    "relations": .array(
                        description: "Array of relations to create",
                        items: .object(
                            properties: [
                                "from": .string(description: "Name of the source entity"),
                                "to": .string(description: "Name of the target entity"),
                                "relationType": .string(description: "Type of relation in active voice (e.g., 'works_at', 'knows')")
                            ],
                            required: ["from", "to", "relationType"]
                        )
                    )
                ],
                required: ["relations"]
            ),
            annotations: ToolAnnotations(
                title: "Create Relations",
                readOnlyHint: false,
                idempotentHint: true,
                openWorldHint: false
            )
        ) { [graphManager] data in
            let input = try JSONDecoder().decode(CreateRelationsInput.self, from: data)
            let created = await graphManager.createRelations(input.relations)
            let output = try JSONEncoder().encode(created)
            return .json(output)
        }
    }

    /// add_observations ツール
    private var addObservationsTool: BuiltInTool {
        BuiltInTool(
            name: "add_observations",
            description: "Add new observations to existing entities in the knowledge graph",
            inputSchema: .object(
                properties: [
                    "observations": .array(
                        description: "Array of observations to add",
                        items: .object(
                            properties: [
                                "entityName": .string(description: "Name of the entity to add observations to"),
                                "contents": .array(
                                    description: "Observation strings to add",
                                    items: .string()
                                )
                            ],
                            required: ["entityName", "contents"]
                        )
                    )
                ],
                required: ["observations"]
            ),
            annotations: ToolAnnotations(
                title: "Add Observations",
                readOnlyHint: false,
                idempotentHint: true,
                openWorldHint: false
            )
        ) { [graphManager] data in
            let input = try JSONDecoder().decode(AddObservationsInput.self, from: data)
            let result = await graphManager.addObservations(input.observations)
            let output = try JSONEncoder().encode(result)
            return .json(output)
        }
    }

    /// delete_entities ツール
    private var deleteEntitiesTool: BuiltInTool {
        BuiltInTool(
            name: "delete_entities",
            description: "Delete multiple entities and their associated relations from the knowledge graph",
            inputSchema: .object(
                properties: [
                    "entityNames": .array(
                        description: "Names of entities to delete",
                        items: .string()
                    )
                ],
                required: ["entityNames"]
            ),
            annotations: ToolAnnotations(
                title: "Delete Entities",
                readOnlyHint: false,
                destructiveHint: true,
                idempotentHint: true,
                openWorldHint: false
            )
        ) { [graphManager] data in
            let input = try JSONDecoder().decode(DeleteEntitiesInput.self, from: data)
            await graphManager.deleteEntities(input.entityNames)
            return .text("Deleted entities: \(input.entityNames.joined(separator: ", "))")
        }
    }

    /// delete_observations ツール
    private var deleteObservationsTool: BuiltInTool {
        BuiltInTool(
            name: "delete_observations",
            description: "Delete specific observations from entities in the knowledge graph",
            inputSchema: .object(
                properties: [
                    "deletions": .array(
                        description: "Array of observations to delete",
                        items: .object(
                            properties: [
                                "entityName": .string(description: "Name of the entity"),
                                "observations": .array(
                                    description: "Observations to delete",
                                    items: .string()
                                )
                            ],
                            required: ["entityName", "observations"]
                        )
                    )
                ],
                required: ["deletions"]
            ),
            annotations: ToolAnnotations(
                title: "Delete Observations",
                readOnlyHint: false,
                destructiveHint: true,
                idempotentHint: true,
                openWorldHint: false
            )
        ) { [graphManager] data in
            let input = try JSONDecoder().decode(DeleteObservationsInput.self, from: data)
            await graphManager.deleteObservations(input.deletions)
            return .text("Deleted observations successfully")
        }
    }

    /// delete_relations ツール
    private var deleteRelationsTool: BuiltInTool {
        BuiltInTool(
            name: "delete_relations",
            description: "Delete multiple relations from the knowledge graph",
            inputSchema: .object(
                properties: [
                    "relations": .array(
                        description: "Array of relations to delete",
                        items: .object(
                            properties: [
                                "from": .string(description: "Name of the source entity"),
                                "to": .string(description: "Name of the target entity"),
                                "relationType": .string(description: "Type of relation")
                            ],
                            required: ["from", "to", "relationType"]
                        )
                    )
                ],
                required: ["relations"]
            ),
            annotations: ToolAnnotations(
                title: "Delete Relations",
                readOnlyHint: false,
                destructiveHint: true,
                idempotentHint: true,
                openWorldHint: false
            )
        ) { [graphManager] data in
            let input = try JSONDecoder().decode(DeleteRelationsInput.self, from: data)
            await graphManager.deleteRelations(input.relations)
            return .text("Deleted relations successfully")
        }
    }

    /// read_graph ツール
    private var readGraphTool: BuiltInTool {
        BuiltInTool(
            name: "read_graph",
            description: "Read the entire knowledge graph",
            inputSchema: .object(properties: [:], required: []),
            annotations: ToolAnnotations(
                title: "Read Graph",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { [graphManager] _ in
            let graph = await graphManager.readGraph()
            let output = try JSONEncoder().encode(graph)
            return .json(output)
        }
    }

    /// search_nodes ツール
    private var searchNodesTool: BuiltInTool {
        BuiltInTool(
            name: "search_nodes",
            description: "Search for nodes based on matching entity names, types, and observation content",
            inputSchema: .object(
                properties: [
                    "query": .string(description: "Search query string")
                ],
                required: ["query"]
            ),
            annotations: ToolAnnotations(
                title: "Search Nodes",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { [graphManager] data in
            let input = try JSONDecoder().decode(SearchNodesInput.self, from: data)
            let result = await graphManager.searchNodes(query: input.query)
            let output = try JSONEncoder().encode(result)
            return .json(output)
        }
    }

    /// open_nodes ツール
    private var openNodesTool: BuiltInTool {
        BuiltInTool(
            name: "open_nodes",
            description: "Open specific nodes in the knowledge graph by their names",
            inputSchema: .object(
                properties: [
                    "names": .array(
                        description: "Names of entities to retrieve",
                        items: .string()
                    )
                ],
                required: ["names"]
            ),
            annotations: ToolAnnotations(
                title: "Open Nodes",
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { [graphManager] data in
            let input = try JSONDecoder().decode(OpenNodesInput.self, from: data)
            let result = await graphManager.openNodes(names: input.names)
            let output = try JSONEncoder().encode(result)
            return .json(output)
        }
    }
}

// MARK: - Input Types

private struct CreateEntitiesInput: Codable {
    let entities: [Entity]
}

private struct CreateRelationsInput: Codable {
    let relations: [Relation]
}

private struct AddObservationsInput: Codable {
    let observations: [ObservationAddition]
}

private struct DeleteEntitiesInput: Codable {
    let entityNames: [String]
}

private struct DeleteObservationsInput: Codable {
    let deletions: [ObservationDeletion]
}

private struct DeleteRelationsInput: Codable {
    let relations: [Relation]
}

private struct SearchNodesInput: Codable {
    let query: String
}

private struct OpenNodesInput: Codable {
    let names: [String]
}

// MARK: - Data Models

/// ナレッジグラフのエンティティ
public struct Entity: Codable, Equatable, Sendable {
    /// エンティティの一意な名前
    public var name: String

    /// エンティティの種類（例: "person", "organization"）
    public var entityType: String

    /// エンティティに関する観察のリスト
    public var observations: [String]

    public init(name: String, entityType: String, observations: [String] = []) {
        self.name = name
        self.entityType = entityType
        self.observations = observations
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case entityType
        case observations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        entityType = try container.decode(String.self, forKey: .entityType)
        observations = try container.decodeIfPresent([String].self, forKey: .observations) ?? []
    }
}

/// エンティティ間のリレーション
public struct Relation: Codable, Equatable, Sendable, Hashable {
    /// ソースエンティティの名前
    public var from: String

    /// ターゲットエンティティの名前
    public var to: String

    /// リレーションの種類（能動態で記述、例: "works_at", "knows"）
    public var relationType: String

    public init(from: String, to: String, relationType: String) {
        self.from = from
        self.to = to
        self.relationType = relationType
    }
}

/// 観察の追加リクエスト
public struct ObservationAddition: Codable, Sendable {
    public var entityName: String
    public var contents: [String]

    public init(entityName: String, contents: [String]) {
        self.entityName = entityName
        self.contents = contents
    }
}

/// 観察の削除リクエスト
public struct ObservationDeletion: Codable, Sendable {
    public var entityName: String
    public var observations: [String]

    public init(entityName: String, observations: [String]) {
        self.entityName = entityName
        self.observations = observations
    }
}

/// ナレッジグラフ全体
public struct KnowledgeGraph: Codable, Sendable {
    public var entities: [Entity]
    public var relations: [Relation]

    public init(entities: [Entity] = [], relations: [Relation] = []) {
        self.entities = entities
        self.relations = relations
    }
}

// MARK: - KnowledgeGraphManager

/// ナレッジグラフを管理するアクター
actor KnowledgeGraphManager {
    // MARK: - Properties

    private var entities: [String: Entity]
    private var relations: Set<Relation>
    private let persistencePath: String?

    // MARK: - Initialization

    init(persistencePath: String? = nil) {
        self.persistencePath = persistencePath

        // 同期的にファイルから読み込み
        if let path = persistencePath {
            let (loadedEntities, loadedRelations) = Self.loadFromFile(path: path)
            self.entities = loadedEntities
            self.relations = loadedRelations
        } else {
            self.entities = [:]
            self.relations = []
        }
    }

    /// ファイルから同期的に読み込み（nonisolated）
    private static func loadFromFile(path: String) -> ([String: Entity], Set<Relation>) {
        var entities: [String: Entity] = [:]
        var relations: Set<Relation> = []

        let expandedPath = NSString(string: path).expandingTildeInPath
        guard let data = FileManager.default.contents(atPath: expandedPath),
              let content = String(data: data, encoding: .utf8) else {
            return (entities, relations)
        }

        let decoder = JSONDecoder()
        for line in content.components(separatedBy: .newlines) where !line.isEmpty {
            guard let lineData = line.data(using: .utf8) else { continue }

            if let entity = try? decoder.decode(Entity.self, from: lineData) {
                entities[entity.name] = entity
            } else if let relation = try? decoder.decode(Relation.self, from: lineData) {
                relations.insert(relation)
            }
        }

        return (entities, relations)
    }

    // MARK: - Entity Operations

    /// エンティティを作成（既存の名前はスキップ）
    func createEntities(_ newEntities: [Entity]) -> [Entity] {
        var created: [Entity] = []
        for entity in newEntities {
            if entities[entity.name] == nil {
                entities[entity.name] = entity
                created.append(entity)
            }
        }
        saveIfNeeded()
        return created
    }

    /// エンティティを削除（関連リレーションも削除）
    func deleteEntities(_ names: [String]) {
        for name in names {
            entities.removeValue(forKey: name)
            // 関連リレーションも削除
            relations = relations.filter { $0.from != name && $0.to != name }
        }
        saveIfNeeded()
    }

    // MARK: - Relation Operations

    /// リレーションを作成（重複はスキップ）
    func createRelations(_ newRelations: [Relation]) -> [Relation] {
        var created: [Relation] = []
        for relation in newRelations {
            if !relations.contains(relation) {
                relations.insert(relation)
                created.append(relation)
            }
        }
        saveIfNeeded()
        return created
    }

    /// リレーションを削除
    func deleteRelations(_ toDelete: [Relation]) {
        for relation in toDelete {
            relations.remove(relation)
        }
        saveIfNeeded()
    }

    // MARK: - Observation Operations

    /// 観察を追加
    func addObservations(_ additions: [ObservationAddition]) -> [ObservationAddition] {
        var added: [ObservationAddition] = []
        for addition in additions {
            if var entity = entities[addition.entityName] {
                var newObservations: [String] = []
                for obs in addition.contents {
                    if !entity.observations.contains(obs) {
                        entity.observations.append(obs)
                        newObservations.append(obs)
                    }
                }
                entities[addition.entityName] = entity
                if !newObservations.isEmpty {
                    added.append(ObservationAddition(entityName: addition.entityName, contents: newObservations))
                }
            }
        }
        saveIfNeeded()
        return added
    }

    /// 観察を削除
    func deleteObservations(_ deletions: [ObservationDeletion]) {
        for deletion in deletions {
            if var entity = entities[deletion.entityName] {
                entity.observations.removeAll { deletion.observations.contains($0) }
                entities[deletion.entityName] = entity
            }
        }
        saveIfNeeded()
    }

    // MARK: - Query Operations

    /// グラフ全体を取得
    func readGraph() -> KnowledgeGraph {
        KnowledgeGraph(
            entities: Array(entities.values),
            relations: Array(relations)
        )
    }

    /// ノードを検索
    func searchNodes(query: String) -> KnowledgeGraph {
        let lowercaseQuery = query.lowercased()
        let matchingEntities = entities.values.filter { entity in
            entity.name.lowercased().contains(lowercaseQuery) ||
            entity.entityType.lowercased().contains(lowercaseQuery) ||
            entity.observations.contains { $0.lowercased().contains(lowercaseQuery) }
        }

        let entityNames = Set(matchingEntities.map { $0.name })
        let matchingRelations = relations.filter { relation in
            entityNames.contains(relation.from) || entityNames.contains(relation.to)
        }

        return KnowledgeGraph(
            entities: Array(matchingEntities),
            relations: Array(matchingRelations)
        )
    }

    /// 特定のノードを取得
    func openNodes(names: [String]) -> KnowledgeGraph {
        let matchingEntities = names.compactMap { entities[$0] }
        let entityNames = Set(names)
        let matchingRelations = relations.filter { relation in
            entityNames.contains(relation.from) && entityNames.contains(relation.to)
        }

        return KnowledgeGraph(
            entities: matchingEntities,
            relations: Array(matchingRelations)
        )
    }

    // MARK: - Persistence

    private func saveIfNeeded() {
        guard let path = persistencePath else { return }
        saveToFile(path: path)
    }

    private func saveToFile(path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let encoder = JSONEncoder()
        var lines: [String] = []

        for entity in entities.values {
            if let data = try? encoder.encode(entity),
               let line = String(data: data, encoding: .utf8) {
                lines.append(line)
            }
        }

        for relation in relations {
            if let data = try? encoder.encode(relation),
               let line = String(data: data, encoding: .utf8) {
                lines.append(line)
            }
        }

        let content = lines.joined(separator: "\n")
        try? content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
    }
}
