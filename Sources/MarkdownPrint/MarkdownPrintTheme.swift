import CoreGraphics
import Foundation

/// Tema visual para el PDF renderizado.
///
/// Incluye presets: `.light`, `.dark`, `.mono`.
/// Colores y tipografia Apple nativos.
public struct MarkdownPrintTheme: Equatable, Sendable {
    public let modeName: String

    // Fondos
    public let pageBackground: CGColor
    public let codeBackground: CGColor
    public let inlineCodeBackground: CGColor
    public let tableHeaderBackground: CGColor

    // Texto
    public let text: CGColor
    public let mutedText: CGColor
    public let linkText: CGColor
    public let codeText: CGColor
    public let pageNumberText: CGColor

    // Estructurales
    public let border: CGColor
    public let gridLine: CGColor
    public let blockquoteBar: CGColor
    public let headingUnderline: CGColor

    // Comportamiento
    public let underlineLinks: Bool
    public let syntaxHighlight: Bool
    public let smallCaps: Bool

    public init(
        modeName: String,
        pageBackground: CGColor,
        codeBackground: CGColor,
        inlineCodeBackground: CGColor,
        tableHeaderBackground: CGColor,
        text: CGColor,
        mutedText: CGColor,
        linkText: CGColor,
        codeText: CGColor,
        pageNumberText: CGColor,
        border: CGColor,
        gridLine: CGColor,
        blockquoteBar: CGColor,
        headingUnderline: CGColor,
        underlineLinks: Bool,
        syntaxHighlight: Bool,
        smallCaps: Bool
    ) {
        self.modeName = modeName
        self.pageBackground = pageBackground
        self.codeBackground = codeBackground
        self.inlineCodeBackground = inlineCodeBackground
        self.tableHeaderBackground = tableHeaderBackground
        self.text = text
        self.mutedText = mutedText
        self.linkText = linkText
        self.codeText = codeText
        self.pageNumberText = pageNumberText
        self.border = border
        self.gridLine = gridLine
        self.blockquoteBar = blockquoteBar
        self.headingUnderline = headingUnderline
        self.underlineLinks = underlineLinks
        self.syntaxHighlight = syntaxHighlight
        self.smallCaps = smallCaps
    }

    public static func == (lhs: MarkdownPrintTheme, rhs: MarkdownPrintTheme) -> Bool {
        lhs.modeName == rhs.modeName
    }
}

// MARK: - Presets

public extension MarkdownPrintTheme {

    /// Tema claro. Paleta Apple nativa (grises frios, fondo blanco puro).
    static let light = MarkdownPrintTheme(
        modeName: "light",
        // Fondos
        pageBackground:        .hex(0xFF, 0xFF, 0xFF),
        codeBackground:        .hex(0xF5, 0xF5, 0xF7),
        inlineCodeBackground:  .hex(0xF0, 0xF0, 0xF2),
        tableHeaderBackground: .hex(0xF5, 0xF5, 0xF7),
        // Texto
        text:             .hex(0x1D, 0x1D, 0x1F),
        mutedText:        .hex(0x86, 0x86, 0x8B),
        linkText:         .hex(0x00, 0x66, 0xCC),
        codeText:         .hex(0x1D, 0x1D, 0x1F),
        pageNumberText:   .hex(0x86, 0x86, 0x8B),
        // Estructurales
        border:           .hex(0xD2, 0xD2, 0xD7),
        gridLine:         .hex(0xD2, 0xD2, 0xD7, alpha: 0.6),
        blockquoteBar:    .hex(0x86, 0x86, 0x8B),
        headingUnderline: .hex(0xD2, 0xD2, 0xD7),
        // Comportamiento
        underlineLinks:  true,
        syntaxHighlight: true,
        smallCaps: true
    )

    /// Tema oscuro. Paleta Apple nativa (Dark Mode).
    static let dark = MarkdownPrintTheme(
        modeName: "dark",
        // Fondos
        pageBackground:        .hex(0x1C, 0x1C, 0x1E),
        codeBackground:        .hex(0x2C, 0x2C, 0x2E),
        inlineCodeBackground:  .hex(0x2C, 0x2C, 0x2E),
        tableHeaderBackground: .hex(0x2C, 0x2C, 0x2E),
        // Texto
        text:             .hex(0xF5, 0xF5, 0xF7),
        mutedText:        .hex(0x98, 0x98, 0x9D),
        linkText:         .hex(0x64, 0xD2, 0xFF),
        codeText:         .hex(0xF5, 0xF5, 0xF7),
        pageNumberText:   .hex(0x98, 0x98, 0x9D),
        // Estructurales
        border:           .hex(0x48, 0x48, 0x4A),
        gridLine:         .hex(0x48, 0x48, 0x4A, alpha: 0.6),
        blockquoteBar:    .hex(0x48, 0x48, 0x4A),
        headingUnderline: .hex(0x48, 0x48, 0x4A),
        // Comportamiento
        underlineLinks:  true,
        syntaxHighlight: true,
        smallCaps: true
    )

