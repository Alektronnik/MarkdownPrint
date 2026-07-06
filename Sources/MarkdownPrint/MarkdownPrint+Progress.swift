import Foundation
import MarkdownPrintCore

// MARK: - Progress Reporting

extension MarkdownPrintEngine {

    /// Renderiza PDF con soporte de progreso.
    /// - Parameter progress: Objeto Progress que recibe actualizaciones de fraccion completada.
    public func renderPDF(
        fromMarkdown markdown: String,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0, fontFamily: FontFamily = .apple,
        progress: Progress? = nil
    ) throws -> Data {
        let options = RenderOptions(
            pageSize: pageSize,
            metadata: metadata,
            baseURL: baseURL,
            theme: theme,
            withTOC: withTOC,
            dynamicTypeScale: dynamicTypeScale,
            fontFamily: fontFamily
        )
        return try render(markdown, options: options, progress: progress).pdfData
    }

    public func renderPDFWithDiagnostics(
        fromMarkdown markdown: String,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0, fontFamily: FontFamily = .apple,
        progress: Progress? = nil
    ) throws -> PDFRenderResult {
        let options = RenderOptions(
            pageSize: pageSize,
            metadata: metadata,
            baseURL: baseURL,
            theme: theme,
            withTOC: withTOC,
            dynamicTypeScale: dynamicTypeScale,
            fontFamily: fontFamily
        )
        return try render(markdown, options: options, progress: progress)
    }
}

// MARK: - Async with Progress

@available(macOS 13.0, iOS 16.0, *)
extension MarkdownPrintEngine {
    public func renderPDF(
        fromMarkdown markdown: String,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0, fontFamily: FontFamily = .apple,
        progress: Progress? = nil
    ) async throws -> Data {
        try await Task.detached {
            try self.renderPDF(
                fromMarkdown: markdown,
                pageSize: pageSize,
                metadata: metadata,
                baseURL: baseURL,
                theme: theme,
                withTOC: withTOC,
                dynamicTypeScale: dynamicTypeScale, fontFamily: fontFamily,
                progress: progress
            )
        }.value
    }

    public func renderPDFWithDiagnostics(
        fromMarkdown markdown: String,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0, fontFamily: FontFamily = .apple,
        progress: Progress? = nil
    ) async throws -> PDFRenderResult {
        try await Task.detached {
            try self.renderPDFWithDiagnostics(
                fromMarkdown: markdown,
                pageSize: pageSize,
                metadata: metadata,
                baseURL: baseURL,
                theme: theme,
                withTOC: withTOC,
                dynamicTypeScale: dynamicTypeScale, fontFamily: fontFamily,
                progress: progress
            )
        }.value
    }
}
