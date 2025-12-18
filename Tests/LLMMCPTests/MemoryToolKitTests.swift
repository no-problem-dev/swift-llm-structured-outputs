import XCTest
@testable import LLMMCP
import LLMTool

final class MemoryToolKitTests: XCTestCase {

    // MARK: - ToolKit Protocol Tests

    func testMemoryToolKitName() {
        let toolkit = MemoryToolKit()
        XCTAssertEqual(toolkit.name, "memory")
    }

    func testMemoryToolKitToolCount() {
        let toolkit = MemoryToolKit()
        XCTAssertEqual(toolkit.toolCount, 9)
    }

    func testMemoryToolKitToolNames() {
        let toolkit = MemoryToolKit()
        let expectedNames = [
            "create_entities",
            "create_relations",
            "add_observations",
            "delete_entities",
            "delete_observations",
            "delete_relations",
            "read_graph",
            "search_nodes",
            "open_nodes"
        ]
        XCTAssertEqual(toolkit.toolNames, expectedNames)
    }

    func testMemoryToolKitInToolSet() {
        let toolkit = MemoryToolKit()
        let toolSet = ToolSet {
            toolkit
        }
        XCTAssertEqual(toolSet.count, 9)
        XCTAssertNotNil(toolSet.tool(named: "create_entities"))
        XCTAssertNotNil(toolSet.tool(named: "read_graph"))
    }

    // MARK: - Entity Operations Tests

