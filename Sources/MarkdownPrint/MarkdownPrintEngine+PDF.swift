import Foundation
import MarkdownPrintCore
import PDFKit

// MARK: - PDFRenderResult

/// Resultado de una operacion de renderizado PDF con metricas de diagnostico.
///
/// Contiene el PDF generado junto con contadores de elementos detectados
/// y el tiempo de renderizado.
public struct PDFRenderResult: Sendable {
    public let pdfData: Data
    public let pageCount: Int
    public let linkCount: Int
    public let imageCount: Int
    public let headingCount: Int
    public let duration: TimeInterval

    public init(pdfData: Data, pageCount: Int, linkCount: Int, imageCount: Int, headingCount: Int, duration: TimeInterval) {
        self.pdfData = pdfData
        self.pageCount = pageCount
        self.linkCount = linkCount
        self.imageCount = imageCount
        self.headingCount = headingCount
        self.duration = duration
    }

    public var diagnostics: String {
        """
        Paginas:    \(pageCount)
        Enlaces:    \(linkCount)
        Imagenes:   \(imageCount)
        Headings:   \(headingCount)
        Tamano:     \(ByteCountFormatter.string(fromByteCount: Int64(pdfData.count), countStyle: .file))
        Duracion:   \(String(format: "%.0f ms", duration * 1000))
        """
    }
}

func renderedPDFPageCount(_ pdfData: Data, fallback: Int) -> Int {
    PDFDocument(data: pdfData)?.pageCount ?? fallback
}

// MARK: - Engine extension

extension MarkdownPrintEngine {

    // MARK: - Unified API

    /// Renders Markdown to PDF with a single options object.
    ///
    /// This is the recommended entry point. All configuration lives in
    /// ``RenderOptions``, which has sensible defaults.
    ///
    /// ```swift
    /// let result = try engine.render(markdown, options: .init(
    ///     pageSize: .a4,
    ///     theme: .dark,
    ///     withTOC: true
    /// ))
    /// // result.pdfData, result.pageCount, result.diagnostics...
    /// ```
    public func render(
        _ markdown: String,
        options: RenderOptions = .default
    ) throws -> PDFRenderResult {
        guard markdown.utf8.count <= options.maxMarkdownSize else {
            throw MarkdownPrintError.inputTooLarge(size: markdown.utf8.count, maxAllowed: options.maxMarkdownSize)
        }
        return try render(markdown, options: options, progress: nil)
    }

    /// Async version of ``render(_:options:)``.
    @available(macOS 13.0, iOS 16.0, *)
    public func render(
        _ markdown: String,
        options: RenderOptions = .default
    ) async throws -> PDFRenderResult {
        try await Task.detached {
            try self.render(markdown, options: options)
        }.value
    }

    /// Renders with progress reporting.
    /// The `progress` object is updated with fraction completed as each page
    /// (and optional TOC page) is rendered.
    public func render(
        _ markdown: String,
        options: RenderOptions = .default,
        progress: Progress?
    ) throws -> PDFRenderResult {
        setJustifyText(options.justifyText)
        let documentLayout = layout(markdown, pageSize: options.pageSize)

        let hasHeadings = documentLayout.pages.contains { page in
            page.elements.contains { $0.headingLevel > 0 && $0.kind == .word && !$0.text.isEmpty }
        }
        let tocPage = (options.withTOC && hasHeadings) ? 1 : 0
        let totalUnits = Int64(documentLayout.pages.count) + Int64(tocPage)
        progress?.totalUnitCount = totalUnits
        progress?.becomeCurrent(withPendingUnitCount: totalUnits)
        defer { progress?.resignCurrent() }

        let start = CFAbsoluteTimeGetCurrent()
        let pdfData = try PDFRenderer.render(documentLayout, metadata: options.metadata, baseURL: options.baseURL, theme: options.theme, withTOC: options.withTOC, scaleFactor: options.dynamicTypeScale, fontFamily: options.fontFamily, progress: progress, showLineNumbers: options.showLineNumbers, justifyText: options.justifyText, watermark: options.watermark, headerFooter: options.headerFooter)
        let duration = CFAbsoluteTimeGetCurrent() - start

        var linkCount = 0; var imageCount = 0; var headingCount = 0
        for page in documentLayout.pages {
            for element in page.elements {
                if element.style == .link && !element.url.isEmpty { linkCount += 1 }
                if element.kind == .image { imageCount += 1 }
                if element.headingLevel > 0 && element.kind == .word && !element.text.isEmpty { headingCount += 1 }
            }
        }

        return PDFRenderResult(
            pdfData: pdfData,
            pageCount: renderedPDFPageCount(pdfData, fallback: documentLayout.pages.count),
            linkCount: linkCount,
            imageCount: imageCount,
            headingCount: headingCount,
            duration: duration
        )
    }

