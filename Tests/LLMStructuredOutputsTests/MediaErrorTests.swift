import XCTest
@testable import LLMStructuredOutputs
@testable import LLMClient

final class MediaErrorTests: XCTestCase {

    // MARK: - Error Case Tests

    func testUnsupportedFormat() {
        let error = MediaError.unsupportedFormat("xyz")

        XCTAssertTrue(error.errorDescription?.contains("xyz") ?? false)
        XCTAssertNotNil(error.failureReason)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testSizeLimitExceeded() {
        let error = MediaError.sizeLimitExceeded(size: 30_000_000, maxSize: 20_000_000)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("exceeds") ?? false)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testNotSupportedByProvider() {
        let error = MediaError.notSupportedByProvider(feature: "Audio input", provider: .anthropic)

        XCTAssertTrue(error.errorDescription?.contains("Audio input") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Anthropic") ?? false)
    }

    func testFileReadError() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: nil)
        let error = MediaError.fileReadError(underlyingError)

        XCTAssertTrue(error.errorDescription?.contains("Failed to read file") ?? false)
    }

    func testInvalidMediaData() {
        let error = MediaError.invalidMediaData("corrupted data")

        XCTAssertTrue(error.errorDescription?.contains("corrupted data") ?? false)
    }

    func testMediaTypeMismatch() {
        let error = MediaError.mediaTypeMismatch(expected: "image/jpeg", actual: "image/png")

        XCTAssertTrue(error.errorDescription?.contains("image/jpeg") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("image/png") ?? false)
    }

    func testMissingRequiredParameter() {
        let error = MediaError.missingRequiredParameter("mediaType")

        XCTAssertTrue(error.errorDescription?.contains("mediaType") ?? false)
    }

    func testInvalidURL() {
        let error = MediaError.invalidURL("not-a-valid-url")

        XCTAssertTrue(error.errorDescription?.contains("not-a-valid-url") ?? false)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        XCTAssertEqual(
            MediaError.unsupportedFormat("xyz"),
            MediaError.unsupportedFormat("xyz")
        )
        XCTAssertNotEqual(
            MediaError.unsupportedFormat("xyz"),
            MediaError.unsupportedFormat("abc")
        )

        XCTAssertEqual(
            MediaError.sizeLimitExceeded(size: 100, maxSize: 50),
            MediaError.sizeLimitExceeded(size: 100, maxSize: 50)
        )
        XCTAssertNotEqual(
            MediaError.sizeLimitExceeded(size: 100, maxSize: 50),
            MediaError.sizeLimitExceeded(size: 100, maxSize: 60)
        )

        XCTAssertEqual(
            MediaError.notSupportedByProvider(feature: "test", provider: .anthropic),
            MediaError.notSupportedByProvider(feature: "test", provider: .anthropic)
        )
        XCTAssertNotEqual(
            MediaError.notSupportedByProvider(feature: "test", provider: .anthropic),
            MediaError.notSupportedByProvider(feature: "test", provider: .openai)
        )

        // Different error types are not equal
        XCTAssertNotEqual(
            MediaError.unsupportedFormat("xyz") as MediaError,
            MediaError.invalidMediaData("xyz") as MediaError
        )
    }

    // MARK: - CustomNSError Tests

    func testErrorDomain() {
        XCTAssertEqual(MediaError.errorDomain, "LLMStructuredOutputs.MediaError")
    }

    func testErrorCodes() {
        XCTAssertEqual(MediaError.unsupportedFormat("").errorCode, 1001)
        XCTAssertEqual(MediaError.sizeLimitExceeded(size: 0, maxSize: 0).errorCode, 1002)
        XCTAssertEqual(MediaError.notSupportedByProvider(feature: "", provider: .anthropic).errorCode, 1003)
        XCTAssertEqual(MediaError.fileReadError(NSError(domain: "", code: 0)).errorCode, 1004)
        XCTAssertEqual(MediaError.invalidMediaData("").errorCode, 1005)
        XCTAssertEqual(MediaError.mediaTypeMismatch(expected: "", actual: "").errorCode, 1006)
        XCTAssertEqual(MediaError.missingRequiredParameter("").errorCode, 1007)
        XCTAssertEqual(MediaError.invalidURL("").errorCode, 1008)
    }

    func testErrorUserInfo() {
        let error = MediaError.unsupportedFormat("xyz")
        let userInfo = error.errorUserInfo

        XCTAssertNotNil(userInfo[NSLocalizedDescriptionKey])
        XCTAssertNotNil(userInfo[NSLocalizedFailureReasonErrorKey])
        XCTAssertNotNil(userInfo[NSLocalizedRecoverySuggestionErrorKey])
    }

    // MARK: - Validation Helper Tests

    func testValidateSize() {
        XCTAssertNoThrow(try MediaError.validateSize(100, maxSize: 200))
        XCTAssertNoThrow(try MediaError.validateSize(100, maxSize: 100))

        XCTAssertThrowsError(try MediaError.validateSize(200, maxSize: 100)) { error in
            guard case MediaError.sizeLimitExceeded(let size, let maxSize) = error else {
                XCTFail("Expected sizeLimitExceeded error")
                return
            }
            XCTAssertEqual(size, 200)
            XCTAssertEqual(maxSize, 100)
        }
    }

    func testValidateSupport() {
        // Should not throw for supported type
        XCTAssertNoThrow(try MediaError.validateSupport(ImageMediaType.jpeg, for: .anthropic))
        XCTAssertNoThrow(try MediaError.validateSupport(ImageMediaType.heic, for: .gemini))

        // Should throw for unsupported type
        XCTAssertThrowsError(try MediaError.validateSupport(ImageMediaType.heic, for: .anthropic)) { error in
            guard case MediaError.notSupportedByProvider(_, let provider) = error else {
                XCTFail("Expected notSupportedByProvider error")
                return
            }
            XCTAssertEqual(provider, .anthropic)
        }

        // Audio support validation
        XCTAssertThrowsError(try MediaError.validateSupport(AudioMediaType.wav, for: .anthropic))
        XCTAssertNoThrow(try MediaError.validateSupport(AudioMediaType.wav, for: .openai))
        XCTAssertNoThrow(try MediaError.validateSupport(AudioMediaType.wav, for: .gemini))

        // Video support validation
        XCTAssertThrowsError(try MediaError.validateSupport(VideoMediaType.mp4, for: .anthropic))
        XCTAssertThrowsError(try MediaError.validateSupport(VideoMediaType.mp4, for: .openai))
        XCTAssertNoThrow(try MediaError.validateSupport(VideoMediaType.mp4, for: .gemini))
    }

    // MARK: - Sendable Tests

    func testSendable() {
        let error = MediaError.unsupportedFormat("test")

        Task {
            _ = error
        }

        XCTAssertTrue(true)  // If this compiles, Sendable conformance works
    }
}
