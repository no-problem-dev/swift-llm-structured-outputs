import XCTest
@testable import LLMMCP
import LLMTool

final class UtilityToolKitTests: XCTestCase {

    // MARK: - ToolKit Protocol Tests

    func testUtilityToolKitName() {
        let toolkit = UtilityToolKit()
        XCTAssertEqual(toolkit.name, "utility")
    }

    func testUtilityToolKitToolCount() {
        let toolkit = UtilityToolKit()
        XCTAssertEqual(toolkit.toolCount, 4)
    }

    func testUtilityToolKitToolNames() {
        let toolkit = UtilityToolKit()
        let expectedNames = ["get_current_time", "calculate", "generate_uuid", "sleep"]
        XCTAssertEqual(toolkit.toolNames, expectedNames)
    }

    func testUtilityToolKitInToolSet() {
        let toolkit = UtilityToolKit()
        let toolSet = ToolSet {
            toolkit
        }

        XCTAssertEqual(toolSet.count, 4)
        XCTAssertNotNil(toolSet.tool(named: "get_current_time"))
        XCTAssertNotNil(toolSet.tool(named: "calculate"))
        XCTAssertNotNil(toolSet.tool(named: "generate_uuid"))
        XCTAssertNotNil(toolSet.tool(named: "sleep"))
    }

    // MARK: - get_current_time Tests

