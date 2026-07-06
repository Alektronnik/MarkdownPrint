# ``MarkdownPrint``

Render professional PDF documents from Markdown with native Apple typography.

@Metadata {
    @TechnologyRoot
}

## Overview

MarkdownPrint converts Markdown documents into PDF files using native Apple frameworks. It uses San Francisco and Menlo fonts via CoreText, without requiring AppKit, UIKit, or WebKit.

### Key Features

- **Apple-native typography**: San Francisco (SF Pro) with automatic optical sizing
- **No dependencies**: Only macOS SDK required (CoreGraphics, CoreText, PDFKit)
- **3-layer architecture**: C++17 core + Swift bridge + CoreGraphics renderer
- **Full GFM support**: Tables, task lists, strikethrough, reference links
- **PDF features**: Outline, clickable links, metadata, page numbers
- **Watermarks**: Diagonal text or image stamps on every page
- **Headers & Footers**: `{page}`, `{title}`, `{section}` placeholders
- **Code line numbers** and **text justification**
- **Custom themes**: JSON files or `ThemeOverrides` API
- **Native math**: C++ LaTeX math engine (no external dependencies)
- **Liang-Knuth hyphenation**: English + Spanish patterns
- **Cross-references** and page-bottom **footnotes**
- **Themes**: Light, Dark, Mono, High Contrast
- **Accessibility**: Dynamic Type scaling, high contrast theme, VoiceOver labels in SwiftUI previews, LocalizedError messages
- **Performance**: Font caching, Progress reporting, cancellation, 569 tests

### Quick Start

```swift
import MarkdownPrint

let engine = MarkdownPrintEngine()
let pdfData = try await engine.renderPDF(fromMarkdown: "# Hello\n\nWorld.")
try pdfData.write(to: URL(fileURLWithPath: "output.pdf"))
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Architecture>
- <doc:SwiftUIIntegration>

### Reference

- ``MarkdownPrintEngine``
- ``MarkdownPrintConfiguration``
- ``MarkdownPrintView``
- ``PDFRenderResult``
- ``PDFMetadata``
- ``MarkdownPrintTheme``
- ``RenderOptions``
- ``Watermark``
- ``PageHeaderFooter``
- ``ThemeOverrides``
- ``CLIParser``
