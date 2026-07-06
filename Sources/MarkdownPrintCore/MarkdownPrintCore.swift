import CMarkdownPrintCore
import CxxStdlib
import Foundation

/// Errores publicos del motor.
public enum MarkdownPrintError: Error, Equatable, Sendable, LocalizedError {
    case notImplementedYet(String)
    case invalidUTF8
    case inputTooLarge(size: Int, maxAllowed: Int)

    public var errorDescription: String? {
        switch self {
        case .notImplementedYet(let feature):
            return String(localized: "Feature not implemented: \(feature)", comment: "Error when a feature is not yet available")
        case .invalidUTF8:
            return String(localized: "Input data is not valid UTF-8", comment: "Error when input data encoding is invalid")
        case .inputTooLarge(let size, let maxAllowed):
            return String(localized: "Input is too large (\(size) bytes, max \(maxAllowed) bytes)", comment: "Error when input exceeds maximum allowed size")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .notImplementedYet:
            return String(localized: "This feature will be available in a future version.", comment: "Recovery suggestion for unimplemented features")
        case .invalidUTF8:
            return String(localized: "Ensure the input data is encoded as UTF-8.", comment: "Recovery suggestion for invalid UTF-8")
        case .inputTooLarge:
            return String(localized: "Reduce the input size or increase the maximum allowed size via RenderOptions.maxMarkdownSize.", comment: "Recovery suggestion for large input")
        }
    }
}

/// Tipo de bloque reconocido por el lexer. Es la traducción 100%
/// Swift de `mdcore::TokenKind`: ningún tipo C++ llega hasta aquí.
public enum MarkdownTokenKind: Equatable, Sendable {
    case heading(level: Int)
    case unorderedListItem
    case orderedListItem(number: Int)
    case horizontalRule
    case codeBlock(language: String)
    case blankLine
    case tableRow
    case blockquote
    case rawHtmlBlock
    case mathBlock
    case paragraph
    case unknown
}

/// Un token de bloque tal y como lo produce el lexer, ya traducido a
/// un valor Swift puro.
public struct MarkdownToken: Equatable, Sendable {
    public let kind: MarkdownTokenKind
    public let text: String
}

/// Tipo de énfasis de un fragmento de texto inline.
public enum MarkdownInlineKind: Equatable, Sendable {
    case plainText
    case bold
    case italic
    case code
    case strikethrough
    case link
    case image
    case hardBreak
    case inlineMath
}

/// Un fragmento de texto con su tipo de énfasis, dentro de un
/// encabezado, párrafo o ítem de lista.
public struct MarkdownInlineRun: Equatable, Sendable {
    public let kind: MarkdownInlineKind
    public let text: String
    public let url: String   // solo cuando kind == .link o .image
}

/// Un ítem de lista ya resuelto: su número (0 si no está numerado) y
/// su contenido inline.
public struct MarkdownListItem: Equatable, Sendable {
    public let number: Int
    public let checked: Bool
    public let isTask: Bool
    public let indent: Int
    public let items: [MarkdownListItem]
    public let inlines: [MarkdownInlineRun]
}

/// Tipo de bloque ya agrupado por el AST Builder (a diferencia de
/// `MarkdownTokenKind`, aquí una lista completa ya es un solo bloque
/// con varios ítems).
public enum MarkdownBlockKind: Equatable, Sendable {
    case heading(level: Int)
    case paragraph
    case unorderedList
    case orderedList
    case horizontalRule
    case codeBlock(language: String)
    case table(columnCount: Int)
    case rawHtmlBlock(tag: String)
    case mathBlock
    case blockquote
    case unknown
}

/// Un bloque del documento ya agrupado: párrafos multilínea
/// fusionados, ítems de lista agrupados, énfasis inline resuelto.
public struct MarkdownBlock: Equatable, Sendable {
    public let kind: MarkdownBlockKind
    public let inlines: [MarkdownInlineRun]  // heading / paragraph
    public let items: [MarkdownListItem]     // listas
    public let text: String                  // codigo (contenido literal)
    public let tableHeaders: [String]        // tabla: cabeceras de columna
    public let tableCells: [String]          // tabla: celdas en row-major, incluyendo cabecera
    public let tableColumnCount: Int         // tabla: numero de columnas
    public let tableAlign: [Int]             // tabla: 0=left, 1=center, 2=right
    public let htmlTag: String               // rawHtmlBlock: nombre de etiqueta
    public let htmlContent: String           // rawHtmlBlock: contenido HTML literal
}

