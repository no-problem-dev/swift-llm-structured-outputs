import XCTest
@testable import LLMClient

final class MediaSourceTests: XCTestCase {

    // MARK: - Basic Case Tests

    func testBase64Case() {
        let data = Data("Hello, World!".utf8)
        let source = MediaSource.base64(data)

        XCTAssertTrue(source.isBase64)
        XCTAssertFalse(source.isURL)
        XCTAssertFalse(source.isFileReference)
        XCTAssertEqual(source.sourceType, "base64")
    }

    func testURLCase() {
        let url = URL(string: "https://example.com/image.jpg")!
        let source = MediaSource.url(url)

        XCTAssertFalse(source.isBase64)
        XCTAssertTrue(source.isURL)
        XCTAssertFalse(source.isFileReference)
        XCTAssertEqual(source.sourceType, "url")
    }

    func testFileReferenceCase() {
        let source = MediaSource.fileReference(id: "files/abc123")

        XCTAssertFalse(source.isBase64)
        XCTAssertFalse(source.isURL)
        XCTAssertTrue(source.isFileReference)
        XCTAssertEqual(source.sourceType, "fileReference")
    }

    // MARK: - Accessor Tests

    func testBase64StringAccessor() {
        let data = Data("Test Data".utf8)
        let source = MediaSource.base64(data)

        XCTAssertEqual(source.base64String, data.base64EncodedString())
        XCTAssertNil(MediaSource.url(URL(string: "https://example.com")!).base64String)
    }

    func testURLValueAccessor() {
        let url = URL(string: "https://example.com/image.jpg")!
        let source = MediaSource.url(url)

        XCTAssertEqual(source.urlValue, url)
        XCTAssertNil(MediaSource.base64(Data()).urlValue)
    }

    func testFileReferenceIdAccessor() {
        let fileId = "files/abc123"
        let source = MediaSource.fileReference(id: fileId)

        XCTAssertEqual(source.fileReferenceId, fileId)
        XCTAssertNil(MediaSource.base64(Data()).fileReferenceId)
    }

    func testDataAccessor() {
        let data = Data("Test Data".utf8)
        let source = MediaSource.base64(data)

        XCTAssertEqual(source.data, data)
        XCTAssertNil(MediaSource.url(URL(string: "https://example.com")!).data)
    }

    // MARK: - Size Validation Tests

    func testDataSize() {
        let data = Data(repeating: 0, count: 1024)
        let source = MediaSource.base64(data)

        XCTAssertEqual(source.dataSize, 1024)
        XCTAssertNil(MediaSource.url(URL(string: "https://example.com")!).dataSize)
    }

    func testIsWithinSizeLimit() {
        let data = Data(repeating: 0, count: 1024)
        let source = MediaSource.base64(data)

        XCTAssertTrue(source.isWithinSizeLimit(2048))  // Larger limit
        XCTAssertTrue(source.isWithinSizeLimit(1024))  // Exact limit
        XCTAssertFalse(source.isWithinSizeLimit(512))  // Smaller limit

        // URL sources always pass size check (size unknown)
        XCTAssertTrue(MediaSource.url(URL(string: "https://example.com")!).isWithinSizeLimit(1))
    }

    func testValidateSize() throws {
        let data = Data(repeating: 0, count: 1024)
        let source = MediaSource.base64(data)

        // Should not throw
        XCTAssertNoThrow(try source.validateSize(maxBytes: 2048))
        XCTAssertNoThrow(try source.validateSize(maxBytes: 1024))

        // Should throw
        XCTAssertThrowsError(try source.validateSize(maxBytes: 512)) { error in
            guard case MediaError.sizeLimitExceeded(let size, let maxSize) = error else {
                XCTFail("Expected sizeLimitExceeded error")
                return
            }
            XCTAssertEqual(size, 1024)
            XCTAssertEqual(maxSize, 512)
        }

        // URL source should pass without error
        let urlSource = MediaSource.url(URL(string: "https://example.com")!)
        XCTAssertNoThrow(try urlSource.validateSize(maxBytes: 1))
    }

    // MARK: - Codable Tests

    func testBase64Codable() throws {
        let data = Data("Hello, World!".utf8)
        let original = MediaSource.base64(data)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaSource.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    func testURLCodable() throws {
        let url = URL(string: "https://example.com/image.jpg")!
        let original = MediaSource.url(url)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaSource.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    func testFileReferenceCodable() throws {
        let original = MediaSource.fileReference(id: "files/abc123")

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaSource.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let data1 = Data("Test".utf8)
        let data2 = Data("Test".utf8)
        let data3 = Data("Different".utf8)

        XCTAssertEqual(MediaSource.base64(data1), MediaSource.base64(data2))
        XCTAssertNotEqual(MediaSource.base64(data1), MediaSource.base64(data3))

        let url1 = URL(string: "https://example.com")!
        let url2 = URL(string: "https://example.com")!
        let url3 = URL(string: "https://different.com")!

        XCTAssertEqual(MediaSource.url(url1), MediaSource.url(url2))
        XCTAssertNotEqual(MediaSource.url(url1), MediaSource.url(url3))

        XCTAssertEqual(
            MediaSource.fileReference(id: "abc"),
            MediaSource.fileReference(id: "abc")
        )
        XCTAssertNotEqual(
            MediaSource.fileReference(id: "abc"),
            MediaSource.fileReference(id: "def")
        )

        // Different types are not equal
        XCTAssertNotEqual(MediaSource.base64(data1), MediaSource.url(url1))
    }

    // MARK: - Convenience Initializer Tests

    func testFromBase64String() throws {
        let originalData = Data("Hello, World!".utf8)
        let base64String = originalData.base64EncodedString()

        let source = try MediaSource.fromBase64String(base64String)

        XCTAssertEqual(source.data, originalData)
    }

    func testFromBase64StringInvalid() {
        XCTAssertThrowsError(try MediaSource.fromBase64String("!!!invalid!!!")) { error in
            guard case MediaError.invalidMediaData(_) = error else {
                XCTFail("Expected invalidMediaData error")
                return
            }
        }
    }

    // MARK: - CustomStringConvertible Tests

    func testDescription() {
        let data = Data(repeating: 0, count: 256)
        let base64Source = MediaSource.base64(data)
        XCTAssertEqual(base64Source.description, "MediaSource.base64(256 bytes)")

        let urlSource = MediaSource.url(URL(string: "https://example.com/image.jpg")!)
        XCTAssertEqual(urlSource.description, "MediaSource.url(https://example.com/image.jpg)")

        let fileRefSource = MediaSource.fileReference(id: "files/abc123")
        XCTAssertEqual(fileRefSource.description, "MediaSource.fileReference(files/abc123)")
    }

    // MARK: - Sendable Tests

    func testSendable() {
        let source = MediaSource.base64(Data("Test".utf8))

        Task {
            _ = source
        }

        XCTAssertTrue(true)  // If this compiles, Sendable conformance works
    }
}
