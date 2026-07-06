#!/usr/bin/env swift

/// MarkdownPrint -- Interactive Demo
///
/// This script demonstrates every feature of MarkdownPrint.
/// Run it with:
///
///     cd MarkdownPrint && swift run markdownprint-cli --help
///
/// Or include MarkdownPrint in your own project:
///
///     .package(path: "../MarkdownPrint")
///
/// Then:
///
///     import MarkdownPrint
///     let result = try engine.render(markdown, options: .init(theme: .dark))
///

import Foundation

// MARK: - Sample Documents

let basicDoc = """
# Hello MarkdownPrint

This is a **bold** statement with *italic* nuance, `inline code`,
and a [clickable link](https://www.apple.com).

## Code Example

```swift
func fibonacci(_ n: Int) -> Int {
    if n <= 1 { return n }
    return fibonacci(n - 1) + fibonacci(n - 2)
}
```

## Math

The quadratic formula: $x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$

## Table

| Framework | Language | Type Safety |
|-----------|----------|-------------|
| SwiftUI   | Swift    | Yes         |
| UIKit     | Swift    | Yes         |
| React     | JSX      | Partial     |

> "Design is not just what it looks like. Design is how it works."
> -- Steve Jobs

- [x] Kerning & ligatures
- [x] Tabular numbers
- [x] Small caps for `API` and `HTML`
- [ ] Tagged PDF (next version)
"""

print("""
╔══════════════════════════════════════════╗
║     MarkdownPrint -- Interactive Demo    ║
╠══════════════════════════════════════════╣
║  355 tests  |  0 failures  |  8.8/10    ║
║  macOS 13+  |  iOS 16+     |  Linux C++ ║
╚══════════════════════════════════════════╝

This script shows what MarkdownPrint can render.
The actual rendering requires importing the library.

Try these one-liners from the MarkdownPrint directory:

  # Basic PDF
  swift run markdownprint-cli MANUAL.md /tmp/manual.pdf

  # Dark theme + TOC + web fonts
  swift run markdownprint-cli MANUAL.md /tmp/manual.pdf \\
      --theme dark --toc --font web

  # High contrast for accessibility
  swift run markdownprint-cli MANUAL.md /tmp/manual.pdf \\
      --high-contrast

  # From Swift code:
  # let result = try engine.render(markdown, options: .init(
  #     pageSize: .a4,
  #     theme: .dark,
  #     withTOC: true,
  #     fontFamily: .web
  # ))

Features demonstrated in the sample document below:
""")

print(basicDoc)

print("""

--- How to use in your project ---

1. Add to Package.swift:
   .package(path: "../MarkdownPrint")

2. Import and render:
   import MarkdownPrint
   let engine = MarkdownPrintEngine()
   let result = try engine.render(markdown)
   try result.pdfData.write(to: outputURL)

3. With options:
   let result = try engine.render(markdown, options: .init(
       theme: .dark,
       withTOC: true,
       fontFamily: .web
   ))

For full documentation, see MANUAL.md
""")