    // MARK: - Legacy API

    public func renderPDF(
        fromMarkdown markdown: String,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0,
        fontFamily: FontFamily = .apple
    ) throws -> Data {
        let result = try renderPDFWithDiagnostics(
            fromMarkdown: markdown,
            pageSize: pageSize,
            metadata: metadata,
            baseURL: baseURL,
            theme: theme,
            withTOC: withTOC,
            dynamicTypeScale: dynamicTypeScale,
            fontFamily: fontFamily
        )
        return result.pdfData
    }

    public func renderPDFWithDiagnostics(
        fromMarkdown markdown: String,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0,
        fontFamily: FontFamily = .apple
    ) throws -> PDFRenderResult {
        let start = CFAbsoluteTimeGetCurrent()
        let documentLayout = layout(markdown, pageSize: pageSize)
        let pdfData = try PDFRenderer.render(documentLayout, metadata: metadata, baseURL: baseURL, theme: theme, withTOC: withTOC, scaleFactor: dynamicTypeScale, fontFamily: fontFamily)
        let duration = CFAbsoluteTimeGetCurrent() - start

        var linkCount = 0
        var imageCount = 0
        var headingCount = 0

        for page in documentLayout.pages {
            for element in page.elements {
                if element.style == .link && !element.url.isEmpty { linkCount += 1 }
                if element.kind == .image { imageCount += 1 }
                if element.headingLevel > 0 && element.kind == .word && !element.text.isEmpty { headingCount += 1 }
            }
        }

        return PDFRenderResult(
            pdfData: pdfData,
            pageCount: renderedPDFPageCount(pdfData, fallback: documentLayout.pages.count),
            linkCount: linkCount,
            imageCount: imageCount,
            headingCount: headingCount,
            duration: duration
        )
    }

    // MARK: - Async/await API

    /// Renderiza PDF de forma asincrona (Swift Concurrency).
    @available(macOS 13.0, iOS 16.0, *)
    public func renderPDF(
        fromMarkdown markdown: String,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0, fontFamily: FontFamily = .apple
    ) async throws -> Data {
        try await Task.detached {
            let result = try self.renderPDFWithDiagnostics(
                fromMarkdown: markdown,
                pageSize: pageSize,
                metadata: metadata,
                baseURL: baseURL,
                theme: theme,
                withTOC: withTOC,
                dynamicTypeScale: dynamicTypeScale,
                fontFamily: fontFamily
            )
            return result.pdfData
        }.value
    }

    @available(macOS 13.0, iOS 16.0, *)
    public func renderPDFWithDiagnostics(
        fromMarkdown markdown: String,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0, fontFamily: FontFamily = .apple
    ) async throws -> PDFRenderResult {
        try await Task.detached {
            let start = CFAbsoluteTimeGetCurrent()
            let documentLayout = self.layout(markdown, pageSize: pageSize)
            let pdfData = try PDFRenderer.render(documentLayout, metadata: metadata, baseURL: baseURL, theme: theme, withTOC: withTOC, scaleFactor: dynamicTypeScale, fontFamily: fontFamily)
            let duration = CFAbsoluteTimeGetCurrent() - start
            var linkCount = 0; var imageCount = 0; var headingCount = 0
            for page in documentLayout.pages {
                for element in page.elements {
                    if element.style == .link && !element.url.isEmpty { linkCount += 1 }
                    if element.kind == .image { imageCount += 1 }
                    if element.headingLevel > 0 && element.kind == .word && !element.text.isEmpty { headingCount += 1 }
                }
            }
            return PDFRenderResult(pdfData: pdfData, pageCount: renderedPDFPageCount(pdfData, fallback: documentLayout.pages.count), linkCount: linkCount, imageCount: imageCount, headingCount: headingCount, duration: duration)
        }.value
    }

    // MARK: - Data-based API (streaming)

    public func renderPDF(
        fromMarkdownData data: Data,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0, fontFamily: FontFamily = .apple
    ) throws -> Data {
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw MarkdownPrintError.invalidUTF8
        }
        return try renderPDF(fromMarkdown: markdown, pageSize: pageSize, metadata: metadata, baseURL: baseURL, theme: theme, withTOC: withTOC, dynamicTypeScale: dynamicTypeScale, fontFamily: fontFamily)
    }

    public func renderPDFWithDiagnostics(
        fromMarkdownData data: Data,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0, fontFamily: FontFamily = .apple
    ) throws -> PDFRenderResult {
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw MarkdownPrintError.invalidUTF8
        }
        return try renderPDFWithDiagnostics(fromMarkdown: markdown, pageSize: pageSize, metadata: metadata, baseURL: baseURL, theme: theme, withTOC: withTOC, dynamicTypeScale: dynamicTypeScale, fontFamily: fontFamily)
    }
}
