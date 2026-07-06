import Foundation
import CoreTransferable

// MARK: - Transferable support

@available(macOS 13.0, iOS 16.0, *)
extension PDFRenderResult: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { result in
            result.pdfData
        }
    }
}

@available(macOS 13.0, iOS 16.0, *)
extension MarkdownPrintEngine {
    /// Shared singleton for convenience in SwiftUI apps.
    public static let shared = MarkdownPrintEngine()
}
