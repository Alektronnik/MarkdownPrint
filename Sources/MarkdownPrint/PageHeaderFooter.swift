import CoreGraphics
import Foundation

/// Header/footer configuration for PDF pages.
///
/// Supports placeholders:
/// - `{page}` — current page number
/// - `{total}` — total pages
/// - `{title}` — document title from metadata
/// - `{section}` — current section heading (first H1/H2 on page)
public struct PageHeaderFooter: Sendable {
    /// Header text (drawn at the top of each content page).
    /// Supports placeholders `{page}`, `{title}`, `{section}`.
    /// Default: nil (no header).
    public let header: String?

    /// Footer text (drawn at the bottom).
    /// Default: nil (keeps page number if header is set, otherwise nil).
    public let footer: String?

    /// Font size for header/footer text. Default: 9.
    public let fontSize: CGFloat

    /// Color for header/footer text. Default: muted gray.
    public let color: CGColor?

    public init(
        header: String? = nil,
        footer: String? = nil,
        fontSize: CGFloat = 9,
        color: CGColor? = nil
    ) {
        self.header = header
        self.footer = footer
        self.fontSize = fontSize
        self.color = color
    }

    /// Convenience: "{section} — {page}" header.
    public static func sectionAndPage(fontSize: CGFloat = 9) -> PageHeaderFooter {
        PageHeaderFooter(header: "{section} — {page}", fontSize: fontSize)
    }

    /// Convenience: "{title}" header + "{page}" footer.
    public static func titleAndPage(fontSize: CGFloat = 9) -> PageHeaderFooter {
        PageHeaderFooter(header: "{title}", footer: "{page}", fontSize: fontSize)
    }
}
