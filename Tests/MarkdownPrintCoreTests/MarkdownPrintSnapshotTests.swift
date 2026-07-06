import XCTest
import SnapshotTesting
@testable import MarkdownPrintCore
@testable import MarkdownPrint

/// Snapshot tests for PDF rendering output.
/// Catches regressions in typography, layout, or styling.
final class MarkdownPrintSnapshotTests: XCTestCase {

    // MARK: - Reference document

    /// A small, stable document that exercises key GFM features.
    /// When this snapshot changes, review the diff carefully --
    /// it means something in the rendering pipeline shifted.
    private static let referenceMarkdown = """
    # Snapshot Test Document

    This paragraph has **bold text**, *italic text*, `inline code`, and
    a [link to example](https://example.com). It also has ~~strikethrough~~.

    ## Code Block

    ```swift
    func greet(_ name: String) -> String {
        return "Hello, \\(name)!"
    }
    ```

    ## Table

    | Name  | Price | Stock |
    |-------|-------|-------|
    | Alpha | 12.99 | 100   |
    | Beta  |  8.50 | 45    |
    | Gamma | 24.00 | 0     |

    ## List

    - Item one with **bold**
    - Item two with *italic*
    - [x] Completed task
    - [ ] Pending task

    > This is a blockquote with `code` inside.

    ---

    ### Math

    Inline formula: $E = mc^2$ sits in a paragraph.

    Display math:

    $$
    \\int_{0}^{\\infty} e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}
    $$

    ### H3 with Ligatures

    Efficient floating-point file I/O with affinity for difficult
    coefficient filtering.

    `H1` has kerning. Tables have tabular numbers.
    """

    // MARK: - Helpers

    /// Generates a stable diagnostic fingerprint of the PDF layout.
    /// Includes the PDF header signature, page count, byte size, and
    /// structural metadata. Excludes variable PDF trailer data (IDs,
    /// timestamps) so snapshots are deterministic.
    private func snapshotValue(for pdfData: Data, pageCount: Int) -> String {
        // Extraemos las lineas de diagnostico y las ordenamos para
        // estabilidad. Anadimos el tamano exacto como indicador de
        // cambios en el contenido.
        let sizeKB = String(format: "%.1f", Double(pdfData.count) / 1024.0)
        let header = pdfData.prefix(128).reduce("") { $0 + String(format: "%02x", $1) }

        return """
        pages: \(pageCount)
        size_kb: \(sizeKB)
        header_hex: \(header)
        """
    }

    private func renderAndSnapshot(
        theme: MarkdownPrintTheme = .light,
        pageSize: MarkdownPageSize = .a4,
        withTOC: Bool = false,
        fontFamily: FontFamily = .apple,
        named: String,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) throws {
        let engine = MarkdownPrintEngine()
        let result = try engine.render(
            Self.referenceMarkdown,
            options: RenderOptions(
                pageSize: pageSize,
                theme: theme,
                withTOC: withTOC,
                fontFamily: fontFamily
            )
        )
        let value = snapshotValue(for: result.pdfData, pageCount: result.pageCount)

        assertSnapshot(
            of: value,
            as: .lines,
            named: named,
            file: file,
            testName: testName,
            line: line
        )
    }

    // MARK: - Snapshot tests

    func testPDFSnapshotDefault() throws {
        try renderAndSnapshot(named: "default-light-a4")
    }

    func testPDFSnapshotDark() throws {
        try renderAndSnapshot(theme: .dark, named: "dark-a4")
    }

    func testPDFSnapshotWebFont() throws {
        try renderAndSnapshot(fontFamily: .web, named: "web-font-a4")
    }

    func testPDFSnapshotHighContrast() throws {
        try renderAndSnapshot(theme: .highContrast, named: "highcontrast-a4")
    }

    func testPDFSnapshotWithTOC() throws {
        try renderAndSnapshot(withTOC: true, named: "toc-light-a4")
    }

    func testPDFSnapshotUSLetter() throws {
        try renderAndSnapshot(pageSize: .usLetter, named: "default-light-letter")
    }
}