    /// Tema blanco y negro (alto contraste).
    static let mono = MarkdownPrintTheme(
        modeName: "mono",
        // Fondos
        pageBackground:        .hex(0xFF, 0xFF, 0xFF),
        codeBackground:        .hex(0xF5, 0xF5, 0xF5),
        inlineCodeBackground:  .hex(0xF0, 0xF0, 0xF0),
        tableHeaderBackground: .hex(0xF5, 0xF5, 0xF5),
        // Texto
        text:             .hex(0x00, 0x00, 0x00),
        mutedText:        .gray(0.35),
        linkText:         .hex(0x00, 0x00, 0x00),
        codeText:         .hex(0x00, 0x00, 0x00),
        pageNumberText:   .gray(0.5),
        // Estructurales
        border:           .gray(0.6),
        gridLine:         .gray(0.6, alpha: 0.4),
        blockquoteBar:    .gray(0.3),
        headingUnderline: .gray(0.5),
        // Comportamiento
        underlineLinks:  true,
        syntaxHighlight: false,
        smallCaps: false
    )

    /// Tema de alto contraste (accesibilidad).
    static let highContrast = MarkdownPrintTheme(
        modeName: "highContrast",
        pageBackground:        .hex(0xFF, 0xFF, 0xFF),
        codeBackground:        .hex(0xE8, 0xE8, 0xE8),
        inlineCodeBackground:  .hex(0xDD, 0xDD, 0xDD),
        tableHeaderBackground: .hex(0xE8, 0xE8, 0xE8),
        text:             .hex(0x00, 0x00, 0x00),
        mutedText:        .hex(0x00, 0x00, 0x00),
        linkText:         .hex(0x00, 0x00, 0xEE),
        codeText:         .hex(0x00, 0x00, 0x00),
        pageNumberText:   .hex(0x00, 0x00, 0x00),
        border:           .hex(0x00, 0x00, 0x00),
        gridLine:         .hex(0x00, 0x00, 0x00),
        blockquoteBar:    .hex(0x00, 0x00, 0x00),
        headingUnderline: .hex(0x00, 0x00, 0x00),
        underlineLinks:  true,
        syntaxHighlight: false,
        smallCaps: false
    )
}

// MARK: - Custom Themes

/// Configurable color value for custom themes.
public enum ThemeColor: Equatable, Sendable {
    case hex(red: UInt8, green: UInt8, blue: UInt8, alpha: CGFloat)
    case gray(white: CGFloat, alpha: CGFloat)
    case cgColor(CGColor)

    public static func hex(_ r: UInt8, _ g: UInt8, _ b: UInt8, alpha: CGFloat = 1.0) -> ThemeColor {
        .hex(red: r, green: g, blue: b, alpha: alpha)
    }

    public static func gray(_ w: CGFloat, alpha: CGFloat = 1.0) -> ThemeColor {
        .gray(white: w, alpha: alpha)
    }

    var cgColor: CGColor {
        switch self {
        case .hex(let r, let g, let b, let a):
            return CGColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a)
        case .gray(let w, let a):
            return CGColor(gray: w, alpha: a)
        case .cgColor(let c):
            return c
        }
    }

    public static func == (lhs: ThemeColor, rhs: ThemeColor) -> Bool {
        lhs.cgColor == rhs.cgColor
    }
}

/// Overrideable properties for custom theme creation.
/// All properties are optional -- omitted ones inherit from `.light`.
public struct ThemeOverrides: Sendable {
    public var pageBackground: ThemeColor?
    public var codeBackground: ThemeColor?
    public var inlineCodeBackground: ThemeColor?
    public var tableHeaderBackground: ThemeColor?
    public var text: ThemeColor?
    public var mutedText: ThemeColor?
    public var linkText: ThemeColor?
    public var codeText: ThemeColor?
    public var pageNumberText: ThemeColor?
    public var border: ThemeColor?
    public var gridLine: ThemeColor?
    public var blockquoteBar: ThemeColor?
    public var headingUnderline: ThemeColor?
    public var underlineLinks: Bool?
    public var syntaxHighlight: Bool?
    public var smallCaps: Bool?

