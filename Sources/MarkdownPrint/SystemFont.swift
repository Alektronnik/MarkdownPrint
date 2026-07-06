import CoreText
import Foundation
import MarkdownPrintCore

/// Font family preset.
public enum FontFamily: String, Sendable, CaseIterable {
    case apple   // San Francisco + Menlo
    case web     // Georgia headings + Helvetica body + Courier code
}

// System fonts via CoreText — no AppKit/UIKit needed.
enum SystemFont {

    // MARK: - Cache

    private static let cacheLock = NSLock()
    private static var fontCache: [String: CTFont] = [:]

    private static func cachedFont(key: String, factory: () -> CTFont?) -> CTFont {
        cacheLock.lock()
        if let cached = fontCache[key] { cacheLock.unlock(); return cached }
        cacheLock.unlock()
        let font = factory() ?? CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        cacheLock.lock()
        fontCache[key] = font
        cacheLock.unlock()
        return font
    }

    // MARK: - Apple fonts (San Francisco)

    private static func sfRegular(_ size: CGFloat) -> CTFont {
        cachedFont(key: "sfR\(size)") {
            CTFontCreateUIFontForLanguage(.system, size, nil)
        }
    }

    private static func sfBold(_ size: CGFloat) -> CTFont {
        cachedFont(key: "sfB\(size)") {
            CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil)
                ?? sfRegular(size)
        }
    }

    private static func sfItalic(_ size: CGFloat) -> CTFont {
        cachedFont(key: "sfI\(size)") {
            let base = sfRegular(size)
            return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .traitItalic, .traitItalic) ?? base
        }
    }

    private static func sfSemibold(_ size: CGFloat) -> CTFont {
        cachedFont(key: "sfS\(size)") {
            let traits: [CFString: Any] = [kCTFontWeightTrait: 0.3]
            let attrs: [CFString: Any] = [kCTFontTraitsAttribute: traits, kCTFontFamilyNameAttribute: "SF Pro"]
            return CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes(attrs as CFDictionary), size, nil)
        }
    }

    private static func sfMono(_ size: CGFloat) -> CTFont {
        cachedFont(key: "sfM\(size)") {
            CTFontCreateWithName("Menlo" as CFString, size, nil)
        }
    }

    // MARK: - Web fonts (Georgia, Helvetica, Courier)

    private static func webHeading(_ size: CGFloat) -> CTFont {
        cachedFont(key: "wH\(size)") {
            CTFontCreateWithName("Georgia-Bold" as CFString, size, nil)
        }
    }

    private static func webBody(_ size: CGFloat) -> CTFont {
        cachedFont(key: "wB\(size)") {
            CTFontCreateWithName("Helvetica" as CFString, size, nil)
        }
    }

    private static func webBold(_ size: CGFloat) -> CTFont {
        cachedFont(key: "wBo\(size)") {
            CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
        }
    }

    private static func webItalic(_ size: CGFloat) -> CTFont {
        cachedFont(key: "wI\(size)") {
            let base = webBody(size)
            return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .traitItalic, .traitItalic) ?? base
        }
    }

    private static func webSemibold(_ size: CGFloat) -> CTFont {
        cachedFont(key: "wS\(size)") {
            CTFontCreateWithName("Georgia-Bold" as CFString, size, nil)
        }
    }

    private static func webMono(_ size: CGFloat) -> CTFont {
        cachedFont(key: "wM\(size)") {
            CTFontCreateWithName("Courier" as CFString, size, nil)
        }
    }

    // MARK: - Selection

    static func font(
        forStyle style: MarkdownInlineKind,
        headingLevel: Int,
        size: CGFloat,
        family: FontFamily = .apple
    ) -> CTFont {
        switch family {
        case .apple:
            switch style {
            case .code:                         return sfMono(size)
            case .bold:                         return sfBold(size)
            case .italic:                       return sfItalic(size)
            case .plainText:
                switch headingLevel {
                case 1:                         return sfBold(size)
                case 2, 3, 4, 5, 6:             return sfSemibold(size)
                default:                        return sfRegular(size)
                }
            default:                            return sfRegular(size)
            }
        case .web:
            switch style {
            case .code:                         return webMono(size)
            case .bold:                         return webBold(size)
            case .italic:                       return webItalic(size)
            case .plainText:
                switch headingLevel {
                case 1:                         return webHeading(size)
                case 2, 3, 4, 5, 6:             return webSemibold(size)
                default:                        return webBody(size)
                }
            default:                            return webBody(size)
            }
        }
    }

    // MARK: - Convenience (default family)

    static func regular(size: CGFloat) -> CTFont { font(forStyle: .plainText, headingLevel: 0, size: size) }
    static func bold(size: CGFloat) -> CTFont { font(forStyle: .bold, headingLevel: 0, size: size) }
    static func italic(size: CGFloat) -> CTFont { font(forStyle: .italic, headingLevel: 0, size: size) }
    static func monospace(size: CGFloat) -> CTFont { font(forStyle: .code, headingLevel: 0, size: size) }
}
