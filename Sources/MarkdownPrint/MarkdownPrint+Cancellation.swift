import Foundation
import os.log

// MARK: - Logger

extension Logger {
    /// Logger compartido para MarkdownPrint.
    static let markdownPrint = Logger(
        subsystem: "com.markdownprint",
        category: "engine"
    )
}

// MARK: - Atomic cancellation flag

/// Flag thread-safe para propagar cancelacion desde el TaskContext async
/// al hilo GCD donde corre el renderizado de PDF.
private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _isCancelled = false

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isCancelled
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        _isCancelled = true
    }
}

// MARK: - Cancellation-Aware Rendering

extension MarkdownPrintEngine {

    /// Renderiza PDF con soporte de cancelacion cooperativa.
    /// Comprueba `Task.isCancelled` entre paginas y lanza `CancellationError`.
    @available(macOS 13.0, iOS 16.0, *)
    public func renderPDFCancellable(
        fromMarkdown markdown: String,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0, fontFamily: FontFamily = .apple,
        progress: Progress? = nil,
        showLineNumbers: Bool = false,
        justifyText: Bool = false,
        watermark: Watermark? = nil,
        headerFooter: PageHeaderFooter? = nil
    ) async throws -> Data {
        let result = try await renderPDFWithDiagnosticsCancellable(
            fromMarkdown: markdown,
            pageSize: pageSize,
            metadata: metadata,
            baseURL: baseURL,
            theme: theme,
            withTOC: withTOC,
            dynamicTypeScale: dynamicTypeScale, fontFamily: fontFamily,
            progress: progress,
            showLineNumbers: showLineNumbers,
            justifyText: justifyText,
            watermark: watermark,
            headerFooter: headerFooter
        )
        return result.pdfData
    }

    @available(macOS 13.0, iOS 16.0, *)
    public func renderPDFWithDiagnosticsCancellable(
        fromMarkdown markdown: String,
        pageSize: MarkdownPageSize = .usLetter,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0, fontFamily: FontFamily = .apple,
        progress: Progress? = nil,
        showLineNumbers: Bool = false,
        justifyText: Bool = false,
        watermark: Watermark? = nil,
        headerFooter: PageHeaderFooter? = nil
    ) async throws -> PDFRenderResult {
        let log = Logger.markdownPrint
        log.info("Starting PDF render: \(markdown.count) chars, pageSize=\(String(describing: pageSize))")

        // Cancelacion temprana
        try Task.checkCancellation()

        setJustifyText(justifyText)
        let documentLayout = layout(markdown, pageSize: pageSize)
        let hasHeadings = documentLayout.pages.contains { page in
            page.elements.contains { $0.headingLevel > 0 && $0.kind == .word && !$0.text.isEmpty }
        }
        let tocPage = (withTOC && hasHeadings) ? 1 : 0
        let totalUnits = Int64(documentLayout.pages.count) + Int64(tocPage)
        progress?.totalUnitCount = totalUnits

        let start = CFAbsoluteTimeGetCurrent()

        // Flag atomico que se activa cuando la Task se cancela.
        let flag = CancellationFlag()

        let pdfData = try await withTaskCancellationHandler {
            // El render va en GCD para no bloquear el cooperative thread pool.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                DispatchQueue.global().async {
                    do {
                        let data = try PDFRenderer.renderCancellable(
                            documentLayout,
                            metadata: metadata,
                            baseURL: baseURL,
                            theme: theme,
                            withTOC: withTOC,
                            scaleFactor: dynamicTypeScale,
                            fontFamily: fontFamily,
                            progress: progress,
                            isCancelled: {
                                // Flag propagado via withTaskCancellationHandler.
                                flag.isCancelled
                            },
                            showLineNumbers: showLineNumbers,
                            justifyText: justifyText,
                            watermark: watermark,
                            headerFooter: headerFooter
                        )
                        continuation.resume(returning: data)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            flag.cancel()
        }

        let duration = CFAbsoluteTimeGetCurrent() - start
        log.info("PDF rendered: \(pdfData.count) bytes, \(documentLayout.pages.count) pages, \(String(format: "%.0f", duration * 1000))ms")

        var linkCount = 0; var imageCount = 0; var headingCount = 0
        for page in documentLayout.pages {
            for element in page.elements {
                if element.style == .link && !element.url.isEmpty { linkCount += 1 }
                if element.kind == .image { imageCount += 1 }
                if element.headingLevel > 0 && element.kind == .word && !element.text.isEmpty { headingCount += 1 }
            }
        }

        let result = PDFRenderResult(
            pdfData: pdfData,
            pageCount: renderedPDFPageCount(pdfData, fallback: documentLayout.pages.count),
            linkCount: linkCount,
            imageCount: imageCount,
            headingCount: headingCount,
            duration: duration
        )
        log.debug("Diagnostics: \(result.diagnostics)")
        return result
    }
}
