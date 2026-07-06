import Foundation

// MARK: - Render Options

/// Centralized rendering configuration.
///
/// Replaces the scattered parameter lists of the legacy API.
/// All properties have sensible defaults so the simplest call is just:
///
/// ```swift
/// let pdf = try engine.render(markdown)
/// ```
public struct RenderOptions: Sendable {
    /// Page size (A4, US Letter, or custom dimensions).
    public var pageSize: MarkdownPageSize

    /// PDF metadata (title, author, subject, keywords). Visible in Preview, Acrobat, etc.
    public var metadata: PDFMetadata

    /// Base URL for resolving relative image paths.
    /// Defaults to the current working directory if nil.
    public var baseURL: URL?

    /// Visual theme: light, dark, mono, or high contrast.
    public var theme: MarkdownPrintTheme

    /// Whether to include a navigable table of contents (PDF outline).
    public var withTOC: Bool

    /// Relative scaling factor for all font sizes.
    /// 1.0 = default. Use with Dynamic Type values for accessibility.
    public var dynamicTypeScale: CGFloat

    /// Font family preset: `.apple` (SF Pro + Menlo) or `.web` (Georgia + Helvetica + Courier).
    public var fontFamily: FontFamily

    /// Maximum allowed markdown size in bytes. Prevents DoS via oversized input.
    /// Set to `.max` to disable the limit.
    public var maxMarkdownSize: Int

    /// Whether to show line numbers in code blocks. Default: false.
    public var showLineNumbers: Bool

    /// Whether to justify text (align to both margins). Default: false.
    public var justifyText: Bool

    /// Optional watermark drawn on every page.
    public var watermark: Watermark?

    /// Optional header/footer configuration.
    public var headerFooter: PageHeaderFooter?

    public init(
        pageSize: MarkdownPageSize = .a4,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        dynamicTypeScale: CGFloat = 1.0,
        fontFamily: FontFamily = .apple,
        maxMarkdownSize: Int = 10_000_000,
        showLineNumbers: Bool = false,
        justifyText: Bool = false,
        watermark: Watermark? = nil,
        headerFooter: PageHeaderFooter? = nil
    ) {
        self.pageSize = pageSize
        self.metadata = metadata
        self.baseURL = baseURL
        self.theme = theme
        self.withTOC = withTOC
        self.dynamicTypeScale = dynamicTypeScale
        self.fontFamily = fontFamily
        self.maxMarkdownSize = maxMarkdownSize
        self.showLineNumbers = showLineNumbers
        self.justifyText = justifyText
        self.watermark = watermark
        self.headerFooter = headerFooter
    }

    /// The default options: A4, light theme, no TOC, Apple fonts.
    public static let `default` = RenderOptions()
}
