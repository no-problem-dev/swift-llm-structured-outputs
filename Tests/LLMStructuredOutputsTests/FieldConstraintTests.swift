import XCTest
@testable import LLMStructuredOutputs
@testable import LLMClient

final class FieldConstraintTests: XCTestCase {

    // MARK: - Array Constraints

    func testMinItems() {
        let constraint = FieldConstraint.minItems(1)
        XCTAssertEqual(constraint, .minItems(1))
        XCTAssertNotEqual(constraint, .minItems(2))
    }

    func testMaxItems() {
        let constraint = FieldConstraint.maxItems(10)
        XCTAssertEqual(constraint, .maxItems(10))
        XCTAssertNotEqual(constraint, .maxItems(5))
    }

    // MARK: - Numeric Constraints

    func testMinimum() {
        let constraint = FieldConstraint.minimum(0)
        XCTAssertEqual(constraint, .minimum(0))
        XCTAssertNotEqual(constraint, .minimum(1))
    }

    func testMaximum() {
        let constraint = FieldConstraint.maximum(100)
        XCTAssertEqual(constraint, .maximum(100))
        XCTAssertNotEqual(constraint, .maximum(50))
    }

    func testExclusiveMinimum() {
        let constraint = FieldConstraint.exclusiveMinimum(0)
        XCTAssertEqual(constraint, .exclusiveMinimum(0))
        XCTAssertNotEqual(constraint, .minimum(0)) // Different constraint type
    }

    func testExclusiveMaximum() {
        let constraint = FieldConstraint.exclusiveMaximum(100)
        XCTAssertEqual(constraint, .exclusiveMaximum(100))
        XCTAssertNotEqual(constraint, .maximum(100)) // Different constraint type
    }

    // MARK: - String Constraints

    func testMinLength() {
        let constraint = FieldConstraint.minLength(3)
        XCTAssertEqual(constraint, .minLength(3))
        XCTAssertNotEqual(constraint, .minLength(5))
    }

    func testMaxLength() {
        let constraint = FieldConstraint.maxLength(100)
        XCTAssertEqual(constraint, .maxLength(100))
        XCTAssertNotEqual(constraint, .maxLength(50))
    }

    func testPattern() {
        let constraint = FieldConstraint.pattern("^[a-z]+$")
        XCTAssertEqual(constraint, .pattern("^[a-z]+$"))
        XCTAssertNotEqual(constraint, .pattern("^[A-Z]+$"))
    }

    // MARK: - Enum Constraint

    func testEnumConstraint() {
        let constraint = FieldConstraint.enum(["a", "b", "c"])
        XCTAssertEqual(constraint, .enum(["a", "b", "c"]))
        XCTAssertNotEqual(constraint, .enum(["a", "b"]))
        XCTAssertNotEqual(constraint, .enum(["a", "b", "c", "d"]))
    }

    // MARK: - Format Constraints

    func testFormatEmail() {
        let constraint = FieldConstraint.format(.email)
        XCTAssertEqual(constraint, .format(.email))
        XCTAssertNotEqual(constraint, .format(.uri))
    }

    func testFormatUri() {
        let constraint = FieldConstraint.format(.uri)
        XCTAssertEqual(constraint, .format(.uri))
    }

    func testFormatUuid() {
        let constraint = FieldConstraint.format(.uuid)
        XCTAssertEqual(constraint, .format(.uuid))
    }

    func testFormatDate() {
        let constraint = FieldConstraint.format(.date)
        XCTAssertEqual(constraint, .format(.date))
    }

    func testFormatTime() {
        let constraint = FieldConstraint.format(.time)
        XCTAssertEqual(constraint, .format(.time))
    }

    func testFormatDateTime() {
        let constraint = FieldConstraint.format(.dateTime)
        XCTAssertEqual(constraint, .format(.dateTime))

        // Verify raw value for JSON Schema
        XCTAssertEqual(FieldConstraint.StringFormat.dateTime.rawValue, "date-time")
    }

    func testFormatIpv4() {
        let constraint = FieldConstraint.format(.ipv4)
        XCTAssertEqual(constraint, .format(.ipv4))
    }

    func testFormatIpv6() {
        let constraint = FieldConstraint.format(.ipv6)
        XCTAssertEqual(constraint, .format(.ipv6))
    }

    func testFormatHostname() {
        let constraint = FieldConstraint.format(.hostname)
        XCTAssertEqual(constraint, .format(.hostname))
    }

    func testFormatDuration() {
        let constraint = FieldConstraint.format(.duration)
        XCTAssertEqual(constraint, .format(.duration))
    }

    // MARK: - Convenience Extension Tests

    func testItemsRange() {
        let constraints = FieldConstraint.items(1...5)
        XCTAssertEqual(constraints.count, 2)
        XCTAssertEqual(constraints[0], .minItems(1))
        XCTAssertEqual(constraints[1], .maxItems(5))
    }

    func testNumericRange() {
        let constraints = FieldConstraint.range(0...100)
        XCTAssertEqual(constraints.count, 2)
        XCTAssertEqual(constraints[0], .minimum(0))
        XCTAssertEqual(constraints[1], .maximum(100))
    }

    func testLengthRange() {
        let constraints = FieldConstraint.length(3...20)
        XCTAssertEqual(constraints.count, 2)
        XCTAssertEqual(constraints[0], .minLength(3))
        XCTAssertEqual(constraints[1], .maxLength(20))
    }

    // MARK: - Sendable Conformance

    func testSendableConformance() {
        let constraint: FieldConstraint = .minimum(0)

        // Test that constraint can be used in concurrent context
        Task {
            let _ = constraint
        }

        // If this compiles, Sendable conformance works
        XCTAssertTrue(true)
    }

    // MARK: - StringFormat Tests

    func testStringFormatRawValues() {
        XCTAssertEqual(FieldConstraint.StringFormat.email.rawValue, "email")
        XCTAssertEqual(FieldConstraint.StringFormat.uri.rawValue, "uri")
        XCTAssertEqual(FieldConstraint.StringFormat.uuid.rawValue, "uuid")
        XCTAssertEqual(FieldConstraint.StringFormat.date.rawValue, "date")
        XCTAssertEqual(FieldConstraint.StringFormat.time.rawValue, "time")
        XCTAssertEqual(FieldConstraint.StringFormat.dateTime.rawValue, "date-time")
        XCTAssertEqual(FieldConstraint.StringFormat.ipv4.rawValue, "ipv4")
        XCTAssertEqual(FieldConstraint.StringFormat.ipv6.rawValue, "ipv6")
        XCTAssertEqual(FieldConstraint.StringFormat.hostname.rawValue, "hostname")
        XCTAssertEqual(FieldConstraint.StringFormat.duration.rawValue, "duration")
    }

    func testStringFormatEquality() {
        XCTAssertEqual(FieldConstraint.StringFormat.email, .email)
        XCTAssertNotEqual(FieldConstraint.StringFormat.email, .uri)
    }

    func testStringFormatSendable() {
        let format: FieldConstraint.StringFormat = .email

        Task {
            let _ = format
        }

        XCTAssertTrue(true)
    }
}
