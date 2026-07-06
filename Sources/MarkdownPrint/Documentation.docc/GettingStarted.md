# Getting Started with MarkdownPrint

Learn how to render your first PDF from Markdown.

## Basic Usage

```swift
import MarkdownPrint

let engine = MarkdownPrintEngine()
let markdown = """
# Hello World

This is a **bold** statement with `code` and [links](https://example.com).
"""

// Synchronous -- returns PDFRenderResult with pdfData, diagnostics, etc.
let result = try engine.render(markdown)
try result.pdfData.write(to: URL(fileURLWithPath: "output.pdf"))

// Async (recommended for SwiftUI)
let result = try await engine.render(markdown)
```

## Configuration

Customize your PDF with `RenderOptions`:

```swift
let result = try engine.render(markdown, options: .init(
    pageSize: .a4,
    metadata: PDFMetadata(title: "Annual Report", author: "Engineering"),
    theme: .dark,
    withTOC: true,
    fontFamily: .web
))
```

## Table of Contents

Generate a navigable table of contents with clickable outline:

```swift
let result = try engine.render(markdown, options: .init(
    withTOC: true
))
// TOC page appears before content with clickable hierarchy
```

## Watermarks & Decorations

Add diagonal text watermarks, image stamps, headers and footers:

```swift
let result = try engine.render(markdown, options: .init(
    watermark: .confidential(),
    headerFooter: .sectionAndPage()
))
// Header: "Section -- Page N"
// Footer: page number
// Watermark: "CONFIDENTIAL" across every page
```

## Code Line Numbers & Justification

```swift
let result = try engine.render(markdown, options: .init(
    showLineNumbers: true,
    justifyText: true
))
// Code blocks show line numbers
// Body text aligns to both margins
```

## Custom Themes

Load themes from JSON or create with overrides:

```swift
// From JSON file
let theme = try MarkdownPrintTheme.from(jsonFile: "corporate.json")

// With overrides
let theme = MarkdownPrintTheme.custom(name: "brand", overrides: .init(
    text: .hex(0x22, 0x22, 0x44),
    linkText: .hex(0xCC, 0x33, 0x00)
))
```

## Themes & Fonts

Four visual themes and two font families:

```swift
// Dark mode with Georgia/Helvetica/Courier
let result = try engine.render(markdown, options: .init(
    theme: .dark,
    fontFamily: .web
))

// High contrast for accessibility
let result = try engine.render(markdown, options: .init(
    theme: .highContrast,
    dynamicTypeScale: 1.5
))
```

## Progress & Cancellation

Track rendering progress:

```swift
let progress = Progress()
let result = try engine.render(markdown, options: .default, progress: progress)
// progress.fractionCompleted updates as each page renders
```

For cooperative cancellation, use async rendering with `Task`:

```swift
let task = Task {
    try await engine.render(markdown)
}
task.cancel()
```

## SwiftUI Integration

Use the built-in SwiftUI view:

```swift
MarkdownPrintView(markdown)
```