    func testGetCurrentTimeDefault() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "get_current_time")!

        let input = try JSONSerialization.data(withJSONObject: [:])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(json?["time"])
            XCTAssertNotNil(json?["timezone"])
            XCTAssertEqual(json?["format"] as? String, "ISO8601")
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testGetCurrentTimeWithFormat() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "get_current_time")!

        let input = try JSONSerialization.data(withJSONObject: ["format": "yyyy-MM-dd"])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let time = json?["time"] as? String
            XCTAssertNotNil(time)
            // Check it matches date format (YYYY-MM-DD)
            XCTAssertTrue(time?.contains("-") ?? false)
            XCTAssertEqual(json?["format"] as? String, "yyyy-MM-dd")
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testGetCurrentTimeWithTimezone() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "get_current_time")!

        let input = try JSONSerialization.data(withJSONObject: ["timezone": "UTC"])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let tz = json?["timezone"] as? String
            // UTC may be represented as GMT on some systems
            XCTAssertTrue(tz == "UTC" || tz == "GMT")
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - calculate Tests

    func testCalculateAdd() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "add",
            "a": 5,
            "b": 3
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["result"] as? Double, 8.0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testCalculateSubtract() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "subtract",
            "a": 10,
            "b": 4
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["result"] as? Double, 6.0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testCalculateMultiply() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "multiply",
            "a": 7,
            "b": 6
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["result"] as? Double, 42.0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testCalculateDivide() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "divide",
            "a": 20,
            "b": 4
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["result"] as? Double, 5.0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testCalculateDivisionByZero() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "divide",
            "a": 10,
            "b": 0
        ])

        do {
            _ = try await tool.execute(with: input)
            XCTFail("Expected division by zero error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("zero"))
        }
    }

    func testCalculatePower() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "power",
            "a": 2,
            "b": 8
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["result"] as? Double, 256.0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testCalculateSqrt() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "sqrt",
            "a": 16
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["result"] as? Double, 4.0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testCalculateSqrtNegative() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "sqrt",
            "a": -4
        ])

        do {
            _ = try await tool.execute(with: input)
            XCTFail("Expected error for negative sqrt")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("negative"))
        }
    }

    func testCalculateAbs() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "abs",
            "a": -42
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["result"] as? Double, 42.0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testCalculateRound() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "round",
            "a": 3.7
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["result"] as? Double, 4.0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testCalculateFloor() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "floor",
            "a": 3.9
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["result"] as? Double, 3.0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testCalculateCeil() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "ceil",
            "a": 3.1
        ])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["result"] as? Double, 4.0)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testCalculateUnknownOperation() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "unknown",
            "a": 10
        ])

        do {
            _ = try await tool.execute(with: input)
            XCTFail("Expected unknown operation error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Unknown operation"))
        }
    }

    func testCalculateMissingOperand() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "calculate")!

        let input = try JSONSerialization.data(withJSONObject: [
            "operation": "add",
            "a": 10
        ])

        do {
            _ = try await tool.execute(with: input)
            XCTFail("Expected missing operand error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("requires operand"))
        }
    }

    // MARK: - generate_uuid Tests

    func testGenerateUUIDDefault() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "generate_uuid")!

        let input = try JSONSerialization.data(withJSONObject: [:])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let uuids = json?["uuids"] as? [String]
            XCTAssertEqual(uuids?.count, 1)
            XCTAssertEqual(json?["format"] as? String, "standard")
            // Check UUID format (lowercase with hyphens)
            if let uuid = uuids?.first {
                XCTAssertTrue(uuid.contains("-"))
                XCTAssertEqual(uuid, uuid.lowercased())
            }
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testGenerateUUIDCompact() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "generate_uuid")!

        let input = try JSONSerialization.data(withJSONObject: ["format": "compact"])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let uuids = json?["uuids"] as? [String]
            if let uuid = uuids?.first {
                XCTAssertFalse(uuid.contains("-"))
                XCTAssertEqual(uuid.count, 32)
            }
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testGenerateUUIDUppercase() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "generate_uuid")!

        let input = try JSONSerialization.data(withJSONObject: ["format": "uppercase"])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let uuids = json?["uuids"] as? [String]
            if let uuid = uuids?.first {
                XCTAssertEqual(uuid, uuid.uppercased())
            }
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testGenerateUUIDMultiple() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "generate_uuid")!

        let input = try JSONSerialization.data(withJSONObject: ["count": 5])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let uuids = json?["uuids"] as? [String]
            XCTAssertEqual(uuids?.count, 5)
            XCTAssertEqual(json?["count"] as? Int, 5)
            // All UUIDs should be unique
            let uniqueUUIDs = Set(uuids ?? [])
            XCTAssertEqual(uniqueUUIDs.count, 5)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testGenerateUUIDCountLimit() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "generate_uuid")!

        // Request more than maximum
        let input = try JSONSerialization.data(withJSONObject: ["count": 200])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let uuids = json?["uuids"] as? [String]
            XCTAssertEqual(uuids?.count, 100) // Limited to 100
        } else {
            XCTFail("Expected JSON result")
        }
    }

    // MARK: - sleep Tests

    func testSleep() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "sleep")!

        let input = try JSONSerialization.data(withJSONObject: ["seconds": 0.1])

        let startTime = Date()
        let result = try await tool.execute(with: input)
        let elapsed = Date().timeIntervalSince(startTime)

        // Should have waited approximately 0.1 seconds
        XCTAssertGreaterThanOrEqual(elapsed, 0.09)
        XCTAssertLessThan(elapsed, 0.2)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["requestedSeconds"] as? Double, 0.1)
            XCTAssertEqual(json?["actualSeconds"] as? Double, 0.1)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testSleepMinimumDuration() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "sleep")!

        // Request less than minimum
        let input = try JSONSerialization.data(withJSONObject: ["seconds": 0.0001])
        let result = try await tool.execute(with: input)

        if case .json(let data) = result {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            // Should be clamped to minimum (0.001)
            XCTAssertEqual(json?["actualSeconds"] as? Double, 0.001)
        } else {
            XCTFail("Expected JSON result")
        }
    }

    func testSleepMaximumDuration() async throws {
        let toolkit = UtilityToolKit()
        let tool = toolkit.tool(named: "sleep")!

        // Request more than maximum
        let input = try JSONSerialization.data(withJSONObject: ["seconds": 100])

        // Don't actually wait 60 seconds, just verify it clamps the value
        let startTime = Date()
        // Cancel after a short time
        let task = Task {
            return try await tool.execute(with: input)
        }

        // Cancel the task after 0.2 seconds
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()

        let elapsed = Date().timeIntervalSince(startTime)

        // Should have been cancelled before 60 seconds
        XCTAssertLessThan(elapsed, 1.0)
    }

    // MARK: - Annotations Tests

    func testReadOnlyToolAnnotations() {
        let toolkit = UtilityToolKit()

        // get_current_time, calculate, generate_uuid are read-only
        for toolName in ["get_current_time", "calculate", "generate_uuid", "sleep"] {
            let tool = toolkit.tool(named: toolName) as? BuiltInTool
            XCTAssertNotNil(tool)
            XCTAssertEqual(tool?.annotations.readOnlyHint, true)
            XCTAssertTrue(tool?.capabilities.isReadOnly ?? false)
            XCTAssertFalse(tool?.capabilities.isDangerous ?? true)
        }
    }

    func testClosedWorldAnnotations() {
        let toolkit = UtilityToolKit()

        // All utility tools are closed world (no external interaction)
        for tool in toolkit.tools {
            if let builtInTool = tool as? BuiltInTool {
                XCTAssertEqual(builtInTool.annotations.openWorldHint, false)
            }
        }
    }
}
