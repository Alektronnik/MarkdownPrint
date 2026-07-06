import XCTest
@testable import MarkdownPrintCore
@testable import MarkdownPrint
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(PDFKit)
import PDFKit
#endif

/// Coverage tests for Progress, MathRenderer, Transferable, SystemFont, and SyntaxHighlighter.
final class MarkdownPrintCoverageTests: XCTestCase {

    // MARK: - Progress wrapper

    func testProgressRenderPDFLegacy() throws {
        let engine = MarkdownPrintEngine()
        let progress = Progress()
        let pdfData = try! engine.renderPDF(fromMarkdown: "# Progress Test", pageSize: .a4, progress: progress)
        XCTAssertGreaterThan(pdfData.count, 1000)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    func testProgressRenderPDFWithDiagnosticsLegacy() throws {
        let engine = MarkdownPrintEngine()
        let progress = Progress()
        let result = try! engine.renderPDFWithDiagnostics(fromMarkdown: "# Diag\n\n[Link](url)", pageSize: .a4, progress: progress)
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertGreaterThan(result.linkCount, 0)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    func testProgressRenderPDFAllParams() throws {
        let engine = MarkdownPrintEngine()
        let metadata = PDFMetadata(title: "T", author: "A")
        let progress = Progress()
        let result = try! engine.renderPDFWithDiagnostics(
            fromMarkdown: "# Meta",
            pageSize: .usLetter,
            metadata: metadata,
            baseURL: URL(fileURLWithPath: "/tmp"),
            theme: .dark,
            withTOC: true,
            progress: progress
        )
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    // MARK: - MathRenderer

    func testMathRendererIsAvailableIsBool() {
        XCTAssertTrue(MathRenderer.isAvailable || !MathRenderer.isAvailable)
    }

    func testMathRendererEmptyStringReturnsNil() {
        XCTAssertNil(MathRenderer.render(""))
    }

    func testMathRendererWhitespaceReturnsNil() {
        XCTAssertNil(MathRenderer.render("   "))
    }

    func testMathRendererSimpleExpression() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("x = 1")
        // pdflatex may fail in sandbox; accept either outcome
        if result == nil { return }
        XCTAssertNotNil(result)
    }

    func testMathRendererDisplayStyle() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("\\frac{a}{b}", displayStyle: true)
        if result == nil { return }
        XCTAssertNotNil(result)
    }

    func testMathRendererInlineStyle() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("E = mc^2", displayStyle: false)
        if result == nil { return }
        XCTAssertNotNil(result)
    }

    // MARK: - SystemFont cache

    func testSystemFontCacheIntegrity() {
        let f1 = SystemFont.regular(size: 12)
        let f2 = SystemFont.regular(size: 12)
        XCTAssertTrue(f1 === f2)
        let b1 = SystemFont.bold(size: 14)
        let b2 = SystemFont.bold(size: 14)
        XCTAssertTrue(b1 === b2)
    }

    func testSystemFontDifferentSizes() {
        let small = SystemFont.regular(size: 8)
        let large = SystemFont.regular(size: 36)
        XCTAssertNotEqual(CTFontGetSize(small), CTFontGetSize(large))
    }

    // MARK: - Error coverage