    public init(
        pageBackground: ThemeColor? = nil,
        codeBackground: ThemeColor? = nil,
        inlineCodeBackground: ThemeColor? = nil,
        tableHeaderBackground: ThemeColor? = nil,
        text: ThemeColor? = nil,
        mutedText: ThemeColor? = nil,
        linkText: ThemeColor? = nil,
        codeText: ThemeColor? = nil,
        pageNumberText: ThemeColor? = nil,
        border: ThemeColor? = nil,
        gridLine: ThemeColor? = nil,
        blockquoteBar: ThemeColor? = nil,
        headingUnderline: ThemeColor? = nil,
        underlineLinks: Bool? = nil,
        syntaxHighlight: Bool? = nil,
        smallCaps: Bool? = nil
    ) {
        self.pageBackground = pageBackground
        self.codeBackground = codeBackground
        self.inlineCodeBackground = inlineCodeBackground
        self.tableHeaderBackground = tableHeaderBackground
        self.text = text
        self.mutedText = mutedText
        self.linkText = linkText
        self.codeText = codeText
        self.pageNumberText = pageNumberText
        self.border = border
        self.gridLine = gridLine
        self.blockquoteBar = blockquoteBar
        self.headingUnderline = headingUnderline
        self.underlineLinks = underlineLinks
        self.syntaxHighlight = syntaxHighlight
        self.smallCaps = smallCaps
    }
}

public extension MarkdownPrintTheme {

    /// Creates a custom theme by overriding specific properties of the light theme.
    ///
    /// ```swift
    /// let corporate = MarkdownPrintTheme.custom(
    ///     name: "corporate",
    ///     overrides: ThemeOverrides(
    ///         text: .hex(0x22, 0x22, 0x44),
    ///         linkText: .hex(0xCC, 0x33, 0x00),
    ///         codeBackground: .hex(0xF8, 0xF4, 0xEE)
    ///     )
    /// )
    /// ```
    static func custom(name: String, overrides: ThemeOverrides) -> MarkdownPrintTheme {
        let base = MarkdownPrintTheme.light
        return MarkdownPrintTheme(
            modeName: name,
            pageBackground:        overrides.pageBackground?.cgColor        ?? base.pageBackground,
            codeBackground:        overrides.codeBackground?.cgColor        ?? base.codeBackground,
            inlineCodeBackground:  overrides.inlineCodeBackground?.cgColor  ?? base.inlineCodeBackground,
            tableHeaderBackground: overrides.tableHeaderBackground?.cgColor ?? base.tableHeaderBackground,
            text:                  overrides.text?.cgColor                  ?? base.text,
            mutedText:             overrides.mutedText?.cgColor             ?? base.mutedText,
            linkText:              overrides.linkText?.cgColor              ?? base.linkText,
            codeText:              overrides.codeText?.cgColor              ?? base.codeText,
            pageNumberText:        overrides.pageNumberText?.cgColor        ?? base.pageNumberText,
            border:                overrides.border?.cgColor                ?? base.border,
            gridLine:              overrides.gridLine?.cgColor              ?? base.gridLine,
            blockquoteBar:         overrides.blockquoteBar?.cgColor         ?? base.blockquoteBar,
            headingUnderline:      overrides.headingUnderline?.cgColor      ?? base.headingUnderline,
            underlineLinks:        overrides.underlineLinks                 ?? base.underlineLinks,
            syntaxHighlight:       overrides.syntaxHighlight                ?? base.syntaxHighlight,
            smallCaps:             overrides.smallCaps                      ?? base.smallCaps
        )
    }