/// Tamaño de página. Los valores están en puntos (72pt = 1 pulgada),
/// la unidad que usa CoreGraphics para PDF.
public enum MarkdownPageSize: Equatable, Sendable {
    case usLetter
    case a4
    case custom(width: Double, height: Double)

    public var dimensions: (width: Double, height: Double) {
        switch self {
        case .usLetter:
            return (612.0, 792.0)
        case .a4:
            return (595.2756, 841.8898)
        case .custom(let width, let height):
            return (width, height)
        }
    }
}

/// Qué representa un elemento ya posicionado en la página.
public enum MarkdownLayoutElementKind: Equatable, Sendable {
    case word
    case horizontalRule
    case tableGridLine
    case image
    case rawHtml
    case mathBlock
    case footnoteRef
}

/// Un elemento con su posición final en la página. Las coordenadas
/// (x, y) se miden desde la esquina superior izquierda del área de
/// CONTENIDO (dentro de los márgenes), con y creciendo hacia abajo.
public struct MarkdownLayoutElement: Equatable, Sendable {
    public let kind: MarkdownLayoutElementKind
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let fontSize: Double
    public let style: MarkdownInlineKind
    public let text: String
    /// URL del enlace; vacia si style != .link.
    public let url: String
    /// Nivel de encabezado: 0 si no es encabezado, 1-6 para H1-H6.
    /// Permite a la Capa 3 elegir el peso tipografico correcto.
    public let headingLevel: Int
    /// True si este elemento pertenece a un bloque fenced de codigo.
    public let isCodeBlock: Bool
    /// True si este elemento es texto dentro de una celda de tabla.
    public let isTableCell: Bool
    /// True si este elemento pertenece a una cita (>).
    public let isBlockquote: Bool
    /// True si el texto es RTL (arabe, hebreo, etc.).
    public let isRTL: Bool
    /// Etiqueta de la nota al pie (vacia si no es FootnoteRef).
    public let footnoteLabel: String
    public let headingLabel: String
    public let crossRefLabel: String

    /// Returns a copy with the text replaced.
    public func withText(_ newText: String) -> MarkdownLayoutElement {
        MarkdownLayoutElement(
            kind: kind, x: x, y: y, width: width, height: height,
            fontSize: fontSize, style: style, text: newText, url: url,
            headingLevel: headingLevel, isCodeBlock: isCodeBlock,
            isTableCell: isTableCell, isBlockquote: isBlockquote,
            isRTL: isRTL, footnoteLabel: footnoteLabel,
            headingLabel: headingLabel, crossRefLabel: crossRefLabel
        )
    }
}

/// Una página ya maquetada, con sus elementos posicionados.
public struct MarkdownPage: Equatable, Sendable {
    public let pageNumber: Int
    public let elements: [MarkdownLayoutElement]
}

/// Geometría de página usada para calcular un layout: dimensiones y
/// márgenes. Los elementos de cada página están posicionados en
/// relativo al área de contenido que describe esta geometría, no a
/// la página entera — la Capa 3 la necesita para saber dónde
/// arranca esa área dentro de la hoja.
public struct MarkdownPageGeometry: Equatable, Sendable {
    public let pageWidth: Double
    public let pageHeight: Double
    public let marginTop: Double
    public let marginBottom: Double
    public let marginLeft: Double
    public let marginRight: Double
    public let contentWidth: Double
    public let contentHeight: Double
}

/// Resultado completo del layout: el documento ya paginado.
public struct MarkdownLayout: Equatable, Sendable {
    public let pages: [MarkdownPage]
    public let geometry: MarkdownPageGeometry
    public let footnoteDefs: [String: String]
}

