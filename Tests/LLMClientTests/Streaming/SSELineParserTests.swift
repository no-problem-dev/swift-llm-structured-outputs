import Testing
@testable import LLMClient

@Suite("SSE Line Parser")
struct SSELineParserTests {

    @Test("Basic SSE event parsing")
    func basicEventParsing() {
        var parser = SSELineParser()

        // data 行
        let event1 = parser.parseLine("data: hello")
        #expect(event1 == nil) // 空行が来るまで確定しない

        // 空行でイベント確定
        let event2 = parser.parseLine("")
        #expect(event2 != nil)
        #expect(event2?.data == "hello")
        #expect(event2?.event == nil)
    }

    @Test("Event with event type")
    func eventWithType() {
        var parser = SSELineParser()

        _ = parser.parseLine("event: content_block_delta")
        _ = parser.parseLine("data: {\"type\":\"content_block_delta\"}")
        let event = parser.parseLine("")

        #expect(event != nil)
        #expect(event?.event == "content_block_delta")
        #expect(event?.data == "{\"type\":\"content_block_delta\"}")
    }

    @Test("Multiple data lines are joined")
    func multipleDataLines() {
        var parser = SSELineParser()

        _ = parser.parseLine("data: line1")
        _ = parser.parseLine("data: line2")
        let event = parser.parseLine("")

        #expect(event != nil)
        #expect(event?.data == "line1\nline2")
    }

    @Test("Comment lines are ignored")
    func commentLinesIgnored() {
        var parser = SSELineParser()

        _ = parser.parseLine(": this is a comment")
        _ = parser.parseLine("data: actual data")
        let event = parser.parseLine("")

        #expect(event != nil)
        #expect(event?.data == "actual data")
    }

    @Test("Empty line without data yields nothing")
    func emptyLineWithoutData() {
        var parser = SSELineParser()

        let event = parser.parseLine("")
        #expect(event == nil)
    }

    @Test("Multiple events in sequence")
    func multipleEvents() {
        var parser = SSELineParser()

        _ = parser.parseLine("data: first")
        let event1 = parser.parseLine("")
        #expect(event1?.data == "first")

        _ = parser.parseLine("data: second")
        let event2 = parser.parseLine("")
        #expect(event2?.data == "second")
    }
}

@Suite("Data Line Buffer")
struct DataLineBufferTests {

    @Test("Single line in one chunk")
    func singleLine() {
        var buffer = DataLineBuffer()
        let lines = buffer.append("hello\n".data(using: .utf8)!)
        #expect(lines == ["hello"])
    }

    @Test("Multiple lines in one chunk")
    func multipleLines() {
        var buffer = DataLineBuffer()
        let lines = buffer.append("line1\nline2\n".data(using: .utf8)!)
        #expect(lines == ["line1", "line2"])
    }

    @Test("Line split across chunks")
    func splitAcrossChunks() {
        var buffer = DataLineBuffer()
        let lines1 = buffer.append("hel".data(using: .utf8)!)
        #expect(lines1.isEmpty)

        let lines2 = buffer.append("lo\n".data(using: .utf8)!)
        #expect(lines2 == ["hello"])
    }

    @Test("CRLF handling")
    func crlfHandling() {
        var buffer = DataLineBuffer()
        let lines = buffer.append("hello\r\n".data(using: .utf8)!)
        #expect(lines == ["hello"])
    }

    @Test("Empty lines preserved")
    func emptyLines() {
        var buffer = DataLineBuffer()
        let lines = buffer.append("data: test\n\n".data(using: .utf8)!)
        #expect(lines == ["data: test", ""])
    }
}