    /// Creates a custom theme from a base theme, overriding specific properties.
    static func custom(name: String, base: MarkdownPrintTheme, overrides: ThemeOverrides) -> MarkdownPrintTheme {
        return MarkdownPrintTheme(
            modeName: name,
            pageBackground:        overrides.pageBackground?.cgColor        ?? base.pageBackground,
            codeBackground:        overrides.codeBackground?.cgColor        ?? base.codeBackground,
            inlineCodeBackground:  overrides.inlineCodeBackground?.cgColor  ?? base.inlineCodeBackground,
            tableHeaderBackground: overrides.tableHeaderBackground?.cgColor ?? base.tableHeaderBackground,
            text:                  overrides.text?.cgColor                  ?? base.text,
            mutedText:             overrides.mutedText?.cgColor             ?? base.mutedText,
            linkText:              overrides.linkText?.cgColor              ?? base.linkText,
            codeText:              overrides.codeText?.cgColor              ?? base.codeText,
            pageNumberText:        overrides.pageNumberText?.cgColor        ?? base.pageNumberText,
            border:                overrides.border?.cgColor                ?? base.border,
            gridLine:              overrides.gridLine?.cgColor              ?? base.gridLine,
            blockquoteBar:         overrides.blockquoteBar?.cgColor         ?? base.blockquoteBar,
            headingUnderline:      overrides.headingUnderline?.cgColor      ?? base.headingUnderline,
            underlineLinks:        overrides.underlineLinks                 ?? base.underlineLinks,
            syntaxHighlight:       overrides.syntaxHighlight                ?? base.syntaxHighlight,
            smallCaps:             overrides.smallCaps                      ?? base.smallCaps
        )
    }
}

// MARK: - JSON Theme Loading

public extension MarkdownPrintTheme {

    /// Loads a custom theme from a JSON file.
    ///
    /// ```json
    /// {
    ///   "name": "corporate",
    ///   "baseTheme": "light",
    ///   "colors": {
    ///     "text": "#222244",
    ///     "linkText": "#CC3300"
    ///   },
    ///   "underlineLinks": true
    /// }
    /// ```
    static func from(jsonFile path: String) throws -> MarkdownPrintTheme {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try from(jsonData: data)
    }

    /// Loads a custom theme from JSON data.
    static func from(jsonData data: Data) throws -> MarkdownPrintTheme {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ThemeError.invalidJSON
        }
        let name = dict["name"] as? String ?? "custom"
        let colors = dict["colors"] as? [String: String] ?? [:]

        var overrides = ThemeOverrides()
        if let h = colors["pageBackground"]        { overrides.pageBackground = parseHex(h) }
        if let h = colors["codeBackground"]        { overrides.codeBackground = parseHex(h) }
        if let h = colors["inlineCodeBackground"]  { overrides.inlineCodeBackground = parseHex(h) }
        if let h = colors["tableHeaderBackground"] { overrides.tableHeaderBackground = parseHex(h) }
        if let h = colors["text"]                  { overrides.text = parseHex(h) }
        if let h = colors["mutedText"]             { overrides.mutedText = parseHex(h) }
        if let h = colors["linkText"]              { overrides.linkText = parseHex(h) }
        if let h = colors["codeText"]              { overrides.codeText = parseHex(h) }
        if let h = colors["pageNumberText"]        { overrides.pageNumberText = parseHex(h) }
        if let h = colors["border"]                { overrides.border = parseHex(h) }
        if let h = colors["gridLine"]              { overrides.gridLine = parseHex(h) }
        if let h = colors["blockquoteBar"]         { overrides.blockquoteBar = parseHex(h) }
        if let h = colors["headingUnderline"]      { overrides.headingUnderline = parseHex(h) }
        if let v = dict["underlineLinks"]  as? Bool { overrides.underlineLinks = v }
        if let v = dict["syntaxHighlight"] as? Bool { overrides.syntaxHighlight = v }
        if let v = dict["smallCaps"]       as? Bool { overrides.smallCaps = v }

        let baseName = dict["baseTheme"] as? String ?? ""
        let base: MarkdownPrintTheme = switch baseName.lowercased() {
        case "dark": .dark
        case "mono": .mono
        case "highcontrast", "high-contrast": .highContrast
        default: .light
        }

        return .custom(name: name, base: base, overrides: overrides)
    }

    private static func parseHex(_ hex: String) -> ThemeColor {
        var c = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.hasPrefix("#") { c.removeFirst() }
        guard c.count == 6, let v = UInt32(c, radix: 16) else { return .hex(0,0,0) }
        return .hex(UInt8((v>>16)&0xFF), UInt8((v>>8)&0xFF), UInt8(v&0xFF))
    }
}

enum ThemeError: LocalizedError {
    case invalidJSON
    var errorDescription: String? {
        switch self {
        case .invalidJSON: return "Invalid theme JSON format"
        }
    }
}

private extension CGColor {
    static func hex(_ r: UInt8, _ g: UInt8, _ b: UInt8, alpha: CGFloat = 1.0) -> CGColor {
        CGColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: alpha)
    }

    static func gray(_ white: CGFloat, alpha: CGFloat = 1.0) -> CGColor {
        CGColor(gray: white, alpha: alpha)
    }
}
