# MarkdownPrint

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%2013%2B%20%7C%20iOS%2016%2B-blue)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-569%20passed-brightgreen)](.)
[![Coverage](https://img.shields.io/badge/Coverage-94.4%25%20filtered-brightgreen)](.)

**MarkdownPrint converts Markdown into polished, Apple-native PDFs.**

No WebKit, no HTML renderer, no web view. The PDF pipeline is direct CoreText, CoreGraphics, and PDFKit, with an optional SwiftUI preview wrapper.

---

## It looks like this

Open [`Examples/demo.pdf`](Examples/demo.pdf). That file was generated from this library's own user manual -- table of contents, code blocks with syntax highlighting, tables, links, typography, headings, the works.

Or generate one yourself in 30 seconds:

```bash
swift run markdownprint-cli README.md README.pdf --toc
```

---

## One API

```swift
import MarkdownPrint

let engine = MarkdownPrintEngine()
let result = try engine.render(markdown, options: .init(
    theme: .dark,
    withTOC: true
))
try result.pdfData.write(to: URL(fileURLWithPath: "output.pdf"))
```

That's the blessed path. `render()` returns a `PDFRenderResult` with `.pdfData`, `.pageCount`, and `.diagnostics`. Everything else is optional.

## One concept

> MarkdownPrint converts Markdown into polished Apple-native PDFs with tables, code, math, images, themes, TOC, links, cancellation, progress, and SwiftUI support.

## What you get by default

A4, light theme, San Francisco typography, clickable links, page numbers, metadata. No config required. Just markdown in, PDF out.

When you need more: dark mode, high contrast, Dynamic Type scaling, custom themes (JSON or programmatic), watermarks, headers/footers, line numbers, text justification, cross-references, footnotes, hyphenation, native LaTeX math, async rendering with cancellation and progress.

## Installation

```swift
.package(url: "https://github.com/your-org/MarkdownPrint", from: "1.0.0")
```

## Coverage

| Target | Lines |
|---|---|
| `CLIParser` | 99.4% |
| `PDFRenderer` | 90.1% |
| `MarkdownPrintCore` (Swift) | 99.0% |
| Overall (all sources) | **89.0%** |
| Overall (SwiftUI excluded) | **94.4%** |

569 tests, 0 failures. Coverage run completes cleanly; test execution is ~4.3s after build.

`MarkdownPrint+SwiftUI.swift` is excluded from the unit-test threshold -- SwiftUI views are tested via UI/integration tests, not XCTest assertions.

**Known limitation:** PDF/UA tagged structure is not yet implemented. PDFs render as `Tagged: no`. This is documented in the [CHANGELOG](CHANGELOG.md) and planned for a future release. The drawing pipeline (CoreGraphics via CGPDFContext) does not expose tagging APIs; tagged PDF requires post-processing the generated PDF byte stream.

## Documentation

- [User Manual](MANUAL.md) -- full API reference, Markdown support, themes, CLI flags
- [Architecture](MANUAL.md#8-architecture) -- C++17 core, Swift bridge, CoreGraphics renderer
- [DocC](Sources/MarkdownPrint/Documentation.docc/MarkdownPrint.md) -- Getting Started, Architecture, SwiftUI Integration

## CLI

```bash
swift run markdownprint-cli input.md [output.pdf] [--toc] [--theme dark] [--watermark DRAFT] ...
```

15 flags. `--help` shows everything.

## License

MIT.