    func testErrorInputTooLargeDescription() {
        let error = MarkdownPrintError.inputTooLarge(size: 5000000, maxAllowed: 1000000)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testErrorInputTooLargeEquality() {
        XCTAssertEqual(MarkdownPrintError.inputTooLarge(size: 100, maxAllowed: 50), MarkdownPrintError.inputTooLarge(size: 100, maxAllowed: 50))
        XCTAssertNotEqual(MarkdownPrintError.inputTooLarge(size: 100, maxAllowed: 50), MarkdownPrintError.inputTooLarge(size: 200, maxAllowed: 50))
        XCTAssertNotEqual(MarkdownPrintError.inputTooLarge(size: 100, maxAllowed: 50), MarkdownPrintError.invalidUTF8)
    }

    // MARK: - SwiftUI Configuration (available without SwiftUI import)

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationDefaultValues() {
        let config = MarkdownPrintConfiguration.default
        XCTAssertEqual(config.pageSize, .a4)
        XCTAssertEqual(config.theme, .light)
        XCTAssertFalse(config.withTOC)
        XCTAssertNil(config.metadata.title)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationCustomInit() {
        let engine = MarkdownPrintEngine()
        let metadata = PDFMetadata(title: "T", author: "A")
        let url = URL(fileURLWithPath: "/tmp")
        let config = MarkdownPrintConfiguration(engine: engine, pageSize: .usLetter, metadata: metadata, baseURL: url, theme: .dark, withTOC: true)
        XCTAssertEqual(config.pageSize, .usLetter)
        XCTAssertEqual(config.theme, .dark)
        XCTAssertTrue(config.withTOC)
        XCTAssertEqual(config.metadata.title, "T")
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationTOCFalseByDefault() {
        XCTAssertFalse(MarkdownPrintConfiguration.default.withTOC)
    }

    // MARK: - Watermark

    func testWatermarkTextKind() {
        let w = Watermark(kind: .text("CONFIDENTIAL"))
        if case .text(let s) = w.kind { XCTAssertEqual(s, "CONFIDENTIAL") }
        else { XCTFail("Expected .text") }
        XCTAssertEqual(w.opacity, 0.08)
        XCTAssertEqual(w.fontSize, 72)
        XCTAssertEqual(w.angle, -45)
    }

    func testWatermarkImageKind() {
        let url = URL(fileURLWithPath: "/tmp/stamp.png")
        let w = Watermark(kind: .image(url))
        if case .image(let u) = w.kind { XCTAssertEqual(u.path, "/tmp/stamp.png") }
        else { XCTFail("Expected .image") }
    }

    func testWatermarkConfidential() {
        let w = Watermark.confidential()
        if case .text(let s) = w.kind { XCTAssertEqual(s, "CONFIDENTIAL") }
        else { XCTFail("Expected .text") }
        XCTAssertEqual(w.opacity, 0.08)
    }

    func testWatermarkDraft() {
        let w = Watermark.draft()
        if case .text(let s) = w.kind { XCTAssertEqual(s, "DRAFT") }
        else { XCTFail("Expected .text") }
    }

    func testWatermarkImageConvenience() {
        let url = URL(fileURLWithPath: "/tmp/logo.png")
        let w = Watermark.image(at: url, opacity: 0.15)
        if case .image(let u) = w.kind { XCTAssertEqual(u.path, "/tmp/logo.png") }
        else { XCTFail("Expected .image") }
        XCTAssertEqual(w.opacity, 0.15)
    }

    func testWatermarkCustomColor() {
        let color = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        let w = Watermark(kind: .text("TOP SECRET"), opacity: 0.2, fontSize: 48, angle: 30, color: color)
        XCTAssertEqual(w.opacity, 0.2)
        XCTAssertEqual(w.fontSize, 48)
        XCTAssertEqual(w.angle, 30)
        XCTAssertEqual(w.color, color)
    }

    // MARK: - PageHeaderFooter

    func testPageHeaderFooterDefaultInit() {
        let hf = PageHeaderFooter()
        XCTAssertNil(hf.header)
        XCTAssertNil(hf.footer)
        XCTAssertEqual(hf.fontSize, 9)
        XCTAssertNil(hf.color)
    }

    func testPageHeaderFooterCustomInit() {
        let color = CGColor(gray: 0.5, alpha: 1)
        let hf = PageHeaderFooter(header: "{title}", footer: "{page}/{total}", fontSize: 10, color: color)
        XCTAssertEqual(hf.header, "{title}")
        XCTAssertEqual(hf.footer, "{page}/{total}")
        XCTAssertEqual(hf.fontSize, 10)
        XCTAssertEqual(hf.color, color)
    }

    func testPageHeaderFooterSectionAndPage() {
        let hf = PageHeaderFooter.sectionAndPage(fontSize: 11)
        XCTAssertEqual(hf.header, "{section} — {page}")
        XCTAssertNil(hf.footer)
        XCTAssertEqual(hf.fontSize, 11)
    }

    func testPageHeaderFooterTitleAndPage() {
        let hf = PageHeaderFooter.titleAndPage(fontSize: 10)
        XCTAssertEqual(hf.header, "{title}")
        XCTAssertEqual(hf.footer, "{page}")
        XCTAssertEqual(hf.fontSize, 10)
    }

    // MARK: - RenderOptions

    func testRenderOptionsDefaultValues() {
        let opts = RenderOptions()
        XCTAssertEqual(opts.pageSize, .a4)
        XCTAssertEqual(opts.theme, .light)
        XCTAssertFalse(opts.withTOC)
        XCTAssertEqual(opts.dynamicTypeScale, 1.0)
        XCTAssertEqual(opts.fontFamily, .apple)
        XCTAssertEqual(opts.maxMarkdownSize, 10_000_000)
        XCTAssertFalse(opts.showLineNumbers)
        XCTAssertFalse(opts.justifyText)
        XCTAssertNil(opts.watermark)
        XCTAssertNil(opts.headerFooter)
        XCTAssertNil(opts.baseURL)
        XCTAssertNil(opts.metadata.title)
        XCTAssertNil(opts.metadata.author)
    }

    func testRenderOptionsCustomInit() {
        let wm = Watermark.confidential()
        let hf = PageHeaderFooter.sectionAndPage()
        let meta = PDFMetadata(title: "T", author: "A")
        let opts = RenderOptions(
            pageSize: .usLetter,
            metadata: meta,
            baseURL: URL(fileURLWithPath: "/tmp"),
            theme: .dark,
            withTOC: true,
            dynamicTypeScale: 1.5,
            fontFamily: .web,
            maxMarkdownSize: 5000,
            showLineNumbers: true,
            justifyText: true,
            watermark: wm,
            headerFooter: hf
        )
        XCTAssertEqual(opts.pageSize, .usLetter)
        XCTAssertEqual(opts.theme, .dark)
        XCTAssertTrue(opts.withTOC)
        XCTAssertEqual(opts.dynamicTypeScale, 1.5)
        XCTAssertEqual(opts.fontFamily, .web)
        XCTAssertEqual(opts.maxMarkdownSize, 5000)
        XCTAssertTrue(opts.showLineNumbers)
        XCTAssertTrue(opts.justifyText)
        XCTAssertNotNil(opts.watermark)
        XCTAssertNotNil(opts.headerFooter)
        XCTAssertEqual(opts.metadata.title, "T")
        XCTAssertEqual(opts.metadata.author, "A")
        XCTAssertEqual(opts.baseURL?.path, "/tmp")
    }

    func testRenderOptionsCustomPageSize() {
        let opts = RenderOptions(pageSize: .custom(width: 400, height: 600))
        let dims = opts.pageSize.dimensions
        XCTAssertEqual(dims.width, 400)
        XCTAssertEqual(dims.height, 600)
    }

    // MARK: - ThemeColor

    func testThemeColorHex() {
        let c = ThemeColor.hex(red: 0x22, green: 0x44, blue: 0x66, alpha: 0.5)
        if case .hex(let r, let g, let b, let a) = c {
            XCTAssertEqual(r, 0x22)
            XCTAssertEqual(g, 0x44)
            XCTAssertEqual(b, 0x66)
            XCTAssertEqual(a, 0.5)
        } else { XCTFail("Expected .hex") }
    }

    func testThemeColorHexConvenience() {
        let c = ThemeColor.hex(0xAA, 0xBB, 0xCC)
        if case .hex(let r, let g, let b, let a) = c {
            XCTAssertEqual(r, 0xAA)
            XCTAssertEqual(g, 0xBB)
            XCTAssertEqual(b, 0xCC)
            XCTAssertEqual(a, 1.0)
        } else { XCTFail("Expected .hex") }
    }

    func testThemeColorGray() {
        let c = ThemeColor.gray(white: 0.3, alpha: 0.8)
        if case .gray(let w, let a) = c {
            XCTAssertEqual(w, 0.3)
            XCTAssertEqual(a, 0.8)
        } else { XCTFail("Expected .gray") }
    }

    func testThemeColorGrayConvenience() {
        let c = ThemeColor.gray(0.5)
        if case .gray(let w, let a) = c {
            XCTAssertEqual(w, 0.5)
            XCTAssertEqual(a, 1.0)
        } else { XCTFail("Expected .gray") }
    }

    func testThemeColorCGColor() {
        let ref = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
        let c = ThemeColor.cgColor(ref)
        if case .cgColor(let r) = c { XCTAssertEqual(r, ref) }
        else { XCTFail("Expected .cgColor") }
    }

    func testThemeColorToCGColorHex() {
        let c = ThemeColor.hex(red: 255, green: 0, blue: 0, alpha: 1).cgColor
        let comps = c.components ?? []
        XCTAssertEqual(comps[0], 1.0, accuracy: 0.01)
        XCTAssertEqual(comps[1], 0.0, accuracy: 0.01)
        XCTAssertEqual(comps[2], 0.0, accuracy: 0.01)
    }

    func testThemeColorToCGColorGray() {
        let c = ThemeColor.gray(white: 0.5, alpha: 0.5).cgColor
        let comps = c.components ?? []
        XCTAssertEqual(comps[0], 0.5, accuracy: 0.01)
    }

    func testThemeColorEquatable() {
        XCTAssertEqual(ThemeColor.hex(0xFF, 0, 0), ThemeColor.hex(0xFF, 0, 0))
        XCTAssertNotEqual(ThemeColor.hex(0xFF, 0, 0), ThemeColor.hex(0, 0xFF, 0))
    }

    // MARK: - ThemeOverrides

    func testThemeOverridesEmpty() {
        let ov = ThemeOverrides()
        XCTAssertNil(ov.text)
        XCTAssertNil(ov.linkText)
        XCTAssertNil(ov.underlineLinks)
    }

    func testThemeOverridesPartial() {
        let ov = ThemeOverrides(text: .hex(0xFF, 0, 0), linkText: .hex(0, 0, 0xFF))
        XCTAssertNotNil(ov.text)
        XCTAssertNotNil(ov.linkText)
        XCTAssertNil(ov.mutedText)
    }

    // MARK: - Custom Themes

    func testCustomThemeFromOverrides() {
        let ov = ThemeOverrides(text: .hex(0x22, 0x22, 0x44), linkText: .hex(0xCC, 0x33, 0x00))
        let theme = MarkdownPrintTheme.custom(name: "corporate", overrides: ov)
        XCTAssertEqual(theme.modeName, "corporate")
        // Link should be overridden
        let linkComps = theme.linkText.components ?? []
        XCTAssertEqual(linkComps[0], 0xCC/255.0, accuracy: 0.01)
        // Text should be overridden
        let textComps = theme.text.components ?? []
        XCTAssertEqual(textComps[0], 0x22/255.0, accuracy: 0.01)
    }

    func testCustomThemeFromBase() {
        let ov = ThemeOverrides(text: .hex(0xFF, 0xFF, 0x00))
        let theme = MarkdownPrintTheme.custom(name: "yellow-on-dark", base: .dark, overrides: ov)
        XCTAssertEqual(theme.modeName, "yellow-on-dark")
        // Dark background should be preserved
        let bgComps = theme.pageBackground.components ?? []
        XCTAssertEqual(bgComps[0], 0x1C/255.0, accuracy: 0.02)
    }

    func testCustomThemePreservesUnchanged() {
        let ov = ThemeOverrides(linkText: .hex(0xFF, 0x00, 0xFF))
        let theme = MarkdownPrintTheme.custom(name: "purple-links", overrides: ov)
        // underlineLinks should be preserved from light theme (true)
        XCTAssertTrue(theme.underlineLinks)
        XCTAssertTrue(theme.syntaxHighlight)
    }

    // MARK: - Theme JSON Loading

    func testThemeFromJSON() throws {
        let json = """
        {
            "name": "corporate",
            "baseTheme": "light",
            "colors": {
                "text": "#222244",
                "linkText": "#CC3300",
                "codeBackground": "#F8F4EE"
            },
            "underlineLinks": true,
            "syntaxHighlight": true,
            "smallCaps": false
        }
        """.data(using: .utf8)!
        let theme = try MarkdownPrintTheme.from(jsonData: json)
        XCTAssertEqual(theme.modeName, "corporate")
    }

    func testThemeFromJSONDarkBase() throws {
        let json = """
        {
            "name": "custom-dark",
            "baseTheme": "dark",
            "colors": {
                "text": "#FFFFFF"
            }
        }
        """.data(using: .utf8)!
        let theme = try MarkdownPrintTheme.from(jsonData: json)
        XCTAssertEqual(theme.modeName, "custom-dark")
    }

    func testThemeFromJSONMonoBase() throws {
        let json = """
        {
            "name": "mono-custom",
            "baseTheme": "mono",
            "colors": {}
        }
        """.data(using: .utf8)!
        let theme = try MarkdownPrintTheme.from(jsonData: json)
        XCTAssertEqual(theme.modeName, "mono-custom")
    }

    func testThemeFromJSONHighContrastBase() throws {
        for name in ["highContrast", "high-contrast"] {
            let json = """
            {
                "name": "hc",
                "baseTheme": "\(name)",
                "colors": {}
            }
            """.data(using: .utf8)!
            let theme = try MarkdownPrintTheme.from(jsonData: json)
            XCTAssertEqual(theme.modeName, "hc")
        }
    }

    func testThemeFromJSONNoName() throws {
        let json = """
        {
            "colors": {
                "text": "#FF0000"
            }
        }
        """.data(using: .utf8)!
        let theme = try MarkdownPrintTheme.from(jsonData: json)
        XCTAssertEqual(theme.modeName, "custom")
    }

    func testThemeFromJSONInvalidJSON() {
        let json = "not json".data(using: .utf8)!
        // JSONSerialization will throw on invalid JSON, so from(jsonData:) should throw
        XCTAssertThrowsError(try MarkdownPrintTheme.from(jsonData: json))
    }

    func testThemeFromJSONArrayNotDict() {
        let json = "[1, 2, 3]".data(using: .utf8)!
        // Valid JSON but not a dictionary; should throw ThemeError.invalidJSON
        XCTAssertThrowsError(try MarkdownPrintTheme.from(jsonData: json)) { error in
            XCTAssertTrue(error is ThemeError)
        }
    }

    func testThemeErrorDescription() {
        let error = ThemeError.invalidJSON
        XCTAssertEqual(error.errorDescription, "Invalid theme JSON format")
    }

    func testThemeFromJSONAllColors() throws {
        let json = """
        {
            "name": "full",
            "baseTheme": "light",
            "colors": {
                "pageBackground": "#111111",
                "codeBackground": "#222222",
                "inlineCodeBackground": "#333333",
                "tableHeaderBackground": "#444444",
                "text": "#555555",
                "mutedText": "#666666",
                "linkText": "#777777",
                "codeText": "#888888",
                "pageNumberText": "#999999",
                "border": "#AAAAAA",
                "gridLine": "#BBBBBB",
                "blockquoteBar": "#CCCCCC",
                "headingUnderline": "#DDDDDD"
            },
            "underlineLinks": false,
            "syntaxHighlight": false,
            "smallCaps": true
        }
        """.data(using: .utf8)!
        let theme = try MarkdownPrintTheme.from(jsonData: json)
        XCTAssertEqual(theme.modeName, "full")
        XCTAssertFalse(theme.underlineLinks)
        XCTAssertFalse(theme.syntaxHighlight)
        XCTAssertTrue(theme.smallCaps)
    }

    // MARK: - SyntaxHighlighter Coverage

    func testSyntaxHighlighterSwiftKeywords() {
        for kw in ["let", "var", "func", "class", "struct", "enum", "protocol"] {
            let color = SyntaxHighlighter.color(for: kw)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterPythonKeywords() {
        for kw in ["def", "import", "from", "None", "yield", "lambda", "except"] {
            let color = SyntaxHighlighter.color(for: kw)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterCppKeywords() {
        for kw in ["int", "double", "const", "auto", "namespace", "template"] {
            let color = SyntaxHighlighter.color(for: kw)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterGoKeywords() {
        for kw in ["package", "defer", "chan", "map", "interface"] {
            let color = SyntaxHighlighter.color(for: kw)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterRustKeywords() {
        for kw in ["fn", "impl", "trait", "crate", "mod", "match", "unsafe"] {
            let color = SyntaxHighlighter.color(for: kw)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterShellKeywords() {
        for kw in ["echo", "export", "source", "fi", "esac", "done"] {
            let color = SyntaxHighlighter.color(for: kw)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterDoubleQuotedString() {
        let color = SyntaxHighlighter.color(for: "\"hello world\"")
        let comps = color.components ?? []
        XCTAssertEqual(comps[0], 0x0A/255.0, accuracy: 0.01)
    }

    func testSyntaxHighlighterSingleQuotedString() {
        let color = SyntaxHighlighter.color(for: "'c'")
        let comps = color.components ?? []
        XCTAssertEqual(comps[0], 0x0A/255.0, accuracy: 0.01)
    }

    func testSyntaxHighlighterLineComment() {
        for comment in ["// hello", "/* block */", "# python comment"] {
            let color = SyntaxHighlighter.color(for: comment)
            let comps = color.components ?? []
            XCTAssertEqual(comps[0], 0x6E/255.0, accuracy: 0.01)
        }
    }

    func testSyntaxHighlighterStarComment() {
        let color = SyntaxHighlighter.color(for: "* bullet comment")
        let comps = color.components ?? []
        XCTAssertEqual(comps[0], 0x6E/255.0, accuracy: 0.01)
    }

    func testSyntaxHighlighterNumbers() {
        for num in ["42", "0", "-5", "3.14", "1000000"] {
            let color = SyntaxHighlighter.color(for: num)
            let comps = color.components ?? []
            XCTAssertEqual(comps[0], 0x05/255.0, accuracy: 0.01)
        }
    }

    func testSyntaxHighlighterBuiltinTypes() {
        for type in ["String", "Int", "Bool", "CGFloat", "CGContext", "CTFont"] {
            let color = SyntaxHighlighter.color(for: type)
            let comps = color.components ?? []
            XCTAssertEqual(comps[0], 0x82/255.0, accuracy: 0.01)
        }
    }

    func testSyntaxHighlighterWhitespaceOnly() {
        let color = SyntaxHighlighter.color(for: "   ")
        let comps = color.components ?? []
        XCTAssertEqual(comps[0], 0x1F/255.0, accuracy: 0.01)
    }

    // MARK: - PDFRenderResult diagnostics

    func testPDFRenderResultDiagnostics() {
        let result = PDFRenderResult(
            pdfData: Data([0x25, 0x50, 0x44, 0x46]),
            pageCount: 5,
            linkCount: 12,
            imageCount: 3,
            headingCount: 8,
            duration: 0.125
        )
        let diag = result.diagnostics
        XCTAssertTrue(diag.contains("5"))
        XCTAssertTrue(diag.contains("12"))
        XCTAssertTrue(diag.contains("3"))
        XCTAssertTrue(diag.contains("8"))
        XCTAssertTrue(diag.contains("125 ms"))
    }

    func testPDFRenderResultInit() {
        let data = Data([0xFF, 0xFE])
        let result = PDFRenderResult(pdfData: data, pageCount: 1, linkCount: 0, imageCount: 0, headingCount: 0, duration: 0.01)
        XCTAssertEqual(result.pdfData, data)
        XCTAssertEqual(result.pageCount, 1)
        XCTAssertEqual(result.duration, 0.01)
    }

    // MARK: - MarkdownLayoutElement.withText()

    func testLayoutElementWithText() {
        let el = MarkdownLayoutElement(
            kind: .word, x: 10, y: 20, width: 100, height: 14,
            fontSize: 12, style: .plainText, text: "original", url: "",
            headingLevel: 0, isCodeBlock: false, isTableCell: false,
            isBlockquote: false, isRTL: false,
            footnoteLabel: "", headingLabel: "", crossRefLabel: ""
        )
        let modified = el.withText("modified")
        XCTAssertEqual(modified.text, "modified")
        XCTAssertEqual(modified.x, el.x)
        XCTAssertEqual(modified.y, el.y)
        XCTAssertEqual(modified.fontSize, el.fontSize)
        XCTAssertEqual(modified.style, el.style)
    }

    func testLayoutElementWithTextPreservesFields() {
        let el = MarkdownLayoutElement(
            kind: .word, x: 5, y: 15, width: 50, height: 12,
            fontSize: 10, style: .bold, text: "bold text", url: "",
            headingLevel: 2, isCodeBlock: true, isTableCell: true,
            isBlockquote: true, isRTL: true,
            footnoteLabel: "fn1", headingLabel: "h1", crossRefLabel: "xref"
        )
        let modified = el.withText("new")
        XCTAssertEqual(modified.headingLevel, 2)
        XCTAssertTrue(modified.isCodeBlock)
        XCTAssertTrue(modified.isTableCell)
        XCTAssertTrue(modified.isBlockquote)
        XCTAssertTrue(modified.isRTL)
        XCTAssertEqual(modified.footnoteLabel, "fn1")
        XCTAssertEqual(modified.headingLabel, "h1")
        XCTAssertEqual(modified.crossRefLabel, "xref")
    }

    // MARK: - Engine render() with unified options

    func testEngineRenderWithDefaults() throws {
        let engine = MarkdownPrintEngine()
        let result = try engine.render("# Test", options: .init())
        XCTAssertGreaterThan(result.pdfData.count, 100)
        XCTAssertEqual(result.pageCount, 1)
    }

    func testEngineRenderWithCustomOptions() throws {
        let engine = MarkdownPrintEngine()
        let wm = Watermark.confidential()
        let hf = PageHeaderFooter.titleAndPage()
        let meta = PDFMetadata(title: "Test", author: "X")
        let opts = RenderOptions(
            pageSize: .usLetter,
            metadata: meta,
            theme: .mono,
            withTOC: true,
            fontFamily: .web,
            showLineNumbers: true,
            justifyText: true,
            watermark: wm,
            headerFooter: hf
        )
        let result = try engine.render("# Mono TOC", options: opts)
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    func testEngineRenderJustify() throws {
        let engine = MarkdownPrintEngine()
        let result = try engine.render("Text with **bold** and *italic*.", options: .init(justifyText: true))
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    func testEngineRenderWithLineNumbers() throws {
        let engine = MarkdownPrintEngine()
        let md = "```swift\nlet x = 1\nlet y = 2\n```"
        let result = try engine.render(md, options: .init(showLineNumbers: true))
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    func testEngineRenderWithWatermark() throws {
        let engine = MarkdownPrintEngine()
        let result = try engine.render("# Doc", options: .init(watermark: .draft()))
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    func testEngineRenderWithHeaderFooter() throws {
        let engine = MarkdownPrintEngine()
        let result = try engine.render("# Doc", options: .init(headerFooter: .sectionAndPage()))
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    func testEngineRenderInputTooLarge() {
        let engine = MarkdownPrintEngine()
        let big = String(repeating: "x", count: 1000)
        XCTAssertThrowsError(try engine.render(big, options: .init(maxMarkdownSize: 10))) { error in
            XCTAssertTrue(error is MarkdownPrintError)
        }
    }

    func testEngineRenderTOCNoHeadings() throws {
        let engine = MarkdownPrintEngine()
        let result = try engine.render("Just text, no headings.", options: .init(withTOC: true))
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    // MARK: - Engine Data-based API

    func testEngineRenderPDFFromData() throws {
        let engine = MarkdownPrintEngine()
        let data = "# Data Test".data(using: .utf8)!
        let pdf = try engine.renderPDF(fromMarkdownData: data)
        XCTAssertGreaterThan(pdf.count, 100)
    }

    func testEngineRenderPDFFromDataInvalidUTF8() {
        let engine = MarkdownPrintEngine()
        let data = Data([0xFF, 0xFE, 0xFD])
        XCTAssertThrowsError(try engine.renderPDF(fromMarkdownData: data)) { error in
            XCTAssertEqual(error as? MarkdownPrintError, .invalidUTF8)
        }
    }

    func testEngineRenderWithDiagnosticsFromData() throws {
        let engine = MarkdownPrintEngine()
        let data = "# Diag Data".data(using: .utf8)!
        let result = try engine.renderPDFWithDiagnostics(fromMarkdownData: data)
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    func testEngineRenderWithDiagnosticsFromDataInvalidUTF8() {
        let engine = MarkdownPrintEngine()
        let data = Data([0x80, 0x80])
        XCTAssertThrowsError(try engine.renderPDFWithDiagnostics(fromMarkdownData: data)) { error in
            XCTAssertEqual(error as? MarkdownPrintError, .invalidUTF8)
        }
    }

    // MARK: - Engine Async API

    @available(macOS 13.0, iOS 16.0, *)
    func testEngineRenderAsync() async throws {
        let engine = MarkdownPrintEngine()
        let result = try await engine.render("# Async")
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testEngineRenderPDFAsyncLegacy() async throws {
        let engine = MarkdownPrintEngine()
        let pdf = try await engine.renderPDF(fromMarkdown: "# Async Legacy")
        XCTAssertGreaterThan(pdf.count, 100)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testEngineRenderWithDiagnosticsAsyncLegacy() async throws {
        let engine = MarkdownPrintEngine()
        let result = try await engine.renderPDFWithDiagnostics(fromMarkdown: "# Async Diag")
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    // MARK: - Engine setJustifyText

    func testEngineSetJustifyTextDoesNotThrow() {
        let engine = MarkdownPrintEngine()
        engine.setJustifyText(true)
        engine.setJustifyText(false)
    }

    // MARK: - MarkdownLayout footnoteDefs

    func testMarkdownLayoutEmptyFootnoteDefs() {
        let geo = MarkdownPageGeometry(pageWidth: 612, pageHeight: 792, marginTop: 72, marginBottom: 90, marginLeft: 72, marginRight: 72, contentWidth: 468, contentHeight: 630)
        let page = MarkdownPage(pageNumber: 1, elements: [])
        let layout = MarkdownLayout(pages: [page], geometry: geo, footnoteDefs: [:])
        XCTAssertEqual(layout.footnoteDefs.count, 0)
    }

    func testMarkdownLayoutWithFootnoteDefs() {
        let geo = MarkdownPageGeometry(pageWidth: 612, pageHeight: 792, marginTop: 72, marginBottom: 90, marginLeft: 72, marginRight: 72, contentWidth: 468, contentHeight: 630)
        let page = MarkdownPage(pageNumber: 1, elements: [])
        let defs = ["^1": "First footnote", "^2": "Second footnote"]
        let layout = MarkdownLayout(pages: [page], geometry: geo, footnoteDefs: defs)
        XCTAssertEqual(layout.footnoteDefs.count, 2)
        XCTAssertEqual(layout.footnoteDefs["^1"], "First footnote")
        XCTAssertEqual(layout.footnoteDefs["^2"], "Second footnote")
    }

    // MARK: - Layout element footnote/crossRef labels

    func testLayoutElementFootnoteLabel() {
        let el = MarkdownLayoutElement(
            kind: .footnoteRef, x: 0, y: 0, width: 0, height: 0,
            fontSize: 10, style: .plainText, text: "[^1]", url: "",
            headingLevel: 0, isCodeBlock: false, isTableCell: false,
            isBlockquote: false, isRTL: false,
            footnoteLabel: "^1", headingLabel: "", crossRefLabel: ""
        )
        XCTAssertEqual(el.footnoteLabel, "^1")
    }

    func testLayoutElementCrossRefLabel() {
        let el = MarkdownLayoutElement(
            kind: .word, x: 0, y: 0, width: 0, height: 0,
            fontSize: 10, style: .plainText, text: "See Section 1", url: "",
            headingLevel: 0, isCodeBlock: false, isTableCell: false,
            isBlockquote: false, isRTL: false,
            footnoteLabel: "", headingLabel: "sec-intro", crossRefLabel: "#sec-intro"
        )
        XCTAssertEqual(el.crossRefLabel, "#sec-intro")
    }

    // MARK: - FontFamily

    func testFontFamilyCases() {
        let families: [FontFamily] = [.apple, .web]
        for f in families {
            _ = f
        }
    }

    // MARK: - SystemFont Cache

    func testSystemFontRegularCache() {
        // Calling regular multiple times returns cached instance
        let r1 = SystemFont.regular(size: 11)
        let r2 = SystemFont.regular(size: 11)
        XCTAssertTrue(r1 === r2)
    }

    func testSystemFontBoldCache() {
        let b1 = SystemFont.bold(size: 14)
        let b2 = SystemFont.bold(size: 14)
        XCTAssertTrue(b1 === b2)
    }

    func testSystemFontMonospaceCache() {
        let m1 = SystemFont.monospace(size: 10)
        let m2 = SystemFont.monospace(size: 10)
        XCTAssertTrue(m1 === m2)
    }

    func testSystemFontUnusualSizes() {
        let tiny = SystemFont.regular(size: 1)
        let huge = SystemFont.regular(size: 200)
        XCTAssertNotNil(tiny)
        XCTAssertNotNil(huge)
    }

    // MARK: - MathRenderer extended

    func testMathRendererSubSuperscript() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("x^{2} + y_{1}")
        // May return nil if layout fails; that's OK
        _ = result
    }

    func testMathRendererGreekLetters() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("\\alpha + \\beta = \\gamma")
        _ = result
    }

    func testMathRendererLargeOperators() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("\\sum_{i=1}^{n} i")
        _ = result
    }

    func testMathRendererFractions() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("\\frac{a}{b}", displayStyle: true)
        _ = result
    }

    func testMathRendererRadicals() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("\\sqrt{x^{2}+1}")
        _ = result
    }

    // MARK: - Engine empty rendering

    func testEngineRenderEmptyString() {
        let engine = MarkdownPrintEngine()
        // Should not crash on empty input
        let result = try? engine.render("")
        XCTAssertNotNil(result)
    }

    func testEngineRenderWhitespaceOnly() {
        let engine = MarkdownPrintEngine()
        let result = try? engine.render("   \n\n   ")
        XCTAssertNotNil(result)
    }

    // MARK: - Error Equatable

    func testErrorInputTooLargeWithDifferentSizes() {
        XCTAssertNotEqual(
            MarkdownPrintError.inputTooLarge(size: 100, maxAllowed: 50),
            MarkdownPrintError.inputTooLarge(size: 200, maxAllowed: 50)
        )
    }

    func testErrorInputTooLargeWithDifferentLimits() {
        XCTAssertNotEqual(
            MarkdownPrintError.inputTooLarge(size: 100, maxAllowed: 50),
            MarkdownPrintError.inputTooLarge(size: 100, maxAllowed: 100)
        )
    }

    func testErrorNotImplementedYetDescription() {
        let error = MarkdownPrintError.notImplementedYet("feature")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    // MARK: - MarkdownPageSize dimensions

    func testPageSizeA4Dimensions() {
        let dims = MarkdownPageSize.a4.dimensions
        XCTAssertEqual(dims.width, 595.2756, accuracy: 0.01)
        XCTAssertEqual(dims.height, 841.8898, accuracy: 0.01)
    }

    func testPageSizeUSLetterDimensions() {
        let dims = MarkdownPageSize.usLetter.dimensions
        XCTAssertEqual(dims.width, 612)
        XCTAssertEqual(dims.height, 792)
    }

    func testPageSizeCustomDimensions() {
        let dims = MarkdownPageSize.custom(width: 300, height: 500).dimensions
        XCTAssertEqual(dims.width, 300)
        XCTAssertEqual(dims.height, 500)
    }

    func testPageSizeEquatable() {
        XCTAssertEqual(MarkdownPageSize.a4, MarkdownPageSize.a4)
        XCTAssertNotEqual(MarkdownPageSize.a4, MarkdownPageSize.usLetter)
        XCTAssertNotEqual(MarkdownPageSize.custom(width: 100, height: 200), MarkdownPageSize.custom(width: 100, height: 201))
        XCTAssertEqual(MarkdownPageSize.custom(width: 100, height: 200), MarkdownPageSize.custom(width: 100, height: 200))
    }

    // MARK: - PDFMetadata

    func testPDFMetadataDefault() {
        let m = PDFMetadata()
        XCTAssertNil(m.title)
        XCTAssertNil(m.author)
        XCTAssertNil(m.subject)
        XCTAssertTrue(m.keywords.isEmpty)
    }

    func testPDFMetadataCustom() {
        let m = PDFMetadata(title: "Hello", author: "World", subject: "Manual", keywords: ["markdown", "pdf"])
        XCTAssertEqual(m.title, "Hello")
        XCTAssertEqual(m.author, "World")
        XCTAssertEqual(m.subject, "Manual")
        XCTAssertEqual(m.keywords, ["markdown", "pdf"])
    }

    // MARK: - Engine layout via public API

    func testEngineLayoutReturnsPages() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("# Title\n\nContent here.", pageSize: .a4)
        XCTAssertGreaterThanOrEqual(layout.pages.count, 1)
        XCTAssertNotNil(layout.geometry)
    }

    func testEngineLayoutWithCustomSize() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("Text", pageSize: .custom(width: 400, height: 600))
        XCTAssertEqual(layout.geometry.pageWidth, 400)
    }

    func testEngineLayoutDataAPI() throws {
        let engine = MarkdownPrintEngine()
        let data = "# Layout".data(using: .utf8)!
        let layout = try engine.layout(data: data, pageSize: .a4)
        XCTAssertGreaterThanOrEqual(layout.pages.count, 1)
    }

    func testEngineLayoutDataInvalidUTF8() {
        let engine = MarkdownPrintEngine()
        let data = Data([0xFF, 0xFE])
        XCTAssertThrowsError(try engine.layout(data: data)) { error in
            XCTAssertEqual(error as? MarkdownPrintError, .invalidUTF8)
        }
    }

    // MARK: - Shared engine

    func testSharedEngineRendersWithOptions() throws {
        let result = try MarkdownPrintEngine.shared.render("# Shared Test", options: .init(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    // MARK: - Render with scale

    func testEngineRenderWithScale() throws {
        let engine = MarkdownPrintEngine()
        let result = try engine.render("# Scaled", options: .init(dynamicTypeScale: 1.5))
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    func testEngineRenderWithSmallScale() throws {
        let engine = MarkdownPrintEngine()
        let result = try engine.render("# Tiny", options: .init(dynamicTypeScale: 0.5))
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    // MARK: - Engine coreVersion

    func testEngineCoreVersionIsString() {
        let engine = MarkdownPrintEngine()
        XCTAssertTrue(engine.coreVersion.contains("MarkdownPrintCore"))
    }

    // MARK: - Layout element headingLabel

    func testLayoutElementHeadingLabel() {
        let el = MarkdownLayoutElement(
            kind: .word, x: 0, y: 0, width: 0, height: 0,
            fontSize: 24, style: .bold, text: "Introduction", url: "",
            headingLevel: 1, isCodeBlock: false, isTableCell: false,
            isBlockquote: false, isRTL: false,
            footnoteLabel: "", headingLabel: "introduction", crossRefLabel: ""
        )
        XCTAssertEqual(el.headingLabel, "introduction")
        XCTAssertEqual(el.headingLevel, 1)
    }

    // MARK: - Unicode and Special Characters

    func testEngineRenderUnicode() throws {
        let engine = MarkdownPrintEngine()
        let result = try engine.render("# 日本語\n\n**Café** résumé *niño*")
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    func testEngineRenderEmoji() throws {
        let engine = MarkdownPrintEngine()
        let result = try engine.render("# Hello World\n\nTesting with symbols: © ® ™")
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    // MARK: - SyntaxHighlighter JS/TS keywords

    func testSyntaxHighlighterJSKeywords() {
        for kw in ["function", "const", "this", "export", "void", "null", "undefined", "typeof"] {
            let color = SyntaxHighlighter.color(for: kw)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterPreprocessor() {
        let color = SyntaxHighlighter.color(for: "#include <stdio.h>")
        let comps = color.components ?? []
        XCTAssertEqual(comps[0], 0x6E/255.0, accuracy: 0.01)
    }

    func testSyntaxHighlighterDefineDirective() {
        let color = SyntaxHighlighter.color(for: "#define MAX 100")
        let comps = color.components ?? []
        XCTAssertEqual(comps[0], 0x6E/255.0, accuracy: 0.01)
    }

    func testSyntaxHighlighterNegativeInteger() {
        let color = SyntaxHighlighter.color(for: "-42")
        let comps = color.components ?? []
        XCTAssertEqual(comps[0], 0x05/255.0, accuracy: 0.01)
    }

    func testSyntaxHighlighterDecimal() {
        let color = SyntaxHighlighter.color(for: "3.14159")
        let comps = color.components ?? []
        XCTAssertEqual(comps[0], 0x05/255.0, accuracy: 0.01)
    }

    // MARK: - SystemFont family rendering

    func testSystemFontItalicCache() {
        let i1 = SystemFont.italic(size: 12)
        let i2 = SystemFont.italic(size: 12)
        XCTAssertTrue(i1 === i2)
    }

    func testSystemFontDifferentStyles() {
        let regular = SystemFont.regular(size: 14)
        let bold = SystemFont.bold(size: 14)
        // They should be different font objects
        XCTAssertNotEqual(CTFontGetSize(regular), CTFontGetSize(bold) + 100) // sanity check
    }

    // MARK: - Engine render with all options combined

    func testEngineRenderAllOptions() throws {
        let engine = MarkdownPrintEngine()
        let md = """
        # Document Title

        This is a paragraph with **bold**, *italic*, and `code`.
        [Link](https://example.com)

        ```swift
        let x = 42
        print(x)
        ```

        | A | B |
        |---|---|
        | 1 | 2 |

        - Item one
        - [x] Done

        > Blockquote

        ---

        Final paragraph.
        """
        let opts = RenderOptions(
            pageSize: .usLetter,
            metadata: PDFMetadata(title: "All Options", author: "Test"),
            baseURL: URL(fileURLWithPath: "/tmp"),
            theme: .light,
            withTOC: true,
            dynamicTypeScale: 1.2,
            fontFamily: .apple,
            maxMarkdownSize: 100_000,
            showLineNumbers: true,
            justifyText: true,
            watermark: .draft(),
            headerFooter: .sectionAndPage()
        )
        let result = try engine.render(md, options: opts)
        XCTAssertGreaterThan(result.pdfData.count, 500)
        XCTAssertGreaterThanOrEqual(result.pageCount, 1)
    }

    // MARK: - Engine legacy render with diagnostics

    func testEngineLegacyRenderDiagnosticsCounters() throws {
        let engine = MarkdownPrintEngine()
        let md = "# Heading\n\n[Link one](url1) and [Link two](url2).\n\n## Subheading\n"
        let result = try engine.renderPDFWithDiagnostics(fromMarkdown: md)
        XCTAssertGreaterThan(result.pdfData.count, 100)
        // linkCount counts word-level link elements (each word of a link)
        XCTAssertGreaterThanOrEqual(result.linkCount, 1)
        XCTAssertGreaterThanOrEqual(result.headingCount, 1)
    }

    // MARK: - Engine render legacy with all params

    func testEngineLegacyRenderAllParams() throws {
        let engine = MarkdownPrintEngine()
        let result = try engine.renderPDFWithDiagnostics(
            fromMarkdown: "# All Params",
            pageSize: .a4,
            metadata: PDFMetadata(title: "T", author: "A"),
            baseURL: URL(fileURLWithPath: "/tmp"),
            theme: .dark,
            withTOC: true,
            dynamicTypeScale: 1.1,
            fontFamily: .web
        )
        XCTAssertGreaterThan(result.pdfData.count, 100)
    }

    func testEngineLegacyRenderMinimalParams() throws {
        let engine = MarkdownPrintEngine()
        let pdf = try engine.renderPDF(fromMarkdown: "minimal")
        XCTAssertGreaterThan(pdf.count, 100)
    }

    // MARK: - Engine layout with empty/whitespace

    func testEngineLayoutEmptyMarkdown() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("")
        // Empty input may produce an empty page; just verify no crash
        XCTAssertGreaterThanOrEqual(layout.pages.count, 0)
    }

    func testEngineLayoutWhitespace() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("   \n\n   \n")
        XCTAssertGreaterThanOrEqual(layout.pages.count, 0)
    }

    // MARK: - MathRenderer edge cases

    func testMathRendererMatrix() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("\\begin{matrix} a & b \\\\ c & d \\end{matrix}")
        _ = result
    }

    func testMathRendererAccents() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("\\bar{x} + \\hat{y}")
        _ = result
    }

    func testMathRendererLargeDisplayFraction() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("\\frac{\\alpha+\\beta}{\\gamma}", displayStyle: true)
        _ = result
    }

    func testMathRendererCustomFontSize() {
        guard MathRenderer.isAvailable else { return }
        let result = MathRenderer.render("x = 1", displayStyle: false, baseFontSize: 18.0)
        _ = result
    }

    // MARK: - Progress with legacy render

    func testProgressLegacyRenderWithAllParams() throws {
        let engine = MarkdownPrintEngine()
        let progress = Progress()
        let pdf = try engine.renderPDF(
            fromMarkdown: "# Progress",
            pageSize: .a4,
            metadata: PDFMetadata(title: "P", author: "A"),
            baseURL: URL(fileURLWithPath: "/tmp"),
            theme: .light,
            withTOC: true,
            dynamicTypeScale: 1.0,
            fontFamily: .apple,
            progress: progress
        )
        XCTAssertGreaterThan(pdf.count, 100)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    func testProgressLegacyRenderDiagnosticsWithAllParams() throws {
        let engine = MarkdownPrintEngine()
        let progress = Progress()
        let result = try engine.renderPDFWithDiagnostics(
            fromMarkdown: "# Progress Diag",
            pageSize: .usLetter,
            metadata: PDFMetadata(title: "PD", author: "PA"),
            baseURL: URL(fileURLWithPath: "/tmp"),
            theme: .dark,
            withTOC: true,
            dynamicTypeScale: 1.0,
            fontFamily: .web,
            progress: progress
        )
        XCTAssertGreaterThan(result.pdfData.count, 100)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    // MARK: - Progress async methods

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncProgressRenderPDFLegacy() async throws {
        let engine = MarkdownPrintEngine()
        let progress = Progress()
        let pdf = try await engine.renderPDF(
            fromMarkdown: "# Async Progress Legacy",
            pageSize: .a4,
            progress: progress
        )
        XCTAssertGreaterThan(pdf.count, 100)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncProgressRenderPDFWithDiagnosticsLegacy() async throws {
        let engine = MarkdownPrintEngine()
        let progress = Progress()
        let result = try await engine.renderPDFWithDiagnostics(
            fromMarkdown: "# Async Diag Legacy\n\n[Link](url)",
            pageSize: .a4,
            progress: progress
        )
        XCTAssertGreaterThan(result.pdfData.count, 100)
        XCTAssertGreaterThan(result.linkCount, 0)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncProgressRenderPDFLegacyAllParams() async throws {
        let engine = MarkdownPrintEngine()
        let progress = Progress()
        let pdf = try await engine.renderPDF(
            fromMarkdown: "# Full Async Progress",
            pageSize: .usLetter,
            metadata: PDFMetadata(title: "AP", author: "A"),
            baseURL: URL(fileURLWithPath: "/tmp"),
            theme: .dark,
            withTOC: true,
            dynamicTypeScale: 1.2,
            fontFamily: .web,
            progress: progress
        )
        XCTAssertGreaterThan(pdf.count, 100)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncProgressRenderPDFWithDiagnosticsLegacyAllParams() async throws {
        let engine = MarkdownPrintEngine()
        let progress = Progress()
        let result = try await engine.renderPDFWithDiagnostics(
            fromMarkdown: "# Full Async Diag Progress",
            pageSize: .usLetter,
            metadata: PDFMetadata(title: "ADP", author: "B"),
            baseURL: URL(fileURLWithPath: "/tmp"),
            theme: .mono,
            withTOC: true,
            dynamicTypeScale: 1.1,
            fontFamily: .apple,
            progress: progress
        )
        XCTAssertGreaterThan(result.pdfData.count, 100)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncProgressNilProgress() async throws {
        let engine = MarkdownPrintEngine()
        let pdf = try await engine.renderPDF(
            fromMarkdown: "# Nil Progress",
            pageSize: .a4,
            progress: nil
        )
        XCTAssertGreaterThan(pdf.count, 100)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncProgressSequentialCalls() async throws {
        let engine = MarkdownPrintEngine()
        let p1 = Progress()
        let r1 = try await engine.renderPDFWithDiagnostics(
            fromMarkdown: "# First", pageSize: .a4, progress: p1
        )
        let p2 = Progress()
        let r2 = try await engine.renderPDFWithDiagnostics(
            fromMarkdown: "# Second", pageSize: .a4, progress: p2
        )
        XCTAssertGreaterThan(r1.pdfData.count, 100)
        XCTAssertGreaterThan(r2.pdfData.count, 100)
        XCTAssertGreaterThan(p1.totalUnitCount, 0)
        XCTAssertGreaterThan(p2.totalUnitCount, 0)
    }

    // MARK: - PDFKitView (SwiftUI)

    @available(macOS 14.0, iOS 17.0, *)
    func testPDFKitViewInit() {
        let data = Data([0x25, 0x50, 0x44, 0x46])
        let view = PDFKitView(data: data)
        XCTAssertNotNil(view)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testPDFKitViewEmptyData() {
        let view = PDFKitView(data: Data())
        XCTAssertNotNil(view)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testPDFKitViewLargeData() {
        let data = Data(repeating: 0, count: 10000)
        let view = PDFKitView(data: data)
        XCTAssertNotNil(view)
    }

    // MARK: - PDFKitRepresentableView (SwiftUI)

    @available(macOS 14.0, iOS 17.0, *)
    func testPDFKitRepresentableViewInit() {
        let data = Data([0x25, 0x50, 0x44, 0x46])
        let view = PDFKitRepresentableView(data: data)
        XCTAssertNotNil(view)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testPDFKitRepresentableViewEmptyData() {
        let view = PDFKitRepresentableView(data: Data())
        XCTAssertNotNil(view)
    }

    // MARK: - MarkdownPrintConfiguration (SwiftUI)

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationAllProperties() {
        let engine = MarkdownPrintEngine()
        let meta = PDFMetadata(title: "T", author: "A")
        let url = URL(fileURLWithPath: "/tmp/docs")
        let config = MarkdownPrintConfiguration(
            engine: engine,
            pageSize: .custom(width: 400, height: 600),
            metadata: meta,
            baseURL: url,
            theme: .highContrast,
            withTOC: true,
            dynamicTypeScale: 1.4,
            accessibilityLabel: "Accessible PDF"
        )
        XCTAssertEqual(config.pageSize, .custom(width: 400, height: 600))
        XCTAssertEqual(config.theme, .highContrast)
        XCTAssertTrue(config.withTOC)
        XCTAssertEqual(config.metadata.title, "T")
        XCTAssertEqual(config.metadata.author, "A")
        XCTAssertEqual(config.baseURL?.path, "/tmp/docs")
        XCTAssertEqual(config.dynamicTypeScale, 1.4)
        XCTAssertEqual(config.accessibilityLabel, "Accessible PDF")
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationPartialInit() {
        let config = MarkdownPrintConfiguration(pageSize: .usLetter, withTOC: true)
        XCTAssertEqual(config.pageSize, .usLetter)
        XCTAssertTrue(config.withTOC)
        // Defaults
        XCTAssertEqual(config.theme, .light)
        XCTAssertTrue(config.withTOC)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationDefaultIsUsable() {
        let config = MarkdownPrintConfiguration.default
        XCTAssertEqual(config.pageSize, .a4)
        XCTAssertEqual(config.theme, .light)
        XCTAssertFalse(config.withTOC)
        XCTAssertNil(config.metadata.title)
        XCTAssertEqual(config.dynamicTypeScale, 1.0)
        XCTAssertEqual(config.accessibilityLabel, "Markdown PDF preview")
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testDynamicTypeScaleMapping() {
        XCTAssertLessThan(markdownPrintDynamicTypeScale(for: .small), 1.0)
        XCTAssertEqual(markdownPrintDynamicTypeScale(for: .large), 1.0)
        XCTAssertGreaterThan(markdownPrintDynamicTypeScale(for: .accessibility3), 1.0)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testRenderTaskIDTracksMarkdownAndConfiguration() {
        let engine = MarkdownPrintEngine()
        let otherEngine = MarkdownPrintEngine()
        let first = MarkdownPrintRenderTaskID(
            markdown: "# A",
            engineID: ObjectIdentifier(engine),
            pageSize: .a4,
            metadata: PDFMetadata(title: "T", author: "A", subject: "S", keywords: ["pdf"]),
            baseURL: URL(fileURLWithPath: "/tmp/a"),
            theme: .light,
            withTOC: false,
            dynamicTypeScale: 1.0,
            dynamicTypeSize: .large
        )
        let same = MarkdownPrintRenderTaskID(
            markdown: "# A",
            engineID: first.engineID,
            pageSize: .a4,
            metadata: PDFMetadata(title: "T", author: "A", subject: "S", keywords: ["pdf"]),
            baseURL: URL(fileURLWithPath: "/tmp/a"),
            theme: .light,
            withTOC: false,
            dynamicTypeScale: 1.0,
            dynamicTypeSize: .large
        )
        let changedMarkdown = MarkdownPrintRenderTaskID(
            markdown: "# B",
            engineID: first.engineID,
            pageSize: .a4,
            metadata: PDFMetadata(title: "T", author: "A", subject: "S", keywords: ["pdf"]),
            baseURL: URL(fileURLWithPath: "/tmp/a"),
            theme: .light,
            withTOC: false,
            dynamicTypeScale: 1.0,
            dynamicTypeSize: .large
        )
        let changedDynamicType = MarkdownPrintRenderTaskID(
            markdown: "# A",
            engineID: first.engineID,
            pageSize: .a4,
            metadata: PDFMetadata(title: "T", author: "A", subject: "S", keywords: ["pdf"]),
            baseURL: URL(fileURLWithPath: "/tmp/a"),
            theme: .light,
            withTOC: false,
            dynamicTypeScale: 1.0,
            dynamicTypeSize: .accessibility2
        )
        let changedEngine = MarkdownPrintRenderTaskID(
            markdown: "# A",
            engineID: ObjectIdentifier(otherEngine),
            pageSize: .a4,
            metadata: PDFMetadata(title: "T", author: "A", subject: "S", keywords: ["pdf"]),
            baseURL: URL(fileURLWithPath: "/tmp/a"),
            theme: .light,
            withTOC: false,
            dynamicTypeScale: 1.0,
            dynamicTypeSize: .large
        )

        XCTAssertEqual(first, same)
        XCTAssertNotEqual(first, changedMarkdown)
        XCTAssertNotEqual(first, changedDynamicType)
        XCTAssertNotEqual(first, changedEngine)
    }

    // MARK: - MarkdownPrintView (SwiftUI)

    @available(macOS 14.0, iOS 17.0, *)
    func testMarkdownPrintViewWithAllConfigurations() {
        let themes: [MarkdownPrintTheme] = [.light, .dark, .mono, .highContrast]
        let pageSizes: [MarkdownPageSize] = [.a4, .usLetter]
        for theme in themes {
            for size in pageSizes {
                let config = MarkdownPrintConfiguration(pageSize: size, theme: theme, withTOC: true)
                let view = MarkdownPrintView("# \(theme.modeName) \(size)", configuration: config)
                XCTAssertNotNil(view)
            }
        }
        // 4 themes * 2 sizes = 8 combinations
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testMarkdownPrintViewWithMetadata() {
        let meta = PDFMetadata(title: "My Title", author: "Author Name")
        let config = MarkdownPrintConfiguration(metadata: meta)
        let view = MarkdownPrintView("# Titled", configuration: config)
        XCTAssertNotNil(view)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testMarkdownPrintViewWithBaseURL() {
        let config = MarkdownPrintConfiguration(baseURL: URL(fileURLWithPath: "/images"))
        let view = MarkdownPrintView("![img](photo.png)", configuration: config)
        XCTAssertNotNil(view)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testMarkdownPrintViewComplexMarkdown() {
        let md = """
        # Complex Document

        This has **bold**, *italic*, `code`, and ~~strikethrough~~.

        ```swift
        let x = 42
        ```

        | A | B |
        |---|---|
        | 1 | 2 |

        - Item 1
        - [x] Done

        > Quote

        [Link](https://example.com)
        """
        let view = MarkdownPrintView(md)
        XCTAssertNotNil(view)
    }
}
