# Architecture

MarkdownPrint uses a 3-layer architecture designed for portability and performance.

## Layer 1: C++ Core (`CMarkdownPrintCore`)

The parsing and layout engine is written in portable C++17. It has zero Apple dependencies and compiles on Linux, macOS, and CI.

| Component | Responsibility |
|---|---|
| Lexer | Tokenizes Markdown line-by-line |
| AST Builder | Groups tokens into blocks, nests lists |
| Inline Parser | Recognizes emphasis, links, images, HTML, math |
| Layout Engine | Word wrapping, pagination, table layout |
| Page Geometry | Margins and content area calculation |
| Font Metrics | Approximate character widths for layout |
| Math Parser | LaTeX tokenizer + recursive descent parser (160+ symbols) |
| Math Layout Engine | TeX-style box-and-glue layout for math AST |
| Hyphenator | Liang-Knuth algorithm with EN+ES patterns |

## Layer 2: Swift Bridge (`MarkdownPrintCore`)

Uses Swift 5.9+ C++ interoperability to call the C++ engine directly. No Objective-C++ bridge is needed. This layer has no Apple dependencies and works on Linux.

## Layer 3: Apple Rendering (`MarkdownPrint`)

The rendering layer uses CoreText and CoreGraphics to draw PDF pages. It handles:
- Font resolution (San Francisco, Menlo)
- Syntax highlighting
- PDF outline and metadata
- Theme system
- Image loading

## Key Design Decisions

- **No WebKit rendering**: Renders directly to CoreGraphics for pixel-perfect typography
- **Headless-friendly renderer**: PDF generation works in CLI, servers, and background tasks; the SwiftUI/PDFKit preview bridge is optional
- **Cross-platform core**: The C++ core can be reused for other renderers (Linux, Windows)
- **Native fonts**: Uses CTFontCreateUIFontForLanguage for San Francisco with automatic optical sizing
