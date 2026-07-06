# Changelog

All notable changes to MarkdownPrint.

## [1.0.0] -- 2026-07-06

### Added
- Unified API: `render(_:options:)` with `RenderOptions` struct
- Native LaTeX math rendering via C++ math engine (no external dependencies)
- Watermark support: diagonal text and image stamps
- Page headers and footers with `{page}`, `{title}`, `{section}` placeholders
- Code line numbers in code blocks
- Text justification (align both margins)
- Cross-references with label resolution
- Page-bottom footnotes with separator
- Custom themes via `MarkdownPrintTheme.custom(name:overrides:)` and `ThemeOverrides`
- JSON theme loading: `MarkdownPrintTheme.from(jsonFile:)` / `from(jsonData:)`
- Liang-Knuth hyphenation algorithm (English + Spanish patterns)
- `CLIParser` with full argument parsing and `run()` for testability
- CLI now supports 15 flags: `--size`, `--theme`, `--theme-file`, `--high-contrast`,
  `--toc`, `--title`, `--author`, `--font`, `--justify`, `--line-numbers`,
  `--watermark`, `--watermark-image`, `--header`, `--footer`, `--scale`
- `Watermark` struct with `.confidential()`, `.draft()`, `.image(at:)` factories
- `PageHeaderFooter` struct with `.sectionAndPage()`, `.titleAndPage()` factories
- `PDFRenderResult.diagnostics` formatted string
- Cross-reference resolution in inline markdown
- Optical kerning on H1-H3 headings
- Standard ligatures (fi, fl, ff) on all text
- Tabular numbers in table cells via `kCTFontFeatureSettingsAttribute`
- Automatic small caps for acronyms (`HTML`, `API`, `CSS`, etc.) in inline code
- Native LaTeX math rendering via built-in C++ math engine (no external dependencies)
- Page labels: roman numerals (i, ii, iii) for TOC, arabic for content
- Alt text captions on images
- PDF metadata now includes optional `subject` and `keywords`
- SwiftUI preview respects Dynamic Type and exposes VoiceOver labels for loading, errors, and PDF preview
- `maxMarkdownSize` input validation (DoS protection, default 10MB)
- `FontFamily` enum (`.apple` and `.web` presets)
- Snapshot testing (6 tests) with `swift-snapshot-testing`
- Benchmark tests (4 tests) including concurrent rendering
- CI pipeline (GitHub Actions): macOS build+test, iOS build, CLI smoke test
- Privacy manifest (`PrivacyInfo.xcprivacy`)
- `.gitignore` with standard Swift rules
- `Examples/Demo.swift` interactive demo script

### Changed
- 569 tests (up from 359), 0 failures
- Test coverage improved from ~85% to ~90%
- CLI smoke tests replaced with fast direct CLIParser tests (-65% test time)
- Large document benchmark reduced from 60 to 15 sections
- `main.swift` simplified to 13-line thin caller delegating to `CLIParser`
- Unified API: `render(_:options:)` replaces scattered `renderPDF` overloads
- Legacy `renderPDF` methods deprecated with `@available(*, deprecated)`
- `MANUAL.md` rewritten for new API with all features documented
- DocC `GettingStarted.md` updated for new API
- SystemFont refactored with unified `fontCache`
- Zero compiler warnings (Xcode 15+ SDK)

### Deprecated
- `renderPDF(fromMarkdown:...)` -- use `render(_:options:)`
- `renderPDFWithDiagnostics(fromMarkdown:...)` -- use `render(_:options:)`
- `renderPDFCancellable(fromMarkdown:...)` -- use `render()` with Task cancellation
- `renderPDF(fromMarkdownData:...)` -- use `render()` with Data-to-String conversion

### Known Limitations
- No PDF/UA tagged structure (`CGPDFContext` does not expose structure API)
- No `/Lang` in PDF catalog (`kCGPDFContextLanguage` not available in macOS SDK)
- Remote image URLs not downloaded automatically
- Block HTML (`<div>`, `<table>`, `<pre>`) not parsed