/// Punto de entrada público de la librería.
///
/// Esta clase no depende de CoreGraphics ni de ningún framework de
/// Apple: es un envoltorio Swift ergonómico sobre el motor en C++.
/// Se puede compilar y testear en Linux, macOS o en CI sin necesidad
/// de un Mac.
public final class MarkdownPrintEngine {

    // `mdcore.Engine` es la clase C++ importada vía interop nativo.
    // No hay ningún puente Objective-C++ en medio: esta llamada va
    // directa de Swift a C++.
    private let core: mdcore.Engine

    public init() {
        core = mdcore.Engine(std.string("en"))
    }

    /// Prueba de vida: confirma que Swift está llamando directamente
    /// a una clase C++ real.
    public var coreVersion: String {
        String(core.engineVersion())
    }

    /// Enable text justification (align both margins) for this engine.
    /// Must be called before render/layout.
    public func setJustifyText(_ v: Bool) {
        core.setJustifyText(v)
    }

    /// Divide un documento Markdown en tokens de bloque (encabezados,
    /// listas, regla horizontal, bloques de código, párrafos...).
    public func tokenize(_ markdown: String) -> [MarkdownToken] {
        let cppTokens = core.tokenize(std.string(markdown))
        var result: [MarkdownToken] = []
        result.reserveCapacity(Int(cppTokens.size()))
        for cppToken in cppTokens {
            result.append(MarkdownToken(cppToken))
        }
        return result
    }

    /// Tokeniza y agrupa el resultado en bloques: fusiona párrafos
    /// multilínea, agrupa ítems de lista y resuelve el énfasis
    /// inline (negrita, cursiva, código).
    public func parse(_ markdown: String) -> [MarkdownBlock] {
        let cppBlocks = core.parse(std.string(markdown))
        var result: [MarkdownBlock] = []
        result.reserveCapacity(Int(cppBlocks.size()))
        for cppBlock in cppBlocks {
            result.append(MarkdownBlock(cppBlock))
        }
        return result
    }

    /// API de streaming: acepta `Data` (UTF-8) en vez de `String`.
    public func tokenize(data: Data) throws -> [MarkdownToken] {
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw MarkdownPrintError.invalidUTF8
        }
        return tokenize(markdown)
    }

    public func parse(data: Data) throws -> [MarkdownBlock] {
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw MarkdownPrintError.invalidUTF8
        }
        return parse(markdown)
    }

    public func layout(data: Data, pageSize: MarkdownPageSize = .usLetter) throws -> MarkdownLayout {
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw MarkdownPrintError.invalidUTF8
        }
        return layout(markdown, pageSize: pageSize)
    }

    /// Parsea y calcula el layout final: márgenes por proporción
    /// áurea, ajuste de línea y paginación real. Con métricas de
    /// fuente aproximadas por ahora (ver ApproximateFontMetrics.hpp);
    /// la Capa 3 las sustituirá por CoreText sin tocar el algoritmo.
    public func layout(_ markdown: String, pageSize: MarkdownPageSize = .usLetter) -> MarkdownLayout {
        let dimensions = pageSize.dimensions
        let cppLayout = core.layout(std.string(markdown), dimensions.width, dimensions.height)
        var pages: [MarkdownPage] = []
        pages.reserveCapacity(Int(cppLayout.pages.size()))
        for cppPage in cppLayout.pages {
            pages.append(MarkdownPage(cppPage))
        }
        var fnDefs: [String: String] = [:]
        for cppFD in cppLayout.footnoteDefs {
            fnDefs[String(cppFD.label)] = String(cppFD.text)
        }
        return MarkdownLayout(pages: pages, geometry: MarkdownPageGeometry(cppLayout.geometry), footnoteDefs: fnDefs)
    }
}