    func testCreateEntities() async throws {
        let toolkit = MemoryToolKit()
        let tool = toolkit.tool(named: "create_entities")!

        let input = """
        {
            "entities": [
                {"name": "Alice", "entityType": "person", "observations": ["Works at TechCorp"]},
                {"name": "TechCorp", "entityType": "organization", "observations": ["Founded in 2020"]}
            ]
        }
        """

        let result = try await tool.execute(with: input.data(using: .utf8)!)

        if case .json(let data) = result {
            let created = try JSONDecoder().decode([Entity].self, from: data)
            XCTAssertEqual(created.count, 2)
            XCTAssertEqual(created[0].name, "Alice")
            XCTAssertEqual(created[1].name, "TechCorp")
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testCreateEntitiesSkipsDuplicates() async throws {
        let toolkit = MemoryToolKit()
        let createTool = toolkit.tool(named: "create_entities")!

        // First creation
        let input1 = """
        {"entities": [{"name": "Alice", "entityType": "person"}]}
        """
        _ = try await createTool.execute(with: input1.data(using: .utf8)!)

        // Second creation with same name
        let input2 = """
        {"entities": [{"name": "Alice", "entityType": "person"}]}
        """
        let result = try await createTool.execute(with: input2.data(using: .utf8)!)

        if case .json(let data) = result {
            let created = try JSONDecoder().decode([Entity].self, from: data)
            XCTAssertEqual(created.count, 0) // No new entities created
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testDeleteEntities() async throws {
        let toolkit = MemoryToolKit()
        let createTool = toolkit.tool(named: "create_entities")!
        let deleteTool = toolkit.tool(named: "delete_entities")!
        let readTool = toolkit.tool(named: "read_graph")!

        // Create entity
        let createInput = """
        {"entities": [{"name": "Alice", "entityType": "person"}]}
        """
        _ = try await createTool.execute(with: createInput.data(using: .utf8)!)

        // Delete entity
        let deleteInput = """
        {"entityNames": ["Alice"]}
        """
        _ = try await deleteTool.execute(with: deleteInput.data(using: .utf8)!)

        // Verify deletion
        let result = try await readTool.execute(with: "{}".data(using: .utf8)!)
        if case .json(let data) = result {
            let graph = try JSONDecoder().decode(KnowledgeGraph.self, from: data)
            XCTAssertEqual(graph.entities.count, 0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - Relation Operations Tests

    func testCreateRelations() async throws {
        let toolkit = MemoryToolKit()
        let createEntitiesTool = toolkit.tool(named: "create_entities")!
        let createRelationsTool = toolkit.tool(named: "create_relations")!

        // Create entities first
        let entitiesInput = """
        {"entities": [
            {"name": "Alice", "entityType": "person"},
            {"name": "TechCorp", "entityType": "organization"}
        ]}
        """
        _ = try await createEntitiesTool.execute(with: entitiesInput.data(using: .utf8)!)

        // Create relation
        let relationsInput = """
        {"relations": [{"from": "Alice", "to": "TechCorp", "relationType": "works_at"}]}
        """
        let result = try await createRelationsTool.execute(with: relationsInput.data(using: .utf8)!)

        if case .json(let data) = result {
            let created = try JSONDecoder().decode([Relation].self, from: data)
            XCTAssertEqual(created.count, 1)
            XCTAssertEqual(created[0].from, "Alice")
            XCTAssertEqual(created[0].to, "TechCorp")
            XCTAssertEqual(created[0].relationType, "works_at")
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testDeleteRelations() async throws {
        let toolkit = MemoryToolKit()
        let createEntitiesTool = toolkit.tool(named: "create_entities")!
        let createRelationsTool = toolkit.tool(named: "create_relations")!
        let deleteRelationsTool = toolkit.tool(named: "delete_relations")!
        let readTool = toolkit.tool(named: "read_graph")!

        // Setup
        let entitiesInput = """
        {"entities": [
            {"name": "Alice", "entityType": "person"},
            {"name": "Bob", "entityType": "person"}
        ]}
        """
        _ = try await createEntitiesTool.execute(with: entitiesInput.data(using: .utf8)!)

        let relationsInput = """
        {"relations": [{"from": "Alice", "to": "Bob", "relationType": "knows"}]}
        """
        _ = try await createRelationsTool.execute(with: relationsInput.data(using: .utf8)!)

        // Delete relation
        let deleteInput = """
        {"relations": [{"from": "Alice", "to": "Bob", "relationType": "knows"}]}
        """
        _ = try await deleteRelationsTool.execute(with: deleteInput.data(using: .utf8)!)

        // Verify
        let result = try await readTool.execute(with: "{}".data(using: .utf8)!)
        if case .json(let data) = result {
            let graph = try JSONDecoder().decode(KnowledgeGraph.self, from: data)
            XCTAssertEqual(graph.relations.count, 0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - Observation Operations Tests

    func testAddObservations() async throws {
        let toolkit = MemoryToolKit()
        let createTool = toolkit.tool(named: "create_entities")!
        let addObsTool = toolkit.tool(named: "add_observations")!
        let readTool = toolkit.tool(named: "read_graph")!

        // Create entity
        let createInput = """
        {"entities": [{"name": "Alice", "entityType": "person", "observations": ["Likes coffee"]}]}
        """
        _ = try await createTool.execute(with: createInput.data(using: .utf8)!)

        // Add observation
        let addInput = """
        {"observations": [{"entityName": "Alice", "contents": ["Works remotely"]}]}
        """
        _ = try await addObsTool.execute(with: addInput.data(using: .utf8)!)

        // Verify
        let result = try await readTool.execute(with: "{}".data(using: .utf8)!)
        if case .json(let data) = result {
            let graph = try JSONDecoder().decode(KnowledgeGraph.self, from: data)
            let alice = graph.entities.first { $0.name == "Alice" }
            XCTAssertEqual(alice?.observations.count, 2)
            XCTAssertTrue(alice?.observations.contains("Likes coffee") ?? false)
            XCTAssertTrue(alice?.observations.contains("Works remotely") ?? false)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testDeleteObservations() async throws {
        let toolkit = MemoryToolKit()
        let createTool = toolkit.tool(named: "create_entities")!
        let deleteObsTool = toolkit.tool(named: "delete_observations")!
        let readTool = toolkit.tool(named: "read_graph")!

        // Create entity with observations
        let createInput = """
        {"entities": [{"name": "Alice", "entityType": "person", "observations": ["Obs1", "Obs2"]}]}
        """
        _ = try await createTool.execute(with: createInput.data(using: .utf8)!)

        // Delete one observation
        let deleteInput = """
        {"deletions": [{"entityName": "Alice", "observations": ["Obs1"]}]}
        """
        _ = try await deleteObsTool.execute(with: deleteInput.data(using: .utf8)!)

        // Verify
        let result = try await readTool.execute(with: "{}".data(using: .utf8)!)
        if case .json(let data) = result {
            let graph = try JSONDecoder().decode(KnowledgeGraph.self, from: data)
            let alice = graph.entities.first { $0.name == "Alice" }
            XCTAssertEqual(alice?.observations, ["Obs2"])
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - Query Operations Tests

    func testReadGraph() async throws {
        let toolkit = MemoryToolKit()
        let createTool = toolkit.tool(named: "create_entities")!
        let readTool = toolkit.tool(named: "read_graph")!

        // Create entities
        let createInput = """
        {"entities": [
            {"name": "Alice", "entityType": "person"},
            {"name": "Bob", "entityType": "person"}
        ]}
        """
        _ = try await createTool.execute(with: createInput.data(using: .utf8)!)

        // Read graph
        let result = try await readTool.execute(with: "{}".data(using: .utf8)!)
        if case .json(let data) = result {
            let graph = try JSONDecoder().decode(KnowledgeGraph.self, from: data)
            XCTAssertEqual(graph.entities.count, 2)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testSearchNodes() async throws {
        let toolkit = MemoryToolKit()
        let createTool = toolkit.tool(named: "create_entities")!
        let searchTool = toolkit.tool(named: "search_nodes")!

        // Create entities
        let createInput = """
        {"entities": [
            {"name": "Alice", "entityType": "person", "observations": ["Works at TechCorp"]},
            {"name": "Bob", "entityType": "person", "observations": ["Works at FinCorp"]}
        ]}
        """
        _ = try await createTool.execute(with: createInput.data(using: .utf8)!)

        // Search by name
        let searchInput = """
        {"query": "Alice"}
        """
        let result = try await searchTool.execute(with: searchInput.data(using: .utf8)!)
        if case .json(let data) = result {
            let graph = try JSONDecoder().decode(KnowledgeGraph.self, from: data)
            XCTAssertEqual(graph.entities.count, 1)
            XCTAssertEqual(graph.entities[0].name, "Alice")
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testSearchNodesByObservation() async throws {
        let toolkit = MemoryToolKit()
        let createTool = toolkit.tool(named: "create_entities")!
        let searchTool = toolkit.tool(named: "search_nodes")!

        // Create entities
        let createInput = """
        {"entities": [
            {"name": "Alice", "entityType": "person", "observations": ["Works at TechCorp"]},
            {"name": "Bob", "entityType": "person", "observations": ["Works at FinCorp"]}
        ]}
        """
        _ = try await createTool.execute(with: createInput.data(using: .utf8)!)

        // Search by observation content
        let searchInput = """
        {"query": "TechCorp"}
        """
        let result = try await searchTool.execute(with: searchInput.data(using: .utf8)!)
        if case .json(let data) = result {
            let graph = try JSONDecoder().decode(KnowledgeGraph.self, from: data)
            XCTAssertEqual(graph.entities.count, 1)
            XCTAssertEqual(graph.entities[0].name, "Alice")
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testOpenNodes() async throws {
        let toolkit = MemoryToolKit()
        let createEntitiesTool = toolkit.tool(named: "create_entities")!
        let createRelationsTool = toolkit.tool(named: "create_relations")!
        let openTool = toolkit.tool(named: "open_nodes")!

        // Create entities and relations
        let entitiesInput = """
        {"entities": [
            {"name": "Alice", "entityType": "person"},
            {"name": "Bob", "entityType": "person"},
            {"name": "Charlie", "entityType": "person"}
        ]}
        """
        _ = try await createEntitiesTool.execute(with: entitiesInput.data(using: .utf8)!)

        let relationsInput = """
        {"relations": [
            {"from": "Alice", "to": "Bob", "relationType": "knows"},
            {"from": "Bob", "to": "Charlie", "relationType": "knows"}
        ]}
        """
        _ = try await createRelationsTool.execute(with: relationsInput.data(using: .utf8)!)

        // Open specific nodes
        let openInput = """
        {"names": ["Alice", "Bob"]}
        """
        let result = try await openTool.execute(with: openInput.data(using: .utf8)!)
        if case .json(let data) = result {
            let graph = try JSONDecoder().decode(KnowledgeGraph.self, from: data)
            XCTAssertEqual(graph.entities.count, 2)
            // Only relations between requested nodes
            XCTAssertEqual(graph.relations.count, 1)
            XCTAssertEqual(graph.relations[0].from, "Alice")
            XCTAssertEqual(graph.relations[0].to, "Bob")
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - Cascade Delete Tests

    func testDeleteEntityCascadesRelations() async throws {
        let toolkit = MemoryToolKit()
        let createEntitiesTool = toolkit.tool(named: "create_entities")!
        let createRelationsTool = toolkit.tool(named: "create_relations")!
        let deleteEntitiesTool = toolkit.tool(named: "delete_entities")!
        let readTool = toolkit.tool(named: "read_graph")!

        // Setup
        let entitiesInput = """
        {"entities": [
            {"name": "Alice", "entityType": "person"},
            {"name": "Bob", "entityType": "person"}
        ]}
        """
        _ = try await createEntitiesTool.execute(with: entitiesInput.data(using: .utf8)!)

        let relationsInput = """
        {"relations": [{"from": "Alice", "to": "Bob", "relationType": "knows"}]}
        """
        _ = try await createRelationsTool.execute(with: relationsInput.data(using: .utf8)!)

        // Delete Alice - should also delete the relation
        let deleteInput = """
        {"entityNames": ["Alice"]}
        """
        _ = try await deleteEntitiesTool.execute(with: deleteInput.data(using: .utf8)!)

        // Verify
        let result = try await readTool.execute(with: "{}".data(using: .utf8)!)
        if case .json(let data) = result {
            let graph = try JSONDecoder().decode(KnowledgeGraph.self, from: data)
            XCTAssertEqual(graph.entities.count, 1) // Only Bob remains
            XCTAssertEqual(graph.relations.count, 0) // Relation was cascaded
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - Tool Annotations Tests

    func testReadOnlyToolAnnotations() {
        let toolkit = MemoryToolKit()

        let readGraphTool = toolkit.tools.first { $0.toolName == "read_graph" } as? BuiltInTool
        XCTAssertEqual(readGraphTool?.annotations.readOnlyHint, true)

        let searchNodesTool = toolkit.tools.first { $0.toolName == "search_nodes" } as? BuiltInTool
        XCTAssertEqual(searchNodesTool?.annotations.readOnlyHint, true)

        let openNodesTool = toolkit.tools.first { $0.toolName == "open_nodes" } as? BuiltInTool
        XCTAssertEqual(openNodesTool?.annotations.readOnlyHint, true)
    }

    func testWriteToolAnnotations() {
        let toolkit = MemoryToolKit()

        let createEntitiesTool = toolkit.tools.first { $0.toolName == "create_entities" } as? BuiltInTool
        XCTAssertEqual(createEntitiesTool?.annotations.readOnlyHint, false)
        XCTAssertEqual(createEntitiesTool?.annotations.idempotentHint, true)

        let deleteEntitiesTool = toolkit.tools.first { $0.toolName == "delete_entities" } as? BuiltInTool
        XCTAssertEqual(deleteEntitiesTool?.annotations.destructiveHint, true)
    }

    func testClosedWorldAnnotations() {
        let toolkit = MemoryToolKit()

        // All memory tools should be closed world
        for tool in toolkit.tools {
            if let builtInTool = tool as? BuiltInTool {
                XCTAssertEqual(builtInTool.annotations.openWorldHint, false,
                              "Tool \(tool.toolName) should have openWorldHint = false")
            }
        }
    }
}
