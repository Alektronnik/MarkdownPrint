import XCTest
@testable import MarkdownPrintCore
@testable import MarkdownPrint

/// Performance and stress tests.
final class MarkdownPrintBenchmarkTests: XCTestCase {

    // MARK: - Input validation

    func testInputTooLargeThrows() {
        let engine = MarkdownPrintEngine()
        let markdown = String(repeating: "# Hello\n\n", count: 100_000)

        XCTAssertThrowsError(
            try engine.render(markdown, options: .init(maxMarkdownSize: 1_000))
        ) { error in
            guard case MarkdownPrintError.inputTooLarge(let size, let maxAllowed) = error else {
                XCTFail("Expected inputTooLarge, got \(error)")
                return
            }
            XCTAssertEqual(maxAllowed, 1_000)
            XCTAssertGreaterThan(size, 1_000)
        }
    }

    func testInputWithinLimitSucceeds() throws {
        let engine = MarkdownPrintEngine()
        let markdown = "# Hello\n\nWorld."
        let result = try engine.render(markdown, options: .init(maxMarkdownSize: 10_000))
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    // MARK: - Large document rendering

    func testRenderLargeDocument() throws {
        let engine = MarkdownPrintEngine()

        // Generate a multi-page markdown document with mixed content.
        var parts: [String] = []
        for i in 1...15 {
            parts.append("# Section \(i)\n")
            parts.append("This is paragraph one of section \(i). It contains **bold text**, *italic text*, and `inline code` with a [link](https://example.com/\(i)).\n\n")
            parts.append("This is paragraph two. It has ~~strikethrough~~ and more content to fill the page with text that wraps naturally across multiple lines in the document layout.\n\n")
            parts.append("| Column A | Column B | Column C |\n")
            parts.append("|----------|----------|----------|\n")
            parts.append("| Value \(i*3-2) | \(Double(i)*1.5) | \(i*100) |\n")
            parts.append("| Value \(i*3-1) | \(Double(i)*2.5) | \(i*200) |\n\n")
            parts.append("```swift\nfunc section\(i)() -> Int {\n    return \(i) * 42\n}\n```\n\n")
            parts.append("> This is a blockquote for section \(i) with `code` inside.\n\n")
            if i % 10 == 0 {
                parts.append("---\n\n")
            }
        }

        let markdown = parts.joined()
        let start = CFAbsoluteTimeGetCurrent()
        let result = try engine.render(markdown)
        let duration = CFAbsoluteTimeGetCurrent() - start

        XCTAssertGreaterThan(result.pageCount, 4, "Large document should produce multiple pages")
        XCTAssertGreaterThan(result.pdfData.count, 50_000, "Large document should produce substantial PDF")
        XCTAssertLessThan(duration, 30.0, "Large document render should complete within 30 seconds")

        // Log benchmark data for CI/comparison.
        print("[BENCHMARK] pages=\(result.pageCount) size=\(result.pdfData.count) duration=\(String(format: "%.3f", duration))s")
    }

    // MARK: - Concurrent rendering

    func testConcurrentRenderDoesNotCrash() throws {
        let engine = MarkdownPrintEngine()
        let markdown = "# Test\n\nHello world."

        let expectation = XCTestExpectation(description: "All renders complete")
        expectation.expectedFulfillmentCount = 10

        for _ in 0..<10 {
            DispatchQueue.global().async {
                do {
                    let result = try engine.render(markdown)
                    XCTAssertGreaterThan(result.pdfData.count, 100)
                } catch {
                    XCTFail("Concurrent render failed: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 30)
    }
}