extension MarkdownToken {
    fileprivate init(_ cppToken: mdcore.Token) {
        let text = String(cppToken.text)
        switch cppToken.kind {
        case .Heading:
            self.init(kind: .heading(level: Int(cppToken.level)), text: text)
        case .UnorderedListItem:
            self.init(kind: .unorderedListItem, text: text)
        case .OrderedListItem:
            self.init(kind: .orderedListItem(number: Int(cppToken.level)), text: text)
        case .HorizontalRule:
            self.init(kind: .horizontalRule, text: text)
        case .CodeBlock:
            self.init(kind: .codeBlock(language: String(cppToken.language)), text: text)
        case .BlankLine:
            self.init(kind: .blankLine, text: text)
        case .TableRow:
            self.init(kind: .tableRow, text: text)
        case .Blockquote:
            self.init(kind: .blockquote, text: text)
        case .RawHtmlBlock:
            self.init(kind: .rawHtmlBlock, text: text)
        case .MathBlock:
            self.init(kind: .mathBlock, text: text)
        case .Paragraph:
            self.init(kind: .paragraph, text: text)
        default:
            self.init(kind: .unknown, text: text)
        }
    }
}

extension MarkdownInlineRun {
    fileprivate init(_ cppRun: mdcore.InlineRun) {
        let text = String(cppRun.text)
        let url = String(cppRun.url)
        switch cppRun.kind {
        case .Bold:
            self.init(kind: .bold, text: text, url: "")
        case .Italic:
            self.init(kind: .italic, text: text, url: "")
        case .Code:
            self.init(kind: .code, text: text, url: "")
        case .Strikethrough:
            self.init(kind: .strikethrough, text: text, url: "")
        case .Link:
            self.init(kind: .link, text: text, url: url)
        case .Image:
            self.init(kind: .image, text: text, url: url)
        case .HardBreak:
            self.init(kind: .hardBreak, text: "", url: "")
        case .InlineMath:
            self.init(kind: .inlineMath, text: text, url: "")
        default:
            self.init(kind: .plainText, text: text, url: "")
        }
    }
}

extension MarkdownListItem {
    fileprivate init(_ cppItem: mdcore.ListItem) {
        var inlines: [MarkdownInlineRun] = []
        inlines.reserveCapacity(Int(cppItem.inlines.size()))
        for cppRun in cppItem.inlines {
            inlines.append(MarkdownInlineRun(cppRun))
        }
        var subItems: [MarkdownListItem] = []
        subItems.reserveCapacity(Int(cppItem.items.size()))
        for cppSub in cppItem.items {
            subItems.append(MarkdownListItem(cppSub))
        }
        self.init(number: Int(cppItem.number), checked: Bool(cppItem.checked), isTask: Bool(cppItem.isTask), indent: Int(cppItem.indent), items: subItems, inlines: inlines)
    }
}

