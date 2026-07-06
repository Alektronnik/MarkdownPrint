import CoreGraphics
import Foundation

/// Watermark configuration for PDF pages.
public struct Watermark: Sendable {
    public enum Kind: Sendable {
        /// Diagonal text watermark (e.g., "CONFIDENTIAL", "DRAFT").
        case text(String)
        /// Image watermark (logo, stamp, etc.).
        case image(URL)
    }

    public let kind: Kind

    /// Opacity: 0.0 (invisible) to 1.0 (fully opaque). Default: 0.08.
    public let opacity: CGFloat

    /// Font size for text watermarks. Default: 72.
    public let fontSize: CGFloat

    /// Rotation angle in degrees. Default: -45 (diagonal).
    public let angle: CGFloat

    /// Color. Default: black.
    public let color: CGColor

    public init(
        kind: Kind,
        opacity: CGFloat = 0.08,
        fontSize: CGFloat = 72,
        angle: CGFloat = -45,
        color: CGColor = .black
    ) {
        self.kind = kind
        self.opacity = opacity
        self.fontSize = fontSize
        self.angle = angle
        self.color = color
    }

    /// Convenience: "CONFIDENTIAL" watermark.
    public static func confidential() -> Watermark {
        Watermark(kind: .text("CONFIDENTIAL"))
    }

    /// Convenience: "DRAFT" watermark.
    public static func draft() -> Watermark {
        Watermark(kind: .text("DRAFT"))
    }

    /// Convenience: image watermark from a local file.
    public static func image(at url: URL, opacity: CGFloat = 0.1) -> Watermark {
        Watermark(kind: .image(url), opacity: opacity)
    }
}
