# SwiftUI Integration

MarkdownPrint provides native SwiftUI integration for iOS, macOS, and visionOS.

## MarkdownPrintView

A ready-to-use view that renders Markdown to PDF:

```swift
import SwiftUI
import MarkdownPrint

struct ContentView: View {
    let markdown = """
    # Annual Report
    
    ## Revenue
    
    | Quarter | Revenue |
    |---------|---------|
    | Q1      | $1.2M   |
    | Q2      | $1.5M   |
    """
    
    var body: some View {
        NavigationStack {
            MarkdownPrintView(markdown)
                .navigationTitle("Preview")
        }
    }
}
```

## Configuration

Customize rendering with `MarkdownPrintConfiguration`:

```swift
let config = MarkdownPrintConfiguration(
    pageSize: .usLetter,
    theme: .dark,
    withTOC: true,
    dynamicTypeScale: 1.2,
    accessibilityLabel: "Annual report PDF preview"
)

MarkdownPrintView(markdown, configuration: config)
```

`MarkdownPrintView` reads SwiftUI Dynamic Type from the environment and multiplies it with `dynamicTypeScale`, so accessibility text sizes produce larger PDF text. The loading state, error state, and rendered PDF preview expose VoiceOver labels.

## Sheet Presentation

Present a PDF preview in a modal sheet:

```swift
struct DocumentList: View {
    @State private var showPDF = false
    
    var body: some View {
        List {
            Button("View Report") { showPDF = true }
        }
        .markdownPDFPreview(
            isPresented: $showPDF,
            markdown: markdown
        )
    }
}
```

## Sharing

Use `ShareLink` with `PDFRenderResult`:

```swift
let result = try await engine.renderPDFWithDiagnostics(
    fromMarkdown: markdown
)

ShareLink(item: result, preview: SharePreview("Report"))
```

## Progress

Track rendering progress with `ProgressView`:

```swift
struct AsyncRenderer: View {
    @State private var progress = Progress()
    
    var body: some View {
        VStack {
            ProgressView(progress)
            Button("Render") {
                Task {
                    try await engine.renderPDF(
                        fromMarkdown: markdown,
                        progress: progress
                    )
                }
            }
        }
    }
}
```
