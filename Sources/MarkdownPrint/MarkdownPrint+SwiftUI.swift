#if canImport(SwiftUI)
import SwiftUI
import MarkdownPrintCore

// MARK: - SwiftUI Integration

@available(macOS 14.0, iOS 17.0, *)
public struct MarkdownPrintView: View {
    let markdown: String
    let configuration: MarkdownPrintConfiguration

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var renderResult: PDFRenderResult?
    @State private var error: Error?
    @State private var isLoading = true

    private var renderTaskID: MarkdownPrintRenderTaskID {
        MarkdownPrintRenderTaskID(
            markdown: markdown,
            engineID: ObjectIdentifier(configuration.engine),
            pageSize: configuration.pageSize,
            metadata: configuration.metadata,
            baseURL: configuration.baseURL,
            theme: configuration.theme,
            withTOC: configuration.withTOC,
            dynamicTypeScale: configuration.dynamicTypeScale,
            dynamicTypeSize: dynamicTypeSize
        )
    }
    
    public init(
        _ markdown: String,
        configuration: MarkdownPrintConfiguration = .default
    ) {
        self.markdown = markdown
        self.configuration = configuration
    }
    
    public var body: some View {
        Group {
            if let result = renderResult {
                PDFKitView(data: result.pdfData)
                    .accessibilityLabel(Text(configuration.accessibilityLabel))
                    .accessibilityHint(Text("Rendered PDF document"))
            } else if let error {
                VStack(spacing: 16) {
                    Image(systemName: "doc.badge.xmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Render Error")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Render Error"))
                .accessibilityValue(Text(error.localizedDescription))
            } else if isLoading {
                ProgressView("Rendering PDF...")
                    .accessibilityLabel(Text("Rendering PDF"))
            }
        }
        .task(id: renderTaskID) {
            await render()
        }
    }
    
    private func render() async {
        isLoading = true
        error = nil
        renderResult = nil
        defer { isLoading = false }
        do {
            let result = try await configuration.engine.render(
                markdown,
                options: RenderOptions(
                    pageSize: configuration.pageSize,
                    metadata: configuration.metadata,
                    baseURL: configuration.baseURL,
                    theme: configuration.theme,
                    withTOC: configuration.withTOC,
                    dynamicTypeScale: configuration.dynamicTypeScale * markdownPrintDynamicTypeScale(for: dynamicTypeSize)
                )
            )
            guard !Task.isCancelled else { return }
            renderResult = result
        } catch {
            guard !Task.isCancelled else { return }
            renderResult = nil
            self.error = error
        }
    }
}

// MARK: - Configuration

public struct MarkdownPrintConfiguration {
    public let engine: MarkdownPrintEngine
    public let pageSize: MarkdownPageSize
    public let metadata: PDFMetadata
    public let baseURL: URL?
    public let theme: MarkdownPrintTheme
    public let withTOC: Bool
    public let dynamicTypeScale: CGFloat
    public let accessibilityLabel: String
    
    public init(
        engine: MarkdownPrintEngine = MarkdownPrintEngine(),
        pageSize: MarkdownPageSize = .a4,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0,
        accessibilityLabel: String = "Markdown PDF preview"
    ) {
        self.engine = engine
        self.pageSize = pageSize
        self.metadata = metadata
        self.baseURL = baseURL
        self.theme = theme
        self.withTOC = withTOC
        self.dynamicTypeScale = dynamicTypeScale
        self.accessibilityLabel = accessibilityLabel
    }
    
    public static let `default` = MarkdownPrintConfiguration()
}

@available(macOS 14.0, iOS 17.0, *)
struct MarkdownPrintRenderTaskID: Equatable {
    let markdown: String
    let engineID: ObjectIdentifier
    let pageSize: MarkdownPageSize
    let metadata: PDFMetadata
    let baseURL: URL?
    let theme: MarkdownPrintTheme
    let withTOC: Bool
    let dynamicTypeScale: CGFloat
    let dynamicTypeSize: DynamicTypeSize
}

@available(macOS 14.0, iOS 17.0, *)
func markdownPrintDynamicTypeScale(for size: DynamicTypeSize) -> CGFloat {
    switch size {
    case .xSmall: return 0.82
    case .small: return 0.90
    case .medium: return 0.96
    case .large: return 1.0
    case .xLarge: return 1.12
    case .xxLarge: return 1.23
    case .xxxLarge: return 1.35
    case .accessibility1: return 1.55
    case .accessibility2: return 1.75
    case .accessibility3: return 2.0
    case .accessibility4: return 2.35
    case .accessibility5: return 2.75
    @unknown default: return 1.0
    }
}

// MARK: - View Modifier

@available(macOS 14.0, iOS 17.0, *)
extension View {
    /// Renders Markdown to PDF and presents it in a sheet.
    public func markdownPDFPreview(
        isPresented: Binding<Bool>,
        markdown: String,
        configuration: MarkdownPrintConfiguration = .default
    ) -> some View {
        sheet(isPresented: isPresented) {
            NavigationStack {
                MarkdownPrintView(markdown, configuration: configuration)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isPresented.wrappedValue = false }
                        }
                    }
            }
        }
    }
}

// MARK: - PDFKit Bridge

#if canImport(PDFKit)
import PDFKit

@available(macOS 14.0, iOS 17.0, *)
struct PDFKitView: View {
    let data: Data
    
    #if os(macOS)
    var body: some View {
        PDFKitRepresentableView(data: data)
    }
    #else
    var body: some View {
        PDFKitRepresentableView(data: data)
            .ignoresSafeArea()
    }
    #endif
}

@available(macOS 14.0, iOS 17.0, *)
struct PDFKitRepresentableView {
    let data: Data
    
    #if os(macOS)
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: data)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = PDFDocument(data: data)
    }
    #else
    func makeUIView(context: Context) -> UIView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: data)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? PDFView)?.document = PDFDocument(data: data)
    }
    #endif
}

#if os(macOS)
@available(macOS 14.0, *)
extension PDFKitRepresentableView: NSViewRepresentable {}
#else
@available(iOS 17.0, *)
extension PDFKitRepresentableView: UIViewRepresentable {}
#endif
#endif // PDFKit

// MARK: - Preview

@available(macOS 14.0, iOS 17.0, *)
struct MarkdownPrintView_Previews: PreviewProvider {
    static var previews: some View {
        MarkdownPrintView("""
        # Hello World
        
        This is a **Markdown** preview with `code`.
        
        - Item 1
        - Item 2
        
        > A beautiful quote
        
        | A | B |
        |---|---|
        | 1 | 2 |
        """)
    }
}

#endif // canImport(SwiftUI)