extension MarkdownBlock {
    fileprivate init(_ cppBlock: mdcore.Block) {
        var inlines: [MarkdownInlineRun] = []
        inlines.reserveCapacity(Int(cppBlock.inlines.size()))
        for cppRun in cppBlock.inlines {
            inlines.append(MarkdownInlineRun(cppRun))
        }

        var items: [MarkdownListItem] = []
        items.reserveCapacity(Int(cppBlock.items.size()))
        for cppItem in cppBlock.items {
            items.append(MarkdownListItem(cppItem))
        }

        let text = String(cppBlock.text)

        switch cppBlock.kind {
        case .Heading:
            self.init(kind: .heading(level: Int(cppBlock.level)), inlines: inlines, items: items, text: text, tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        case .Paragraph:
            self.init(kind: .paragraph, inlines: inlines, items: items, text: text, tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        case .UnorderedList:
            self.init(kind: .unorderedList, inlines: inlines, items: items, text: text, tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        case .OrderedList:
            self.init(kind: .orderedList, inlines: inlines, items: items, text: text, tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        case .HorizontalRule:
            self.init(kind: .horizontalRule, inlines: inlines, items: items, text: text, tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        case .RawHtmlBlock:
            self.init(kind: .rawHtmlBlock(tag: String(cppBlock.htmlTag)), inlines: inlines, items: items, text: text, tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: String(cppBlock.htmlTag), htmlContent: String(cppBlock.htmlContent))
        case .MathBlock:
            self.init(kind: .mathBlock, inlines: inlines, items: items, text: text, tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        case .Blockquote:
            self.init(kind: .blockquote, inlines: inlines, items: items, text: text, tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        case .CodeBlock:
            self.init(kind: .codeBlock(language: String(cppBlock.language)), inlines: inlines, items: items, text: text, tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        case .Table:
            var tableHeaders: [String] = []
            tableHeaders.reserveCapacity(Int(cppBlock.tableHeaders.size()))
            for h in cppBlock.tableHeaders {
                tableHeaders.append(String(h))
            }
            var tableCells: [String] = []
            tableCells.reserveCapacity(Int(cppBlock.tableCells.size()))
            for c in cppBlock.tableCells {
                tableCells.append(String(c))
            }
            var align: [Int] = []
            align.reserveCapacity(Int(cppBlock.tableAlign.size()))
            for a in cppBlock.tableAlign { align.append(Int(a)) }
            self.init(kind: .table(columnCount: Int(cppBlock.tableColumnCount)), inlines: inlines, items: items, text: text, tableHeaders: tableHeaders, tableCells: tableCells, tableColumnCount: Int(cppBlock.tableColumnCount), tableAlign: align, htmlTag: "", htmlContent: "")
        default:
            self.init(kind: .unknown, inlines: inlines, items: items, text: text, tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        }
    }
}

extension MarkdownLayoutElement {
    fileprivate init(_ cppElement: mdcore.LayoutElement) {
        let style: MarkdownInlineKind
        switch cppElement.style {
        case .Bold:
            style = .bold
        case .Italic:
            style = .italic
        case .Code:
            style = .code
        case .Strikethrough:
            style = .strikethrough
        case .Link:
            style = .link
        case .Image:
            style = .image
        case .HardBreak:
            style = .hardBreak
        case .InlineMath:
            style = .inlineMath
        default:
            style = .plainText
        }

        let kind: MarkdownLayoutElementKind
        switch cppElement.kind {
        case .HorizontalRule:
            kind = .horizontalRule
        case .TableGridLine:
            kind = .tableGridLine
        case .Image:
            kind = .image
        case .RawHtml:
            kind = .rawHtml
        case .MathBlock:
            kind = .mathBlock
        case .FootnoteRef:
            kind = .footnoteRef
        default:
            kind = .word
        }

        self.init(
            kind: kind,
            x: Double(cppElement.x),
            y: Double(cppElement.y),
            width: Double(cppElement.width),
            height: Double(cppElement.height),
            fontSize: Double(cppElement.fontSize),
            style: style,
            text: String(cppElement.text),
            url: String(cppElement.url),
            headingLevel: Int(cppElement.headingLevel),
            isCodeBlock: Bool(cppElement.isCodeBlock),
            isTableCell: Bool(cppElement.isTableCell),
            isBlockquote: Bool(cppElement.isBlockquote),
            isRTL: Bool(cppElement.isRTL),
            footnoteLabel: String(cppElement.footnoteLabel),
            headingLabel: String(cppElement.headingLabel),
            crossRefLabel: String(cppElement.crossRefLabel)
        )
    }
}

extension MarkdownPageGeometry {
    fileprivate init(_ cppGeometry: mdcore.PageGeometry) {
        self.init(
            pageWidth: Double(cppGeometry.pageWidth),
            pageHeight: Double(cppGeometry.pageHeight),
            marginTop: Double(cppGeometry.marginTop),
            marginBottom: Double(cppGeometry.marginBottom),
            marginLeft: Double(cppGeometry.marginLeft),
            marginRight: Double(cppGeometry.marginRight),
            contentWidth: Double(cppGeometry.contentWidth()),
            contentHeight: Double(cppGeometry.contentHeight())
        )
    }
}

extension MarkdownPage {
    fileprivate init(_ cppPage: mdcore.Page) {
        var elements: [MarkdownLayoutElement] = []
        elements.reserveCapacity(Int(cppPage.elements.size()))
        for cppElement in cppPage.elements {
            elements.append(MarkdownLayoutElement(cppElement))
        }
        self.init(pageNumber: Int(cppPage.pageNumber), elements: elements)
    }
}
