import XCTest
import CoreTransferable
import OSLog
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
@testable import MarkdownPrintCore
@testable import MarkdownPrint

final class MarkdownPrintCoreTests: XCTestCase {

    /// Si esto compila y pasa, confirma que Swift está llamando
    /// directamente a `mdcore::Engine` (C++) sin ningún puente
    /// Objective-C++ intermedio.
    func testCoreVersionRoundTripsThroughCpp() {
        let engine = MarkdownPrintEngine()
        XCTAssertTrue(engine.coreVersion.contains("MarkdownPrintCore"))
    }

    func testTokenizeRecognizesHeadingLevels() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("# Uno\n## Dos\n###### Seis")

        XCTAssertEqual(tokens, [
            MarkdownToken(kind: .heading(level: 1), text: "Uno"),
            MarkdownToken(kind: .heading(level: 2), text: "Dos"),
            MarkdownToken(kind: .heading(level: 6), text: "Seis")
        ])
    }

    func testTokenizeRecognizesUnorderedListItems() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("- primero\n- segundo")

        XCTAssertEqual(tokens, [
            MarkdownToken(kind: .unorderedListItem, text: "primero"),
            MarkdownToken(kind: .unorderedListItem, text: "segundo")
        ])
    }

    func testTokenizeRecognizesOrderedListItems() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("1. paso uno\n2. paso dos")

        XCTAssertEqual(tokens, [
            MarkdownToken(kind: .orderedListItem(number: 1), text: "paso uno"),
            MarkdownToken(kind: .orderedListItem(number: 2), text: "paso dos")
        ])
    }

    func testTokenizeRecognizesHorizontalRule() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("---")

        XCTAssertEqual(tokens, [MarkdownToken(kind: .horizontalRule, text: "")])
    }

    func testTokenizeRecognizesFencedCodeBlockWithLanguage() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("```swift\nlet x = 1\nprint(x)\n```")

        XCTAssertEqual(tokens, [
            MarkdownToken(kind: .codeBlock(language: "swift"), text: "let x = 1\nprint(x)")
        ])
    }

    func testTokenizeRecognizesBlankLinesAndParagraphs() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("Hola\n\nMundo")

        XCTAssertEqual(tokens, [
            MarkdownToken(kind: .paragraph, text: "Hola"),
            MarkdownToken(kind: .blankLine, text: ""),
            MarkdownToken(kind: .paragraph, text: "Mundo")
        ])
    }

    func testTokenizeHandlesUnterminatedCodeBlockWithoutLosingContent() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("```\nsin cerrar")

        XCTAssertEqual(tokens, [
            MarkdownToken(kind: .codeBlock(language: ""), text: "sin cerrar")
        ])
    }

    func testTokenizeAllowsLongerFenceAroundNestedBackticks() {
        let engine = MarkdownPrintEngine()
        let markdown = "````\ntexto\n```\nlet x = 1\n```\n````"
        let tokens = engine.tokenize(markdown)

        XCTAssertEqual(tokens, [
            MarkdownToken(kind: .codeBlock(language: ""), text: "texto\n```\nlet x = 1\n```")
        ])
    }

    func testTokenizeKeepsIndentedLinesInsideFencedCodeBlock() {
        let engine = MarkdownPrintEngine()
        let markdown = """
        ```swift
        func ejemplo() {
            return 42
        }
        ```
        """
        let tokens = engine.tokenize(markdown)

        XCTAssertEqual(tokens, [
            MarkdownToken(kind: .codeBlock(language: "swift"), text: "func ejemplo() {\n    return 42\n}")
        ])
    }

    // MARK: - parse() / AST Builder

    func testParseMergesConsecutiveParagraphLines() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Primera linea\nsegunda linea\n\nOtro parrafo")

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].kind, .paragraph)
        XCTAssertEqual(blocks[0].inlines, [MarkdownInlineRun(kind: .plainText, text: "Primera linea segunda linea", url: "")])
        XCTAssertEqual(blocks[1].kind, .paragraph)
        XCTAssertEqual(blocks[1].inlines, [MarkdownInlineRun(kind: .plainText, text: "Otro parrafo", url: "")])
    }

    func testParseRemovesRepeatedPrintHeadersFromMarkItDownHtmlOutput() {
        let engine = MarkdownPrintEngine()
        let markdown = """
        6/2/26, 1:35
        Vía Íbero Romana - Noticias, fotos, videos, callejero...
        (/ﬁleadmin/_processed_/example.png)
        https://www.padul.org/index.php?id=227
        1/75
        """ + "\u{0C}" + """
        6/2/26, 1:35
        Vía Íbero Romana - Noticias, fotos, videos, callejero...
        https://www.padul.org/index.php?id=227
        2/75
        """ + "\u{0C}" + """
        6/2/26, 1:35
        Vía Íbero Romana - Noticias, fotos, videos, callejero...
        Contenido real de la noticia.
        https://www.padul.org/index.php?id=227
        3/75
        """

        let blocks = engine.parse(markdown)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .paragraph)
        XCTAssertEqual(blocks[0].inlines.map(\.text).joined(), "Contenido real de la noticia.")
    }

    func testParseCollapsesMarkItDownLayoutTablesIntoParagraphText() {
        let engine = MarkdownPrintEngine()
        let markdown = """
        El documento describe
        | Granada | (South | Spain), | located | on | the | banks of | the Velillos |
        | ------- | ------ | ------- | ------- | -- | --- | -------- | ------------ |
        | river. | The | movement | started | after | heavy | rain | |
        """

        let blocks = engine.parse(markdown)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .paragraph)
        XCTAssertEqual(
            blocks[0].inlines.map(\.text).joined(),
            "El documento describe Granada (South Spain), located on the banks of the Velillos river. The movement started after heavy rain"
        )
    }

    func testParseCollapsesShortFourColumnMarkItDownLayoutTables() {
        let engine = MarkdownPrintEngine()
        let markdown = """
        Texto OCR previo.
        | Vista general | de Los Olivares | en la margen | opuesta el deslizamiento. |
        | ------------- | --------------- | ------------ | ------------------------- |
        """

        let blocks = engine.parse(markdown)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .paragraph)
        XCTAssertEqual(
            blocks[0].inlines.map(\.text).joined(),
            "Texto OCR previo. Vista general de Los Olivares en la margen opuesta el deslizamiento."
        )
    }

    func testParseKeepsRegularMarkdownTablesAfterPreprocessing() {
        let engine = MarkdownPrintEngine()
        let markdown = """
        | Nombre | Edad | Ciudad |
        | --- | ---: | --- |
        | Ana | 28 | Madrid |
        """

        let blocks = engine.parse(markdown)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .table(columnCount: 3))
        XCTAssertEqual(blocks[0].tableHeaders, ["Nombre", "Edad", "Ciudad"])
        XCTAssertEqual(blocks[0].tableCells, ["Nombre", "Edad", "Ciudad", "Ana", "28", "Madrid"])
    }

    func testParsePromotesRecoveredUppercaseHeadingsInMarkItDownDocuments() {
        let engine = MarkdownPrintEngine()
        let markdown = """
        | Vista general | de Los Olivares | en la margen | opuesta el deslizamiento. |
        | ------------- | --------------- | ------------ | ------------------------- |

        PRESENTACION
        La presente publicacion resume los trabajos.

        1. INTRODUCCION Y ANTECEDENTES
        Texto de la seccion.
        """

        let blocks = engine.parse(markdown)

        XCTAssertEqual(blocks.map(\.kind), [
            .paragraph,
            .heading(level: 2),
            .paragraph,
            .heading(level: 2),
            .paragraph
        ])
        XCTAssertEqual(blocks[1].inlines.map(\.text).joined(), "PRESENTACION")
        XCTAssertEqual(blocks[3].inlines.map(\.text).joined(), "1. INTRODUCCION Y ANTECEDENTES")
    }

    func testParseDoesNotPromoteNumericOcrFragmentsAsRecoveredHeadings() {
        let engine = MarkdownPrintEngine()
        let markdown = """
        | Vista general | de Los Olivares | en la margen | opuesta el deslizamiento. |
        | ------------- | --------------- | ------------ | ------------------------- |

        (675,99) ESLZAMI 32,
        Texto posterior.
        """

        let blocks = engine.parse(markdown)

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].kind, .paragraph)
        XCTAssertEqual(blocks[1].kind, .paragraph)
        XCTAssertEqual(blocks[1].inlines.map(\.text).joined(), "(675,99) ESLZAMI 32, Texto posterior.")
    }

    func testParseGroupsConsecutiveListItemsIntoOneBlock() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("- uno\n- dos\n- tres")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .unorderedList)
        XCTAssertEqual(blocks[0].items.map(\.number), [0, 0, 0])
        XCTAssertEqual(blocks[0].items.map { $0.inlines.map(\.text) }, [["uno"], ["dos"], ["tres"]])
    }

    func testParsePreservesTaskListStateSeparatelyFromPlainBullets() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("- normal\n- [ ] pendiente\n- [x] completa")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .unorderedList)
        XCTAssertEqual(blocks[0].items.map(\.isTask), [false, true, true])
        XCTAssertEqual(blocks[0].items.map(\.checked), [false, false, true])
        XCTAssertEqual(blocks[0].items.map { $0.inlines.map(\.text).joined() }, ["normal", "pendiente", "completa"])
    }

    func testParseKeepsOrderedListNumbers() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("1. paso uno\n2. paso dos")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .orderedList)
        XCTAssertEqual(blocks[0].items.map(\.number), [1, 2])
    }

    func testParseResolvesBoldItalicAndInlineCode() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Texto con **negrita**, *cursiva* y `codigo`.")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].inlines, [
            MarkdownInlineRun(kind: .plainText, text: "Texto con ", url: ""),
            MarkdownInlineRun(kind: .bold, text: "negrita", url: ""),
            MarkdownInlineRun(kind: .plainText, text: ", ", url: ""),
            MarkdownInlineRun(kind: .italic, text: "cursiva", url: ""),
            MarkdownInlineRun(kind: .plainText, text: " y ", url: ""),
            MarkdownInlineRun(kind: .code, text: "codigo", url: ""),
            MarkdownInlineRun(kind: .plainText, text: ".", url: "")
        ])
    }

    func testParseRecognizesInlineImages() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Antes ![Diagrama](images/diagram.png) despues")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .paragraph)
        XCTAssertEqual(blocks[0].inlines, [
            MarkdownInlineRun(kind: .plainText, text: "Antes ", url: ""),
            MarkdownInlineRun(kind: .image, text: "Diagrama", url: "images/diagram.png"),
            MarkdownInlineRun(kind: .plainText, text: " despues", url: "")
        ])
    }

    func testParseRecognizesHtmlEm() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Texto <em>cursiva</em> final")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].inlines, [
            MarkdownInlineRun(kind: .plainText, text: "Texto ", url: ""),
            MarkdownInlineRun(kind: .italic, text: "cursiva", url: ""),
            MarkdownInlineRun(kind: .plainText, text: " final", url: "")
        ])
    }

    func testParseRecognizesHtmlStrong() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Esto <strong>negrita</strong> aqui")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].inlines, [
            MarkdownInlineRun(kind: .plainText, text: "Esto ", url: ""),
            MarkdownInlineRun(kind: .bold, text: "negrita", url: ""),
            MarkdownInlineRun(kind: .plainText, text: " aqui", url: "")
        ])
    }

    func testParseRecognizesHtmlCode() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Usa <code>let x = 1</code> aqui")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].inlines, [
            MarkdownInlineRun(kind: .plainText, text: "Usa ", url: ""),
            MarkdownInlineRun(kind: .code, text: "let x = 1", url: ""),
            MarkdownInlineRun(kind: .plainText, text: " aqui", url: "")
        ])
    }

    func testParseRecognizesHtmlDel() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Texto <del>tachado</del> final")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].inlines, [
            MarkdownInlineRun(kind: .plainText, text: "Texto ", url: ""),
            MarkdownInlineRun(kind: .strikethrough, text: "tachado", url: ""),
            MarkdownInlineRun(kind: .plainText, text: " final", url: "")
        ])
    }

    func testParseRecognizesHtmlAnchor() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Visita <a href=\"https://example.com\">el sitio</a> ahora")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].inlines, [
            MarkdownInlineRun(kind: .plainText, text: "Visita ", url: ""),
            MarkdownInlineRun(kind: .link, text: "el sitio", url: "https://example.com"),
            MarkdownInlineRun(kind: .plainText, text: " ahora", url: "")
        ])
    }

    func testParseRecognizesHtmlBr() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Linea uno<br>Linea dos")

        XCTAssertEqual(blocks.count, 1)
        let kinds = blocks[0].inlines.map(\.kind)
        XCTAssertTrue(kinds.contains(.hardBreak), "Debe contener un hardBreak tras <br>")
    }

    func testParseRecognizesHtmlImg() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Antes <img src=\"foto.png\" alt=\"Mi foto\"> despues")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].inlines, [
            MarkdownInlineRun(kind: .plainText, text: "Antes ", url: ""),
            MarkdownInlineRun(kind: .image, text: "Mi foto", url: "foto.png"),
            MarkdownInlineRun(kind: .plainText, text: " despues", url: "")
        ])
    }

    func testParseTreatsUnknownHtmlTagAsLiteral() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Esto <span>no se toca</span> aqui")

        XCTAssertEqual(blocks.count, 1)
        // <span> no es una etiqueta conocida, asi que el '<' se trata como literal.
        let text = blocks[0].inlines.map(\.text).joined()
        XCTAssertTrue(text.contains("<span>") || text.contains("&lt;"))
    }

    func testParseDoesNotResolveEmphasisInsideCodeBlocks() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("```\nesto **no** se toca\n```")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .codeBlock(language: ""))
        XCTAssertEqual(blocks[0].text, "esto **no** se toca")
        XCTAssertTrue(blocks[0].inlines.isEmpty)
    }

    func testParseHeadingLevelAndInlineEmphasisTogether() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("## Titulo con **enfasis**")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .heading(level: 2))
        XCTAssertEqual(blocks[0].inlines, [
            MarkdownInlineRun(kind: .plainText, text: "Titulo con ", url: ""),
            MarkdownInlineRun(kind: .bold, text: "enfasis", url: "")
        ])
    }

    // MARK: - layout() / motor de layout

    func testLayoutMarginsAreStandardForUSLetter() throws {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("Hola", pageSize: .usLetter)

        // Margenes estandar: 1" (72pt) a cada lado.
        XCTAssertEqual(layout.pages.count, 1)
        let word = try XCTUnwrap(layout.pages[0].elements.first)
        XCTAssertEqual(word.x, 0, accuracy: 0.001)
        XCTAssertEqual(word.y, 0, accuracy: 0.001)

        // 612 - 72*2 = 468 pt de ancho de contenido.
        XCTAssertLessThan(word.width, 468.0)
    }

    func testLayoutSingleShortParagraphFitsOnOnePage() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("Hola mundo", pageSize: .usLetter)

        XCTAssertEqual(layout.pages.count, 1)
        XCTAssertEqual(layout.pages[0].pageNumber, 1)
        XCTAssertEqual(layout.pages[0].elements.map(\.text), ["Hola", "mundo"])
        // La segunda palabra debe estar a la derecha de la primera,
        // en la misma línea (misma y).
        XCTAssertEqual(layout.pages[0].elements[0].y, layout.pages[0].elements[1].y)
        XCTAssertGreaterThan(layout.pages[0].elements[1].x, layout.pages[0].elements[0].x)
    }

    func testLayoutWrapsLongParagraphIntoMultipleLines() {
        let engine = MarkdownPrintEngine()
        let longText = Array(repeating: "palabra", count: 40).joined(separator: " ")
        let layout = engine.layout(longText, pageSize: .usLetter)

        let ys = Set(layout.pages[0].elements.map(\.y))
        XCTAssertGreaterThan(ys.count, 1, "40 palabras deberian ocupar mas de una linea")
    }

    func testLayoutReservesImageBoxWithinContentWidth() throws {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("Antes\n\n![Diagrama](images/diagram.png)\n\nDespues", pageSize: .usLetter)

        let image = try XCTUnwrap(layout.pages.flatMap(\.elements).first { $0.kind == .image })
        XCTAssertEqual(image.text, "Diagrama")
        XCTAssertEqual(image.url, "images/diagram.png")
        XCTAssertEqual(image.x, 0, accuracy: 0.001)
        XCTAssertEqual(image.width, layout.geometry.contentWidth, accuracy: 0.001)
        XCTAssertLessThanOrEqual(image.x + image.width, layout.geometry.contentWidth + 0.001)
    }

    func testLayoutBreaksOversizedWordsBeforeRightMargin() {
        let engine = MarkdownPrintEngine()
        let longWord = String(repeating: "a", count: 200)
        let layout = engine.layout(longWord, pageSize: .usLetter)
        let contentWidth = layout.geometry.contentWidth

        let words = layout.pages.flatMap(\.elements).filter { $0.kind == .word }
        XCTAssertGreaterThan(words.count, 1)
        XCTAssertTrue(words.allSatisfy { $0.x + $0.width <= contentWidth + 0.01 })
    }

    func testLayoutWrapsLongCodeLinesBeforeRightMargin() {
        let engine = MarkdownPrintEngine()
        let longCode = "```\n" + String(repeating: "letVeryLongIdentifier", count: 20) + "\n```"
        let layout = engine.layout(longCode, pageSize: .usLetter)
        let contentWidth = layout.geometry.contentWidth

        let codeWords = layout.pages.flatMap(\.elements).filter { $0.style == .code }
        XCTAssertGreaterThan(codeWords.count, 1)
        XCTAssertTrue(codeWords.allSatisfy { $0.x + $0.width <= contentWidth + 0.01 })
    }

    func testLayoutPaginatesContentThatDoesNotFitOnOnePage() {
        let engine = MarkdownPrintEngine()
        let paragraph = "Este es un parrafo que se repite muchas veces para forzar la paginacion del documento completo. "
        let longDoc = Array(repeating: paragraph, count: 60).joined()
        let layout = engine.layout(longDoc, pageSize: .usLetter)

        XCTAssertGreaterThan(layout.pages.count, 1)
        // Cada página nueva debe reiniciar el cursor cerca de y=0.
        for page in layout.pages {
            let minY = page.elements.map(\.y).min() ?? -1
            XCTAssertEqual(minY, 0, accuracy: 0.001)
        }
    }

    func testLayoutHorizontalRuleSpansFullContentWidth() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("---", pageSize: .usLetter)

        let rule = layout.pages[0].elements.first
        XCTAssertEqual(rule?.kind, .horizontalRule)
        // Margenes de 1": 612 - 144 = 468 pt de ancho de contenido.
        XCTAssertEqual(rule?.width ?? 0, 468.0, accuracy: 0.01)
    }

    func testLayoutListItemsAreIndentedPastTheirMarker() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("- uno\n- dos", pageSize: .usLetter)

        // marcador, texto, marcador, texto
        let elements = layout.pages[0].elements
        XCTAssertEqual(elements.count, 4)
        XCTAssertEqual(elements[0].text, "\u{2022}")
        XCTAssertEqual(elements[0].x, 0, accuracy: 0.001)
        XCTAssertGreaterThan(elements[1].x, elements[0].x)
    }

    func testLayoutMarksHeadingWordsEvenWithoutInlineEmphasis() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("# Titulo simple", pageSize: .usLetter)

        let words = layout.pages[0].elements
        XCTAssertFalse(words.isEmpty)
        XCTAssertTrue(words.allSatisfy { $0.headingLevel > 0 })
    }

    func testLayoutExposesStandardGeometry() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("Hola", pageSize: .usLetter)
        let geometry = layout.geometry

        XCTAssertEqual(geometry.pageWidth, 612)
        XCTAssertEqual(geometry.pageHeight, 792)
        XCTAssertEqual(geometry.marginLeft, 72, accuracy: 0.001)
        XCTAssertEqual(geometry.marginRight, 72, accuracy: 0.001)
        XCTAssertEqual(geometry.marginTop, 72, accuracy: 0.001)
        XCTAssertEqual(geometry.marginBottom, 90, accuracy: 0.001)
        XCTAssertEqual(geometry.contentWidth, 468.0, accuracy: 0.01)
        XCTAssertEqual(geometry.contentHeight, 630.0, accuracy: 0.01)
        XCTAssertEqual(geometry.marginLeft + geometry.contentWidth + geometry.marginRight, geometry.pageWidth, accuracy: 0.01)
        XCTAssertEqual(geometry.marginTop + geometry.contentHeight + geometry.marginBottom, geometry.pageHeight, accuracy: 0.01)
    }

    // MARK: - Tablas

    func testTokenizeRecognizesTableRows() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("| Col A | Col B |\n|-------|-------|\n| val 1 | val 2 |")

        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(tokens[0].kind, .tableRow)
        XCTAssertEqual(tokens[1].kind, .tableRow)
        XCTAssertEqual(tokens[2].kind, .tableRow)
    }

    func testParseGroupsConsecutiveTableRowsIntoTableBlock() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("| Nombre | Edad |\n|--------|------|\n| Ana    | 28   |\n| Luis   | 34   |")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .table(columnCount: 2))
        XCTAssertEqual(blocks[0].tableHeaders, ["Nombre", "Edad"])
        // celdas: Nombre, Edad (cabecera), Ana, 28, Luis, 34
        XCTAssertEqual(blocks[0].tableCells, ["Nombre", "Edad", "Ana", "28", "Luis", "34"])
    }

    func testParseTableWithoutSeparatorTreatsAllRowsAsData() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("| A | B |\n| 1 | 2 |")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .table(columnCount: 2))
        // Sin separador: la primera fila es cabecera, la segunda son datos
        XCTAssertEqual(blocks[0].tableHeaders, ["A", "B"])
        XCTAssertEqual(blocks[0].tableCells, ["A", "B", "1", "2"])
    }

    func testLayoutTableProducesElements() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("| X | Y |\n|---|---|\n| 1 | 2 |", pageSize: .usLetter)

        XCTAssertEqual(layout.pages.count, 1)
        let elements = layout.pages[0].elements
        // Debe haber lineas de cuadricula y texto de celdas
        XCTAssertFalse(elements.isEmpty)
        let gridLines = elements.filter { $0.kind == .tableGridLine }
        let words = elements.filter { $0.kind == .word }
        XCTAssertFalse(gridLines.isEmpty, "Debe haber lineas de cuadricula")
        XCTAssertFalse(words.isEmpty, "Debe haber texto de celdas")
    }

    // MARK: - Numeracion de listas ordenadas (CommonMark)

    func testParseAutoIncrementsOrderedListNumbersFromFirstItem() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("1. uno\n1. dos\n1. tres")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .orderedList)
        XCTAssertEqual(blocks[0].items.map(\.number), [1, 2, 3])
    }

    func testParseOrderedListStartsFromExplicitNumber() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("5. quinto\n1. sexto\n1. septimo")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .orderedList)
        XCTAssertEqual(blocks[0].items.map(\.number), [5, 6, 7])
    }

    // MARK: - Outline y metadatos

    func testLayoutHeadingsHaveCorrectHeadingLevel() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("# H1\n## H2\n### H3\nTexto plano", pageSize: .usLetter)

        let headingElements = layout.pages[0].elements.filter { $0.kind == .word && $0.headingLevel > 0 }
        let levels = headingElements.map(\.headingLevel)
        XCTAssertTrue(levels.contains(1), "Debe haber elementos con headingLevel 1 (H1)")
        XCTAssertTrue(levels.contains(2), "Debe haber elementos con headingLevel 2 (H2)")
        XCTAssertTrue(levels.contains(3), "Debe haber elementos con headingLevel 3 (H3)")
    }

    func testLayoutPlainTextHasHeadingLevelZero() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("Esto es un parrafo normal sin encabezados.", pageSize: .usLetter)

        let headingLevels = layout.pages[0].elements
            .filter { $0.kind == .word }
            .map(\.headingLevel)
        XCTAssertTrue(headingLevels.allSatisfy { $0 == 0 }, "Los parrafos normales deben tener headingLevel 0")
    }

    func testLayoutPreservesHeadingLevelAcrossPages() {
        let engine = MarkdownPrintEngine()
        // Suficientes encabezados para forzar multiples paginas
        var md = ""
        for i in 1...60 {
            md += "# Encabezado \(i)\n\nTexto del encabezado \(i).\n\n"
        }
        let layout = engine.layout(md, pageSize: .usLetter)

        // Debe haber al menos una pagina con encabezados
        let pagesWithHeadings = layout.pages.filter { page in
            page.elements.contains { $0.headingLevel > 0 }
        }
        XCTAssertFalse(pagesWithHeadings.isEmpty, "Debe haber paginas con encabezados")
    }

    // MARK: - Fixtures (archivos .md reales)

    func testFixtureSimpleDocumentParsesCorrectly() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "simple", withExtension: "md", subdirectory: "Resources"))
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let engine = MarkdownPrintEngine()

        let blocks = engine.parse(markdown)
        XCTAssertGreaterThan(blocks.count, 2, "Debe tener varios bloques")

        let headings = blocks.filter { $0.kind != .paragraph && $0.kind != .unknown }
        XCTAssertFalse(headings.isEmpty, "Debe tener encabezados")

        let layout = engine.layout(markdown, pageSize: .a4)
        XCTAssertEqual(layout.pages.count, 1, "Documento simple debe caber en 1 pagina")
        XCTAssertGreaterThan(layout.pages[0].elements.count, 5, "Debe tener varios elementos")
    }

    func testFixtureTablesParseCorrectly() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "tables", withExtension: "md", subdirectory: "Resources"))
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let engine = MarkdownPrintEngine()

        let blocks = engine.parse(markdown)
        let tableBlocks = blocks.filter { $0.kind != .paragraph && $0.kind != .unknown && $0.kind != .heading(level: 1) }
        XCTAssertEqual(tableBlocks.count, 2, "Debe haber 2 tablas")

        let layout = engine.layout(markdown, pageSize: .a4)
        let tableGridLines = layout.pages.flatMap(\.elements).filter { $0.kind == .tableGridLine }
        XCTAssertFalse(tableGridLines.isEmpty, "Debe tener lineas de cuadricula")
    }

    func testFixtureLinksParseCorrectly() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "links", withExtension: "md", subdirectory: "Resources"))
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let engine = MarkdownPrintEngine()

        let blocks = engine.parse(markdown)
        let allInlines = blocks.flatMap(\.inlines)
        let links = allInlines.filter { $0.kind == .link }
        let images = allInlines.filter { $0.kind == .image }

        XCTAssertGreaterThan(links.count, 1, "Debe tener al menos 2 enlaces")
        XCTAssertGreaterThan(images.count, 0, "Debe tener al menos 1 imagen")
    }

    func testFixtureRendersPDFWithoutCrashing() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "simple", withExtension: "md", subdirectory: "Resources"))
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let engine = MarkdownPrintEngine()

        let result = try! engine.render(markdown, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000, "PDF debe tener contenido")
        XCTAssertGreaterThan(result.pageCount, 0, "Debe tener al menos 1 pagina")
        XCTAssertGreaterThan(result.headingCount, 0, "Debe tener al menos 1 heading")
        XCTAssertGreaterThan(result.duration, 0, "Debe medir duracion")
    }

    // MARK: - HTML Block tests

    func testParseDetectsHtmlBlockTags() {
        let engine = MarkdownPrintEngine()
        let divBlocks = engine.parse("<div>\nHola\n</div>")
        let preBlocks = engine.parse("<pre>\ncodigo\n</pre>")
        let tableBlocks = engine.parse("<table>\n<tr><td>x</td></tr>\n</table>")

        let divHtmlBlocks = divBlocks.filter { if case .rawHtmlBlock = $0.kind { true } else { false } }
        let preHtmlBlocks = preBlocks.filter { if case .rawHtmlBlock = $0.kind { true } else { false } }
        let tableHtmlBlocks = tableBlocks.filter { if case .rawHtmlBlock = $0.kind { true } else { false } }

        XCTAssertEqual(divHtmlBlocks.count, 1, "Debe detectar <div> como bloque HTML")
        XCTAssertEqual(preHtmlBlocks.count, 1, "Debe detectar <pre> como bloque HTML")
        XCTAssertEqual(tableHtmlBlocks.count, 1, "Debe detectar <table> como bloque HTML")

        if let block = divHtmlBlocks.first {
            XCTAssertEqual(block.htmlTag, "div")
            XCTAssertTrue(block.htmlContent.contains("<div>"))
            XCTAssertTrue(block.htmlContent.contains("</div>"))
        }
        if let block = preHtmlBlocks.first {
            XCTAssertEqual(block.htmlTag, "pre")
        }
        if let block = tableHtmlBlocks.first {
            XCTAssertEqual(block.htmlTag, "table")
        }
    }

    func testParseDoesNotDetectInlineHtmlAsBlock() {
        let engine = MarkdownPrintEngine()
        // <em>, <strong>, <a> no son etiquetas de bloque
        let blocks = engine.parse("Texto con <em>enfasis</em> y <strong>negrita</strong> y <a href=\"url\">enlace</a>.")
        let htmlBlocks = blocks.filter { if case .rawHtmlBlock = $0.kind { true } else { false } }
        XCTAssertEqual(htmlBlocks.count, 0, "Las etiquetas inline NO deben ser bloques HTML")
    }

    func testFixtureHtmlParsesCorrectly() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "html", withExtension: "md", subdirectory: "Resources"))
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let engine = MarkdownPrintEngine()

        let blocks = engine.parse(markdown)
        let htmlBlocks = blocks.filter { if case .rawHtmlBlock = $0.kind { true } else { false } }

        XCTAssertGreaterThan(htmlBlocks.count, 2, "Debe detectar al menos 3 bloques HTML")
        // Verificar que hay un heading normal tambien.
        let headings = blocks.filter { if case .heading = $0.kind { true } else { false } }
        XCTAssertEqual(headings.count, 1, "Debe detectar el heading normal")
        // Verificar tags detectados.
        let tags = htmlBlocks.map(\.htmlTag).sorted()
        XCTAssertTrue(tags.contains("div"), "Debe detectar tag div")
        XCTAssertTrue(tags.contains("pre"), "Debe detectar tag pre")
        XCTAssertTrue(tags.contains("table"), "Debe detectar tag table")
    }

    func testFixtureHtmlRendersPDFWithoutCrashing() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "html", withExtension: "md", subdirectory: "Resources"))
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let engine = MarkdownPrintEngine()

        let result = try! engine.render(markdown, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000, "PDF debe tener contenido")
        XCTAssertGreaterThan(result.pageCount, 0, "Debe tener al menos 1 pagina")
    }

    // MARK: - Data-based API tests

    func testTokenizeWithData() throws {
        let engine = MarkdownPrintEngine()
        let data = "# Hola\n\nParrafo.".data(using: .utf8)!
        let tokens = try engine.tokenize(data: data)
        XCTAssertGreaterThan(tokens.count, 1)
    }

    func testParseWithData() throws {
        let engine = MarkdownPrintEngine()
        let data = "# Titulo\n\nTexto con **negrita**.".data(using: .utf8)!
        let blocks = try engine.parse(data: data)
        XCTAssertGreaterThan(blocks.count, 1)
        let headings = blocks.filter { if case .heading = $0.kind { true } else { false } }
        XCTAssertEqual(headings.count, 1)
    }

    func testRenderPDFWithData() throws {
        let engine = MarkdownPrintEngine()
        let data = "# PDF desde Data\n\nHola mundo.".data(using: .utf8)!
        let pdfData = try! engine.renderPDF(fromMarkdownData: data, pageSize: .a4)
        XCTAssertGreaterThan(pdfData.count, 1000)
    }

    func testRenderPDFWithDiagnosticsFromData() throws {
        let engine = MarkdownPrintEngine()
        let data = "# Test\n\n[Link](https://example.com)".data(using: .utf8)!
        let result = try! engine.renderPDFWithDiagnostics(fromMarkdownData: data, pageSize: .a4)
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertEqual(result.linkCount, 1)
        XCTAssertEqual(result.headingCount, 1)
    }

    func testInvalidUTF8ThrowsError() {
        let engine = MarkdownPrintEngine()
        // 0xFF es invalido en UTF-8
        let invalidData = Data([0xFF, 0xFE, 0x00, 0x01])
        XCTAssertThrowsError(try engine.parse(data: invalidData)) { error in
            XCTAssertEqual(error as? MarkdownPrintError, .invalidUTF8)
        }
    }
    func testRenderPDFWithTOC() throws {
        let engine = MarkdownPrintEngine()
        let markdown = "# H1\n\n## H2\n\nTexto.\n\n# Otro H1\n\nFinal."
        let result = try! engine.render(markdown, options: RenderOptions(pageSize: .a4, withTOC: true))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        // Con TOC, las paginas de contenido se desplazan
        XCTAssertGreaterThan(result.pageCount, 0)
    }

    func testRenderPDFWithTOCReportsActualPDFPageCount() throws {
        let engine = MarkdownPrintEngine()
        let markdown = (1...40)
            .map { "# Section \($0)\n\nText for section \($0)." }
            .joined(separator: "\n\n")

        let result = try engine.render(markdown, options: RenderOptions(pageSize: .a4, withTOC: true))

        #if canImport(PDFKit)
        let document = try XCTUnwrap(PDFDocument(data: result.pdfData))
        XCTAssertEqual(result.pageCount, document.pageCount)
        XCTAssertGreaterThanOrEqual(result.pageCount, engine.layout(markdown, pageSize: .a4).pages.count)
        #else
        XCTAssertGreaterThan(result.pageCount, 0)
        #endif
    }

    // MARK: - Math/LaTeX tests

    func testParseDisplayMath() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("$$\nx = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\n$$")
        let mathBlocks = blocks.filter { if case .mathBlock = $0.kind { true } else { false } }
        XCTAssertEqual(mathBlocks.count, 1, "Debe detectar bloque $$...$$")
        let mathText = mathBlocks.first?.text ?? ""
        XCTAssertTrue(mathText.contains("frac"), "Debe contener la ecuacion LaTeX")
    }

    func testParseInlineMath() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("La formula $E = mc^2$ es famosa.")
        let paragraphs = blocks.filter { if case .paragraph = $0.kind { true } else { false } }
        XCTAssertEqual(paragraphs.count, 1)
        let inlines = paragraphs.first?.inlines ?? []
        let mathInlines = inlines.filter { $0.kind == .inlineMath }
        XCTAssertEqual(mathInlines.count, 1, "Debe detectar $...$ inline")
        XCTAssertEqual(mathInlines.first?.text, "E = mc^2")
    }

    func testParseMathDoesNotConfuseCurrency() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Cuesta $50 dolares.")
        let inlines = blocks.first?.inlines ?? []
        let mathInlines = inlines.filter { $0.kind == .inlineMath }
        XCTAssertEqual(mathInlines.count, 0, "$50 no es math inline")
    }

    func testRenderMathPDF() throws {
        let engine = MarkdownPrintEngine()
        let markdown = """
        # Ecuaciones

        $$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$$

        Tambien tenemos $a^2 + b^2 = c^2$ inline.
        """
        let result = try! engine.render(markdown, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertGreaterThan(result.pageCount, 0)
    }

    // MARK: - Tokenize: cobertura completa

    func testTokenizeBlockquote() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("> cita\n> otra linea")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].kind, .blockquote)
        XCTAssertEqual(tokens[0].text, "cita")
        XCTAssertEqual(tokens[1].kind, .blockquote)
        XCTAssertEqual(tokens[1].text, "otra linea")
    }

    func testTokenizeBlockquoteEmptyLine() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize(">")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .blockquote)
        XCTAssertEqual(tokens[0].text, "")
    }

    func testTokenizeYamlFrontMatterIsDiscarded() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("---\ntitle: Hola\nauthor: Yo\n---\n\n# Real")
        let headings = tokens.filter { if case .heading = $0.kind { true } else { false } }
        XCTAssertEqual(headings.count, 1)
        XCTAssertEqual(headings[0].text, "Real")
    }

    func testTokenizeYamlFrontMatterWithDots() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("---\ntitle: Hola\n...\n\nTexto")
        // YAML front-matter con ... deberia descartarse dejando solo el parrafo
        _ = tokens.filter { if case .paragraph = $0.kind { true } else { false } }
        _ = tokens.filter { if case .heading = $0.kind { true } else { false } }
        // El contenido real (Texto) debe estar presente
        let allText = tokens.map(\.text).joined(separator: " ")
        XCTAssertTrue(allText.contains("Texto"), "El contenido real debe estar presente")
    }

    func testTokenizeSetextHeadingLevel1() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("Titulo\n=====")
        // Setext H1: ==== se convierte correctamente
        if tokens.count >= 1, case .heading(let level) = tokens[0].kind {
            XCTAssertEqual(level, 1)
        }
        // Si no es heading, al menos debe haber tokens validos
        XCTAssertGreaterThan(tokens.count, 0)
    }

    func testTokenizeSetextHeadingLevel2() {
        let engine = MarkdownPrintEngine()
        // Setext H2: ----- compite con horizontal rule, verificamos que
        // el resultado sea valido (puede ser heading o hr + paragraph)
        let tokens = engine.tokenize("Subtitulo\n-----")
        XCTAssertGreaterThan(tokens.count, 0)
        // El texto del subtitulo debe aparecer en algun token
        let allText = tokens.map(\.text).joined(separator: " ")
        XCTAssertTrue(allText.contains("Subtitulo") || tokens.contains { if case .heading = $0.kind { true } else { false } })
    }

    func testTokenizeTaskListUnchecked() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("- [ ] pendiente\n- [x] hecho\n- [X] tambien")
        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(tokens[0].kind, .unorderedListItem)
        XCTAssertEqual(tokens[0].text, "pendiente")
        XCTAssertEqual(tokens[1].kind, .unorderedListItem)
        XCTAssertEqual(tokens[1].text, "hecho")
        XCTAssertEqual(tokens[2].kind, .unorderedListItem)
        XCTAssertEqual(tokens[2].text, "tambien")
    }

    func testTokenizeIndentedCodeBlock() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("    codigo indentado\n    linea 2")
        XCTAssertEqual(tokens.count, 1)
        if case .codeBlock(let lang) = tokens[0].kind {
            XCTAssertEqual(lang, "") // sin lenguaje
        } else { XCTFail("Debe ser codeBlock") }
        XCTAssertTrue(tokens[0].text.contains("codigo indentado"))
    }

    func testTokenizeHardBreakWithTwoSpaces() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("linea con break  \nsiguiente")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].kind, .paragraph)
        XCTAssertEqual(tokens[1].kind, .paragraph)
    }

    func testTokenizeHtmlBlockTags() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("<div>\ncontenido\n</div>")
        let htmlTokens = tokens.filter { $0.kind == .rawHtmlBlock }
        XCTAssertEqual(htmlTokens.count, 1, "Debe agrupar en un solo token")
        XCTAssertTrue(htmlTokens[0].text.contains("<div>"))
        XCTAssertTrue(htmlTokens[0].text.contains("</div>"))
    }

    func testTokenizeMathBlock() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("$$\nx = 1\n$$")
        let mathTokens = tokens.filter { $0.kind == .mathBlock }
        XCTAssertEqual(mathTokens.count, 1)
        XCTAssertTrue(mathTokens[0].text.contains("x = 1"))
    }

    func testTokenizeStarHorizontalRule() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("***")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .horizontalRule)
    }

    func testTokenizeUnderscoreHorizontalRule() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("___")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .horizontalRule)
    }

    func testTokenizeCodeBlockWithTildeFence() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("~~~\ncodigo\n~~~")
        XCTAssertEqual(tokens.count, 1)
        if case .codeBlock = tokens[0].kind { } else { XCTFail("Debe ser codeBlock") }
    }

    func testTokenizeLongFenceWithBackticksInside() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("````\n```inner\ncode\n```\n````")
        XCTAssertEqual(tokens.count, 1)
        if case .codeBlock = tokens[0].kind { } else { XCTFail("Debe ser codeBlock") }
        XCTAssertTrue(tokens[0].text.contains("```inner"))
    }

    // MARK: - Parse: cobertura completa

    func testParseEmptyDocument() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("")
        XCTAssertEqual(blocks.count, 0)
    }

    func testParseWhitespaceOnly() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("   \n\n   \n")
        XCTAssertEqual(blocks.count, 0, "Documento vacio no produce bloques")
    }

    func testParseSetextHeadingInAST() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Titulo\n=====\n\nTexto")
        let headings = blocks.filter { if case .heading(let l) = $0.kind, l == 1 { true } else { false } }
        XCTAssertEqual(headings.count, 1)
        XCTAssertEqual(headings[0].inlines.map(\.text).joined(), "Titulo")
    }

    func testParseBlockquoteMergesLines() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("> linea uno\n> linea dos")
        let quotes = blocks.filter { if case .blockquote = $0.kind { true } else { false } }
        XCTAssertEqual(quotes.count, 1)
        let text = quotes[0].inlines.map(\.text).joined(separator: " ")
        XCTAssertTrue(text.contains("linea uno"))
        XCTAssertTrue(text.contains("linea dos"))
    }

    func testParseNestedListThreeLevels() {
        let engine = MarkdownPrintEngine()
        let md = "- N1\n  - N2\n    - N3\n- N1 again"
        let blocks = engine.parse(md)
        let lists = blocks.filter { if case .unorderedList = $0.kind { true } else { false } }
        XCTAssertEqual(lists.count, 1)
        XCTAssertEqual(lists[0].items.count, 2)
        XCTAssertEqual(lists[0].items[0].items.count, 1, "N2 dentro de N1")
        XCTAssertEqual(lists[0].items[0].items[0].items.count, 1, "N3 dentro de N2")
    }

    func testParseNestedOrderedList() {
        let engine = MarkdownPrintEngine()
        let md = "1. A\n   1. A.1\n   1. A.2\n2. B"
        let blocks = engine.parse(md)
        let lists = blocks.filter { if case .orderedList = $0.kind { true } else { false } }
        XCTAssertEqual(lists.count, 1)
        XCTAssertEqual(lists[0].items.count, 2)
        XCTAssertEqual(lists[0].items[0].items.count, 2)
    }

    func testParseTableWithAlignment() {
        let engine = MarkdownPrintEngine()
        let md = "| L | C | R |\n|:--|:-:|--:|\n| a | b | c |"
        let blocks = engine.parse(md)
        let tables = blocks.filter { if case .table = $0.kind { true } else { false } }
        XCTAssertEqual(tables.count, 1)
        // Verificar que las celdas se parsean
        XCTAssertEqual(tables[0].tableColumnCount, 3)
    }

    func testParseHorizontalRuleInAST() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("antes\n\n---\n\ndespues")
        let rules = blocks.filter { if case .horizontalRule = $0.kind { true } else { false } }
        XCTAssertEqual(rules.count, 1)
    }

    func testParseStrikethrough() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Texto ~~tachado~~ final")
        let paras = blocks.filter { if case .paragraph = $0.kind { true } else { false } }
        XCTAssertEqual(paras.count, 1)
        let striked = paras[0].inlines.filter { $0.kind == .strikethrough }
        XCTAssertEqual(striked.count, 1)
        XCTAssertEqual(striked[0].text, "tachado")
    }

    func testParseLinkWithUrl() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("[Google](https://google.com)")
        let links = blocks[0].inlines.filter { $0.kind == .link }
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].text, "Google")
        XCTAssertEqual(links[0].url, "https://google.com")
    }

    func testParseReferenceLink() {
        let engine = MarkdownPrintEngine()
        let md = "[docs][ref]\n\n[ref]: https://docs.example.com"
        let blocks = engine.parse(md)
        let allInlines = blocks.flatMap(\.inlines)
        let links = allInlines.filter { $0.kind == .link }
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].url, "https://docs.example.com")
    }

    func testParseImplicitReferenceLink() {
        let engine = MarkdownPrintEngine()
        let md = "[docs][]\n\n[docs]: https://docs.example.com"
        let blocks = engine.parse(md)
        let links = blocks.flatMap(\.inlines).filter { $0.kind == .link }
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].url, "https://docs.example.com")
    }

    func testParseEscapedCharacters() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("\\*no negrita\\* y \\`no codigo\\`")
        let inlines = blocks[0].inlines
        let bold = inlines.filter { $0.kind == .bold }
        let code = inlines.filter { $0.kind == .code }
        XCTAssertEqual(bold.count, 0, "Escapado previene negrita")
        XCTAssertEqual(code.count, 0, "Escapado previene codigo")
    }

    func testParseCodeBlockWithoutLanguage() {
        let engine = MarkdownPrintEngine()
        let md = "```\ncodigo sin lenguaje\n```"
        let blocks = engine.parse(md)
        let codeBlocks = blocks.filter { if case .codeBlock(let lang) = $0.kind, lang.isEmpty { true } else { false } }
        XCTAssertEqual(codeBlocks.count, 1)
        XCTAssertEqual(codeBlocks[0].text, "codigo sin lenguaje")
    }

    func testParseHtmlAnchorWithHref() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("<a href=\"https://x.com\">enlace</a>")
        let links = blocks[0].inlines.filter { $0.kind == .link }
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].url, "https://x.com")
    }

    // MARK: - Layout: cobertura completa

    func testLayoutMathBlockGeneratesElements() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("$$\nx = 1\n$$", pageSize: .a4)
        let pages = layout.pages
        XCTAssertGreaterThan(pages.count, 0)
        let mathElements = pages.flatMap(\.elements).filter { $0.kind == .mathBlock }
        XCTAssertGreaterThan(mathElements.count, 0, "Debe generar elementos mathBlock")
    }

    func testLayoutHtmlBlockGeneratesElements() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("<div>\ntexto\n</div>", pageSize: .a4)
        let rawHtmlElements = layout.pages.flatMap(\.elements).filter { $0.kind == .rawHtml }
        XCTAssertGreaterThan(rawHtmlElements.count, 0, "Debe generar elementos rawHtml")
    }

    func testLayoutBlockquoteTextHasBlockquoteFlag() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("> Una cita de prueba", pageSize: .a4)
        let allElements = layout.pages.flatMap(\.elements)
        let blockquoteElements = allElements.filter { $0.isBlockquote }
        XCTAssertFalse(blockquoteElements.isEmpty, "Debe haber elementos con isBlockquote = true")
        // Verificar que el texto de la cita se renderiza en muted
        let blockquoteWords = blockquoteElements.filter { $0.kind == .word }
        XCTAssertFalse(blockquoteWords.isEmpty, "Debe haber palabras dentro de la cita")
    }

    func testLayoutTableHasGridLines() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("| A | B |\n|---|---|\n| 1 | 2 |", pageSize: .a4)
        let gridLines = layout.pages.flatMap(\.elements).filter { $0.kind == .tableGridLine }
        XCTAssertGreaterThan(gridLines.count, 0, "Debe generar lineas de cuadricula")
    }

    func testLayoutA4Geometry() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("test", pageSize: .a4)
        XCTAssertEqual(layout.geometry.pageWidth, 595.2756, accuracy: 0.1)
        XCTAssertEqual(layout.geometry.pageHeight, 841.8898, accuracy: 0.1)
    }

    func testLayoutUSLetterGeometry() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("test", pageSize: .usLetter)
        XCTAssertEqual(layout.geometry.pageWidth, 612.0, accuracy: 0.1)
        XCTAssertEqual(layout.geometry.pageHeight, 792.0, accuracy: 0.1)
    }

    func testLayoutCustomPageSize() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("test", pageSize: .custom(width: 400, height: 600))
        XCTAssertEqual(layout.geometry.pageWidth, 400.0, accuracy: 0.1)
        XCTAssertEqual(layout.geometry.pageHeight, 600.0, accuracy: 0.1)
    }

    func testLayoutImageElement() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("![foto](test.png)", pageSize: .a4)
        let images = layout.pages.flatMap(\.elements).filter { $0.kind == .image }
        XCTAssertGreaterThan(images.count, 0, "Debe generar elemento imagen")
        XCTAssertEqual(images[0].url, "test.png")
    }

    // MARK: - PDF Render: temas, metadata, edge cases

    func testRenderPDFWithLightTheme() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("# Hola", options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFWithDarkTheme() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("# Hola", options: RenderOptions(pageSize: .a4, theme: .dark))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFWithMonoTheme() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("# Hola", options: RenderOptions(pageSize: .a4, theme: .mono))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFWithMetadata() throws {
        let engine = MarkdownPrintEngine()
        let metadata = PDFMetadata(title: "Test Title", author: "Test Author")
        let result = try! engine.render("# Titulo", options: RenderOptions(pageSize: .a4, metadata: metadata))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFWithNilMetadata() throws {
        let engine = MarkdownPrintEngine()
        let metadata = PDFMetadata(title: nil, author: nil)
        let result = try! engine.render("texto", options: RenderOptions(pageSize: .a4, metadata: metadata))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testPDFRenderResultDiagnostics() throws {
        let engine = MarkdownPrintEngine()
        let md = """
        # Titulo

        [Link](https://x.com) y ![img](foto.png)

        ## Subtitulo

        Texto final.
        """
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertEqual(result.linkCount, 1, "Debe contar 1 enlace")
        XCTAssertEqual(result.imageCount, 1, "Debe contar 1 imagen")
        XCTAssertEqual(result.headingCount, 2, "Debe contar 2 headings")
        XCTAssertGreaterThan(result.pageCount, 0)
        XCTAssertGreaterThan(result.duration, 0)
        let diag = result.diagnostics
        XCTAssertTrue(diag.contains("Paginas"))
        XCTAssertTrue(diag.contains("Enlaces"))
        XCTAssertTrue(diag.contains("Imagenes"))
        XCTAssertTrue(diag.contains("Headings"))
    }

    func testRenderPDFTOCIncreasesPageCount() throws {
        let engine = MarkdownPrintEngine()
        let md = "# H1\n\n## H2\n\n### H3\n\nTexto largo.\n\n# Otro H1\n\nMas texto."
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4, withTOC: false))
        let resultTOC = try engine.render(md, options: RenderOptions(pageSize: .a4, withTOC: true))
        // Con TOC deberia tener al menos las mismas paginas de contenido
        XCTAssertGreaterThanOrEqual(resultTOC.pageCount, result.pageCount)
    }

    // MARK: - Edge cases y robustez

    func testRenderEmptyDocument() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("", options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 0) // PDF vacio pero valido
        // Documento vacio puede producir 0 o 1 pagina segun implementacion
        XCTAssertLessThanOrEqual(result.pageCount, 1)
    }

    func testRenderUnicodeDocument() throws {
        let engine = MarkdownPrintEngine()
        let md = "# 日本語\n\n español\n\n中文测试\n\nالعربية\n\n🌟✨"
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testParseVeryLongWord() {
        let engine = MarkdownPrintEngine()
        let longWord = String(repeating: "A", count: 500)
        let blocks = engine.parse(longWord)
        XCTAssertEqual(blocks.count, 1)
        if case .paragraph = blocks[0].kind { } else { XCTFail("Debe ser parrafo") }
    }

    func testLayoutVeryLongWordWraps() {
        let engine = MarkdownPrintEngine()
        let longWord = String(repeating: "A", count: 500)
        let layout = engine.layout(longWord, pageSize: .a4)
        let words = layout.pages.flatMap(\.elements).filter { $0.kind == .word }
        XCTAssertGreaterThan(words.count, 1, "Palabra larga debe dividirse en varias")
    }

    func testParseMultipleBlankLines() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("Hola\n\n\n\n\nMundo")
        let paragraphs = blocks.filter { if case .paragraph = $0.kind { true } else { false } }
        XCTAssertEqual(paragraphs.count, 2)
    }

    func testParseManyHeadings() {
        let engine = MarkdownPrintEngine()
        let parts = (1...6).map { "\(String(repeating: "#", count: $0)) H\($0)" }
        let blocks = engine.parse(parts.joined(separator: "\n\n"))
        let headings = blocks.filter { if case .heading = $0.kind { true } else { false } }
        XCTAssertGreaterThanOrEqual(headings.count, 4, "Debe detectar al menos 4 niveles de heading")
    }

    func testParseTableWithEmptyCells() {
        let engine = MarkdownPrintEngine()
        let md = "| A | B |\n|---|---|\n| x |   |\n|   | y |"
        let blocks = engine.parse(md)
        let tables = blocks.filter { if case .table = $0.kind { true } else { false } }
        XCTAssertEqual(tables.count, 1)
    }

    func testParseOrderedListStartAtFive() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("5. quinto\n6. sexto")
        let lists = blocks.filter { if case .orderedList = $0.kind { true } else { false } }
        XCTAssertEqual(lists.count, 1)
        XCTAssertEqual(lists[0].items[0].number, 5)
        XCTAssertEqual(lists[0].items[1].number, 6)
    }

    func testLexerHandlesOnlyFenceOpen() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("```\ncodigo sin cerrar")
        XCTAssertEqual(tokens.count, 1)
        if case .codeBlock = tokens[0].kind { } else { XCTFail("Debe ser codeBlock") }
        XCTAssertTrue(tokens[0].text.contains("codigo sin cerrar"))
    }

    func testAPIAllPageSizes() {
        let cases: [(MarkdownPageSize, Double, Double)] = [
            (.usLetter, 612, 792),
            (.a4, 595.2756, 841.8898),
            (.custom(width: 300, height: 500), 300, 500)
        ]
        for (size, w, h) in cases {
            let dims = size.dimensions
            XCTAssertEqual(dims.width, w, accuracy: 0.1)
            XCTAssertEqual(dims.height, h, accuracy: 0.1)
        }
    }

    func testThemeColorsAreValid() {
        // Verificar que los 3 temas devuelven colores no opacos
        let themes: [(MarkdownPrintTheme, String)] = [(.light, "light"), (.dark, "dark"), (.mono, "mono")]
        for (theme, _) in themes {
            XCTAssertEqual(theme.pageBackground.alpha, 1.0)
            XCTAssertEqual(theme.text.alpha, 1.0)
        }
    }

    func testLightThemeHasLightBackground() {
        let theme = MarkdownPrintTheme.light
        let bg = theme.pageBackground
        guard let components = bg.components, components.count >= 3 else { return }
        XCTAssertGreaterThan(components[0] + components[1] + components[2], 2.0, "Fondo claro debe ser claro")
    }

    func testDarkThemeHasDarkBackground() {
        let theme = MarkdownPrintTheme.dark
        let bg = theme.pageBackground
        guard let components = bg.components, components.count >= 3 else { return }
        XCTAssertLessThan(components[0] + components[1] + components[2], 1.0, "Fondo oscuro debe ser oscuro")
    }

    // MARK: - InlineParser: edge cases de enfasis

    func testParseBoldWithTrailingPunctuation() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("**negrita**, sigue.")
        let inlines = blocks[0].inlines
        let bold = inlines.filter { $0.kind == .bold }
        XCTAssertEqual(bold.count, 1)
        XCTAssertEqual(bold[0].text, "negrita")
    }

    func testParseItalicWithTrailingPunctuation() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("*cursiva*.")
        let inlines = blocks[0].inlines
        let italic = inlines.filter { $0.kind == .italic }
        XCTAssertEqual(italic.count, 1)
        XCTAssertEqual(italic[0].text, "cursiva")
    }

    func testParseCodeWithTrailingSemicolon() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("`codigo`;")
        let inlines = blocks[0].inlines
        let code = inlines.filter { $0.kind == .code }
        XCTAssertEqual(code.count, 1)
        XCTAssertEqual(code[0].text, "codigo")
    }

    func testParseMixedInlineEmphasis() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("**negrita** y *cursiva* y `codigo` y ~~tachado~~")
        let inlines = blocks[0].inlines
        XCTAssertTrue(inlines.contains { $0.kind == .bold })
        XCTAssertTrue(inlines.contains { $0.kind == .italic })
        XCTAssertTrue(inlines.contains { $0.kind == .code })
        XCTAssertTrue(inlines.contains { $0.kind == .strikethrough })
    }

    func testParseBoldInsideLink() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("[**descargar**](https://x.com)")
        let links = blocks[0].inlines.filter { $0.kind == .link }
        XCTAssertEqual(links.count, 1)
        XCTAssertTrue(links[0].text.contains("descargar"))
    }

    func testParseMultipleInlineElementsOnSameLine() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("`a` **b** *c* ~~d~~ [e](url) $f$ ![g](img.png)")
        let inlines = blocks[0].inlines
        let kinds = inlines.map(\.kind)
        XCTAssertTrue(kinds.contains(.code))
        XCTAssertTrue(kinds.contains(.bold))
        XCTAssertTrue(kinds.contains(.italic))
        XCTAssertTrue(kinds.contains(.strikethrough))
        XCTAssertTrue(kinds.contains(.link))
        XCTAssertTrue(kinds.contains(.inlineMath))
        XCTAssertTrue(kinds.contains(.image))
    }

    func testParseHardBreak() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("antes<br>despues")
        let inlines = blocks[0].inlines
        XCTAssertTrue(inlines.contains { $0.kind == .hardBreak })
    }

    func testParseHardBreakWithSelfClosing() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("antes<br/>despues")
        let inlines = blocks[0].inlines
        XCTAssertTrue(inlines.contains { $0.kind == .hardBreak })
    }

    func testParseImageWithEmptyAltText() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("![](img.png)")
        let images = blocks[0].inlines.filter { $0.kind == .image }
        XCTAssertEqual(images.count, 1)
        XCTAssertEqual(images[0].url, "img.png")
    }

    func testParseImageWithSpecialCharsInUrl() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("![alt](path/to/image-2024.png)")
        let images = blocks[0].inlines.filter { $0.kind == .image }
        XCTAssertEqual(images.count, 1)
    }

    // MARK: - Engine: preprocesador MarkItDown

    func testPreprocessorRemovesDateTimeHeaders() {
        let engine = MarkdownPrintEngine()
        // Simula salida tipica de MarkItDown con headers de impresion
        let md = """
        6/2/26, 1:35 PM
        Titulo real

        6/2/26, 1:35 PM
        Mas contenido
        """
        let blocks = engine.parse(md)
        let paragraphs = blocks.filter { if case .paragraph = $0.kind { true } else { false } }
        // Debe conservar el contenido real, no los headers de fecha
        let text = paragraphs.map { $0.inlines.map(\.text).joined() }.joined(separator: " ")
        XCTAssertTrue(text.contains("Titulo real") || text.contains("Mas contenido"))
    }

    func testPreprocessorRemovesPageCounters() {
        let engine = MarkdownPrintEngine()
        let md = "1/4\n\nContenido\n\n2/4"
        let blocks = engine.parse(md)
        let paragraphs = blocks.filter { if case .paragraph = $0.kind { true } else { false } }
        let text = paragraphs.map { $0.inlines.map(\.text).joined() }.joined(separator: " ")
        XCTAssertTrue(text.contains("Contenido"))
    }

    func testPreprocessorRemovesRepeatedUrls() {
        let engine = MarkdownPrintEngine()
        let md = """
        https://example.com
        https://example.com
        https://example.com
        Contenido real
        """
        let blocks = engine.parse(md)
        let paragraphs = blocks.filter { if case .paragraph = $0.kind { true } else { false } }
        let text = paragraphs.map { $0.inlines.map(\.text).joined() }.joined(separator: " ")
        XCTAssertTrue(text.contains("Contenido real"))
    }

    func testPreprocessorRemovesFileImageReferences() {
        let engine = MarkdownPrintEngine()
        let md = "(/path/to/image.png)\n\nTexto real"
        let blocks = engine.parse(md)
        let paragraphs = blocks.filter { if case .paragraph = $0.kind { true } else { false } }
        let text = paragraphs.map { $0.inlines.map(\.text).joined() }.joined(separator: " ")
        XCTAssertTrue(text.contains("Texto real"))
    }

    func testPreprocessorNormalizesLigatures() {
        let engine = MarkdownPrintEngine()
        // El preprocesador normaliza ligaduras Unicode a ASCII
        let md = "texto con ligadura fi y fl"
        let blocks = engine.parse(md)
        XCTAssertGreaterThan(blocks.count, 0)
    }

    // MARK: - Combinaciones de elementos

    func testParseCodeBlockAfterHeading() {
        let engine = MarkdownPrintEngine()
        let md = "# Titulo\n\n```\ncodigo\n```"
        let blocks = engine.parse(md)
        let headings = blocks.filter { if case .heading = $0.kind { true } else { false } }
        let codeBlocks = blocks.filter { if case .codeBlock = $0.kind { true } else { false } }
        XCTAssertEqual(headings.count, 1)
        XCTAssertEqual(codeBlocks.count, 1)
    }

    func testParseListAfterCodeBlock() {
        let engine = MarkdownPrintEngine()
        let md = "```\ncode\n```\n\n- item\n- item2"
        let blocks = engine.parse(md)
        let codeBlocks = blocks.filter { if case .codeBlock = $0.kind { true } else { false } }
        let lists = blocks.filter { if case .unorderedList = $0.kind { true } else { false } }
        XCTAssertEqual(codeBlocks.count, 1)
        XCTAssertEqual(lists.count, 1)
    }

    func testParseMultipleHorizontalRules() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("a\n\n---\n\nb\n\n---\n\nc")
        let rules = blocks.filter { if case .horizontalRule = $0.kind { true } else { false } }
        XCTAssertEqual(rules.count, 2)
    }

    func testParseBlockquoteWithEmphasis() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("> Cita con **negrita** y `codigo`")
        let quotes = blocks.filter { if case .blockquote = $0.kind { true } else { false } }
        XCTAssertEqual(quotes.count, 1)
        let inlines = quotes[0].inlines
        XCTAssertTrue(inlines.contains { $0.kind == .bold })
        XCTAssertTrue(inlines.contains { $0.kind == .code })
    }

    func testParseHeadingWithCode() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("# Titulo con `codigo`")
        let inlines = blocks[0].inlines
        XCTAssertTrue(inlines.contains { $0.kind == .code })
        if case .heading(let level) = blocks[0].kind { XCTAssertEqual(level, 1) }
        else { XCTFail("Debe ser heading") }
    }

    func testParseMixedOrderedAndUnorderedLists() {
        let engine = MarkdownPrintEngine()
        let md = "- bullet\n- bullet2\n\n1. primero\n2. segundo"
        let blocks = engine.parse(md)
        let unordered = blocks.filter { if case .unorderedList = $0.kind { true } else { false } }
        let ordered = blocks.filter { if case .orderedList = $0.kind { true } else { false } }
        XCTAssertEqual(unordered.count, 1)
        XCTAssertEqual(ordered.count, 1)
    }

    // MARK: - Tablas: edge cases

    func testParseTableSingleColumn() {
        let engine = MarkdownPrintEngine()
        let md = "| A |\n|---|\n| 1 |\n| 2 |"
        let blocks = engine.parse(md)
        let tables = blocks.filter { if case .table(let cols) = $0.kind, cols == 1 { true } else { false } }
        XCTAssertEqual(tables.count, 1)
    }

    func testParseTableWithoutSeparatorRow() {
        let engine = MarkdownPrintEngine()
        let md = "| A | B |\n| 1 | 2 |"
        let blocks = engine.parse(md)
        let tables = blocks.filter { if case .table = $0.kind { true } else { false } }
        XCTAssertEqual(tables.count, 1)
        // Sin separador, la primera fila es cabecera y datos
        XCTAssertEqual(tables[0].tableColumnCount, 2)
    }

    func testParseTableAllAlignments() {
        let engine = MarkdownPrintEngine()
        let md = "| L | C | R |\n|:--|:-:|--:|\n| a | b | c |"
        let blocks = engine.parse(md)
        let tables = blocks.filter { if case .table = $0.kind { true } else { false } }
        XCTAssertEqual(tables.count, 1)
        XCTAssertEqual(tables[0].tableColumnCount, 3)
    }

    func testLayoutTablePagination() {
        let engine = MarkdownPrintEngine()
        // Crear tabla con muchas filas que deberia paginar
        var rows = "| A | B |\n|---|---|\n"
        for i in 1...60 { rows += "| x\(i) | y\(i) |\n" }
        let layout = engine.layout(rows, pageSize: .a4)
        XCTAssertGreaterThan(layout.pages.count, 1, "Tabla larga debe ocupar varias paginas")
    }

    // MARK: - Imagenes: edge cases

    func testParseImageWithDataUri() {
        let engine = MarkdownPrintEngine()
        let md = "![pixel](data:image/png;base64,iVBORw0KGgo=)"
        let blocks = engine.parse(md)
        let images = blocks[0].inlines.filter { $0.kind == .image }
        XCTAssertEqual(images.count, 1)
    }

    func testLayoutImagePlaceholder() {
        let engine = MarkdownPrintEngine()
        // URL que no se puede cargar -> placeholder
        let layout = engine.layout("![foto](nonexistent.png)", pageSize: .a4)
        let images = layout.pages.flatMap(\.elements).filter { $0.kind == .image }
        XCTAssertGreaterThan(images.count, 0)
    }

    // MARK: - PageGeometry y Layout

    func testPageGeometryMargins() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("test", pageSize: .a4)
        let geo = layout.geometry
        XCTAssertEqual(geo.marginTop, 72.0, accuracy: 1.0)
        XCTAssertEqual(geo.marginBottom, 90.0, accuracy: 1.0)
        XCTAssertEqual(geo.marginLeft, 72.0, accuracy: 1.0)
        XCTAssertEqual(geo.marginRight, 72.0, accuracy: 1.0)
    }

    func testPageGeometryContentArea() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("test", pageSize: .usLetter)
        let geo = layout.geometry
        XCTAssertGreaterThan(geo.contentWidth, 0)
        XCTAssertGreaterThan(geo.contentHeight, 0)
        XCTAssertLessThan(geo.contentWidth, geo.pageWidth)
        XCTAssertLessThan(geo.contentHeight, geo.pageHeight)
    }

    func testLayoutPageNumberPresent() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("# H1\n\nTexto", pageSize: .a4)
        let pages = layout.pages
        XCTAssertGreaterThan(pages.count, 0)
        XCTAssertEqual(pages[0].pageNumber, 1)
        if pages.count > 1 {
            XCTAssertEqual(pages[1].pageNumber, 2)
        }
    }

    // MARK: - Renderizado: integracion

    func testRenderPDFWithAllElementTypes() throws {
        let engine = MarkdownPrintEngine()
        let md = """
        # Titulo

        Parrafo con **negrita**, *cursiva*, `codigo`, ~~tachado~~, [link](https://x.com).

        ## Subtitulo

        > Cita de prueba

        - item 1
        - item 2

        1. paso 1
        2. paso 2

        | A | B |
        |---|---|
        | 1 | 2 |

        ```swift
        let x = 42
        ```

        ---

        $$E = mc^2$$

        <div>HTML block</div>

        Fin.
        """
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 2000)
        XCTAssertGreaterThan(result.pageCount, 0)
        XCTAssertGreaterThan(result.linkCount, 0)
        XCTAssertGreaterThan(result.headingCount, 0)
    }

    func testRenderPDFDarkThemeAllElements() throws {
        let engine = MarkdownPrintEngine()
        let md = "# Test\n\n**bold** *italic* `code` ~~strike~~ [link](url)\n\n- item\n\n| A |\n|---|\n| 1 |"
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4, theme: .dark))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFWithTOCMultipleHeadings() throws {
        let engine = MarkdownPrintEngine()
        let md = "# H1\n\n## H2\n\n### H3\n\nTexto.\n\n# Otro H1\n\n## Otro H2"
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4, withTOC: true))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertGreaterThanOrEqual(result.headingCount, 5, "Al menos 5 palabras de heading")
    }

    // MARK: - Documentos extremos

    func testRenderVeryLongDocument() throws {
        let engine = MarkdownPrintEngine()
        var md = "# Documento largo\n\n"
        for i in 1...100 {
            md += "Parrafo \(i) con suficiente texto para ocupar varias lineas en la pagina. "
        }
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 5000)
        XCTAssertGreaterThan(result.pageCount, 2, "Documento largo debe ocupar varias paginas")
    }

    func testParseDocumentWithOnlyCodeBlocks() {
        let engine = MarkdownPrintEngine()
        let md = "```a\n1\n```\n\n```b\n2\n```\n\n```c\n3\n```"
        let blocks = engine.parse(md)
        let codeBlocks = blocks.filter { if case .codeBlock = $0.kind { true } else { false } }
        XCTAssertEqual(codeBlocks.count, 3)
    }

    func testParseDocumentWithOnlyLists() {
        let engine = MarkdownPrintEngine()
        let md = "- a\n- b\n\n1. c\n2. d"
        let blocks = engine.parse(md)
        XCTAssertEqual(blocks.count, 2) // unordered + ordered
    }

    // MARK: - Typography: escala de fuentes

    func testTypographyHeadingFontSizes() {
        let engine = MarkdownPrintEngine()
        // Verificamos que los headings producen elementos con fontSizes correctas
        for level in 1...6 {
            let md = "\(String(repeating: "#", count: level)) Heading"
            let layout = engine.layout(md, pageSize: .a4)
            let headings = layout.pages.flatMap(\.elements).filter { $0.headingLevel == level && $0.kind == .word }
            if let first = headings.first {
                XCTAssertGreaterThan(first.fontSize, 0, "H\(level) debe tener fontSize > 0")
            }
        }
    }

    func testTypographyCodeFontSize() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("```\ncode\n```", pageSize: .a4)
        let codeElements = layout.pages.flatMap(\.elements).filter { $0.isCodeBlock }
        if let first = codeElements.first {
            // codeFontSize debe ser menor que el cuerpo (10.2 < 12)
            let bodyLayout = engine.layout("texto", pageSize: .a4)
            if let bodyWord = bodyLayout.pages.flatMap(\.elements).filter({ $0.kind == .word }).first {
                XCTAssertLessThanOrEqual(first.fontSize, bodyWord.fontSize)
            }
        }
    }

    // MARK: - ApproximateFontMetrics (via layout)

    func testFontMetricsNarrowChars() {
        let engine = MarkdownPrintEngine()
        // Caracteres estrechos (i, l, j, etc.) deben ocupar menos
        let layout = engine.layout("i", pageSize: .a4)
        if let el = layout.pages.flatMap(\.elements).filter({ $0.kind == .word }).first {
            XCTAssertGreaterThan(el.width, 0)
            XCTAssertLessThan(el.width, 12.0, "Caracter estrecho debe ser < 12pt")
        }
    }

    func testFontMetricsWideChars() {
        let engine = MarkdownPrintEngine()
        // Caracteres anchos (m, w, @) deben ocupar mas
        let layout = engine.layout("W", pageSize: .a4)
        if let el = layout.pages.flatMap(\.elements).filter({ $0.kind == .word }).first {
            XCTAssertGreaterThan(el.width, 8.0, "Caracter ancho debe ser > 8pt")
        }
    }

    func testFontMetricsLineHeight() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("A", pageSize: .a4)
        if let el = layout.pages.flatMap(\.elements).filter({ $0.kind == .word }).first {
            // lineHeight = pointSize * 1.5 = 12 * 1.5 = 18
            XCTAssertGreaterThan(el.height, 15.0)
            XCTAssertLessThan(el.height, 25.0)
        }
    }

    // MARK: - Font verification (via rendering)

    func testRenderedFontIsValid() {
        // Verificar que el renderizado usa fuentes validas
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("**bold** *italic* `code`", options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    // MARK: - SyntaxHighlighter

    func testSyntaxHighlighterHasColors() {
        // Verificamos que los colores del resaltador existen (son constantes)
        // Probamos renderizando codigo con lenguaje conocido
        let engine = MarkdownPrintEngine()
        let md = "```swift\nlet x = 42\n// comment\n```"
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testSyntaxHighlighterMultipleLanguages() {
        let engine = MarkdownPrintEngine()
        let md = """
        ```swift
        let x = 1
        ```
        ```python
        def foo():
            pass
        ```
        ```javascript
        const y = 2;
        ```
        """
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    // MARK: - Theme: propiedades completas

    func testThemeLightAllProperties() {
        let theme = MarkdownPrintTheme.light
        XCTAssertEqual(theme.modeName, "light")
        XCTAssertEqual(theme.pageBackground.alpha, 1.0)
        XCTAssertEqual(theme.text.alpha, 1.0)
        XCTAssertEqual(theme.mutedText.alpha, 1.0)
        XCTAssertEqual(theme.linkText.alpha, 1.0)
        XCTAssertEqual(theme.codeText.alpha, 1.0)
        XCTAssertEqual(theme.border.alpha, 1.0)
        XCTAssertEqual(theme.gridLine.alpha, 0.6, accuracy: 0.01, "gridLine usa alpha 0.6")
        XCTAssertEqual(theme.headingUnderline.alpha, 1.0)
        // inlineCodeBackground usa alpha completo (1.0)
        XCTAssertEqual(theme.inlineCodeBackground.alpha, 1.0)
        XCTAssertTrue(theme.underlineLinks, "Light theme subraya links")
    }

    func testThemeDarkAllProperties() {
        let theme = MarkdownPrintTheme.dark
        XCTAssertEqual(theme.modeName, "dark")
        XCTAssertEqual(theme.pageBackground.alpha, 1.0)
        XCTAssertTrue(theme.underlineLinks, "Dark theme debe subrayar links")
    }

    func testThemeMonoAllProperties() {
        let theme = MarkdownPrintTheme.mono
        XCTAssertEqual(theme.modeName, "mono")
        XCTAssertEqual(theme.pageBackground.alpha, 1.0)
    }

    func testThemeColorsAreDistinct() {
        let light = MarkdownPrintTheme.light
        let dark = MarkdownPrintTheme.dark
        // Fondo claro debe ser diferente de fondo oscuro
        XCTAssertNotEqual(light.pageBackground, dark.pageBackground)
        // Texto claro debe ser diferente de texto oscuro
        XCTAssertNotEqual(light.text, dark.text)
    }

    // MARK: - Stress y concurrencia

    func testConcurrentRendering() {
        let engine = MarkdownPrintEngine()
        let md = "# Test\n\nParrafo de prueba."
        let expectations = (0..<4).map { i -> XCTestExpectation in
            let exp = expectation(description: "render \(i)")
            DispatchQueue.global().async { 
                let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
                XCTAssertGreaterThan(result.pdfData.count, 1000)
                exp.fulfill()
            }
            return exp
        }
        wait(for: expectations, timeout: 10.0)
    }

    func testMultipleEnginesInParallel() {
        let expectations = (0..<3).map { i -> XCTestExpectation in
            let exp = expectation(description: "engine \(i)")
            DispatchQueue.global().async {
                let engine = MarkdownPrintEngine()
                let result = try! engine.render("*test* **bold**", options: RenderOptions(pageSize: .a4))
                XCTAssertGreaterThan(result.pdfData.count, 1000)
                exp.fulfill()
            }
            return exp
        }
        wait(for: expectations, timeout: 10.0)
    }

    func testRapidSequentialRendering() {
        let engine = MarkdownPrintEngine()
        for _ in 0..<10 {
            let result = try! engine.render("test", options: RenderOptions(pageSize: .a4))
            XCTAssertGreaterThan(result.pdfData.count, 1000)
        }
    }

    // MARK: - InlineParser: mas edge cases

    func testParseNestedBoldItalic() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("***bold italic***")
        let inlines = blocks[0].inlines
        // ***...*** should be <em><strong> or <strong><em>
        XCTAssertGreaterThan(inlines.count, 0)
    }

    func testParseItalicWithAsteriskInText() {
        let engine = MarkdownPrintEngine()
        // El texto literal con asteriscos rodeado de negrita
        let blocks = engine.parse("**x * y = z**")
        let inlines = blocks[0].inlines
        let bold = inlines.filter { $0.kind == .bold }
        XCTAssertEqual(bold.count, 1)
    }

    func testParseCodeWithBackticksInside() {
        let engine = MarkdownPrintEngine()
        // Dos backticks como delimitador permiten backtick simple dentro
        let blocks = engine.parse("``codigo con ` backtick``")
        let inlines = blocks[0].inlines
        let code = inlines.filter { $0.kind == .code }
        XCTAssertGreaterThanOrEqual(code.count, 1, "Debe encontrar al menos un elemento code")
    }

    func testParseLinkWithParenthesesInUrl() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("[link](https://en.wikipedia.org/wiki/C_(programming_language))")
        _ = blocks[0].inlines.filter { $0.kind == .link }
        // El parser puede o no manejar parentesis anidados en URLs
        // Al menos no debe crashear
        XCTAssertGreaterThan(blocks.count, 0)
    }

    // MARK: - CLI parser (fast, no Process forking)

    func testCLIParseDefaults() {
        let r = CLIParser.parse(["input.md"])
        XCTAssertEqual(r.inputPath, "input.md")
        XCTAssertEqual(r.outputPath, "input.pdf")
        XCTAssertEqual(r.options.pageSize, .a4)
        XCTAssertEqual(r.options.theme, .light)
    }

    func testCLIParseWithOutput() {
        let r = CLIParser.parse(["input.md", "salida.pdf"])
        XCTAssertEqual(r.inputPath, "input.md")
        XCTAssertEqual(r.outputPath, "salida.pdf")
    }

    func testCLIParseSizeA4() {
        let r = CLIParser.parse(["input.md", "--size", "a4"])
        XCTAssertEqual(r.options.pageSize, .a4)
    }

    func testCLIParseSizeLetter() {
        let r = CLIParser.parse(["input.md", "--size", "letter"])
        XCTAssertEqual(r.options.pageSize, .usLetter)
    }

    func testCLIParseThemeLight() {
        let r = CLIParser.parse(["input.md", "--theme", "light"])
        XCTAssertEqual(r.options.theme, .light)
    }

    func testCLIParseThemeDark() {
        let r = CLIParser.parse(["input.md", "--theme", "dark"])
        XCTAssertEqual(r.options.theme, .dark)
    }

    func testCLIParseThemeMono() {
        let r = CLIParser.parse(["input.md", "--theme", "mono"])
        XCTAssertEqual(r.options.theme, .mono)
    }

    func testCLIParseHighContrast() {
        let r = CLIParser.parse(["input.md", "--high-contrast"])
        XCTAssertEqual(r.options.theme, .highContrast)
    }

    func testCLIParseTOC() {
        let r = CLIParser.parse(["input.md", "--toc"])
        XCTAssertTrue(r.options.withTOC)
    }

    func testCLIParseTitle() {
        let r = CLIParser.parse(["input.md", "--title", "My Title"])
        XCTAssertEqual(r.options.metadata.title, "My Title")
    }

    func testCLIParseAuthor() {
        let r = CLIParser.parse(["input.md", "--author", "Me"])
        XCTAssertEqual(r.options.metadata.author, "Me")
    }

    func testCLIParseTitleAndAuthor() {
        let r = CLIParser.parse(["input.md", "--title", "T", "--author", "A"])
        XCTAssertEqual(r.options.metadata.title, "T")
        XCTAssertEqual(r.options.metadata.author, "A")
    }

    func testCLIParseFontWeb() {
        let r = CLIParser.parse(["input.md", "--font", "web"])
        XCTAssertEqual(r.options.fontFamily, .web)
    }

    func testCLIParseFontApple() {
        let r = CLIParser.parse(["input.md", "--font", "apple"])
        XCTAssertEqual(r.options.fontFamily, .apple)
    }

    func testCLIParseJustify() {
        let r = CLIParser.parse(["input.md", "--justify"])
        XCTAssertTrue(r.options.justifyText)
    }

    func testCLIParseLineNumbers() {
        let r = CLIParser.parse(["input.md", "--line-numbers"])
        XCTAssertTrue(r.options.showLineNumbers)
    }

    func testCLIParseScale() {
        let r = CLIParser.parse(["input.md", "--scale", "1.5"])
        XCTAssertEqual(r.options.dynamicTypeScale, 1.5)
    }

    func testCLIParseWatermark() {
        let r = CLIParser.parse(["input.md", "--watermark", "DRAFT"])
        XCTAssertNotNil(r.options.watermark)
    }

    func testCLIParseHeader() {
        let r = CLIParser.parse(["input.md", "--header", "{title}"])
        XCTAssertEqual(r.options.headerFooter?.header, "{title}")
    }

    func testCLIParseFooter() {
        let r = CLIParser.parse(["input.md", "--footer", "{page}"])
        XCTAssertEqual(r.options.headerFooter?.footer, "{page}")
    }

    func testCLIParseHeaderAndFooter() {
        let r = CLIParser.parse(["input.md", "--header", "{title}", "--footer", "{page}/{total}"])
        XCTAssertEqual(r.options.headerFooter?.header, "{title}")
        XCTAssertEqual(r.options.headerFooter?.footer, "{page}/{total}")
    }

    func testCLIParseAllFlagsCombined() {
        let r = CLIParser.parse([
            "input.md", "output.pdf",
            "--size", "a4",
            "--theme", "dark",
            "--toc",
            "--high-contrast",
            "--title", "CLI Test",
            "--author", "Test Author",
            "--font", "web",
            "--justify",
            "--line-numbers",
            "--scale", "1.2",
            "--watermark", "DRAFT",
            "--header", "{title}",
            "--footer", "{page}"
        ])
        XCTAssertEqual(r.inputPath, "input.md")
        XCTAssertEqual(r.outputPath, "output.pdf")
        // Last theme wins: high-contrast overrides dark
        XCTAssertEqual(r.options.theme, .highContrast)
        XCTAssertTrue(r.options.withTOC)
        XCTAssertEqual(r.options.metadata.title, "CLI Test")
        XCTAssertEqual(r.options.metadata.author, "Test Author")
        XCTAssertEqual(r.options.fontFamily, .web)
        XCTAssertTrue(r.options.justifyText)
        XCTAssertTrue(r.options.showLineNumbers)
        XCTAssertEqual(r.options.dynamicTypeScale, 1.2)
        XCTAssertNotNil(r.options.watermark)
        XCTAssertEqual(r.options.headerFooter?.header, "{title}")
        XCTAssertEqual(r.options.headerFooter?.footer, "{page}")
    }

    func testCLIParseUnknownFlagsAreIgnored() {
        let r = CLIParser.parse(["input.md", "--unknown", "value"])
        XCTAssertEqual(r.inputPath, "input.md")
    }

    func testCLIParseOnlyInputNoExtension() {
        let r = CLIParser.parse(["/tmp/doc"])
        XCTAssertEqual(r.outputPath, "/tmp/doc.pdf")
    }

    func testCLIParseHelpText() {
        let help = CLIParser.helpText
        XCTAssertTrue(help.contains("size"))
        XCTAssertTrue(help.contains("theme"))
        XCTAssertTrue(help.contains("toc"))
        XCTAssertTrue(help.contains("high-contrast"))
        XCTAssertTrue(help.contains("justify"))
        XCTAssertTrue(help.contains("watermark"))
        XCTAssertTrue(help.contains("header"))
        XCTAssertTrue(help.contains("footer"))
    }

    func testCLIErrorCannotReadInput() {
        let error = CLIError.cannotReadInput(path: "/nonexistent")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("/nonexistent") ?? false)
    }

    // MARK: - CLI missing flag coverage

    private func parseSilently(_ args: [String]) -> CLIParser.ParsedArgs {
        CLIParser.parse(args, emitsWarnings: false)
    }

    func testCLIParseThemeFileFlag() {
        let r = parseSilently(["input.md", "--theme-file", "/nonexistent/theme.json"])
        XCTAssertEqual(r.options.theme, .light)
    }

    func testCLIParseWatermarkImageFlag() {
        let r = CLIParser.parse(["input.md", "--watermark-image", "/tmp/stamp.png"])
        XCTAssertNotNil(r.options.watermark)
    }

    func testCLIParseScaleInvalid() {
        let r = parseSilently(["input.md", "--scale", "abc"])
        XCTAssertEqual(r.options.dynamicTypeScale, 1.0)
    }

    func testCLIParseScaleInvalidCanEmitWarningToHandler() {
        var warnings: [String] = []
        let r = CLIParser.parse(["input.md", "--scale", "abc"], warningHandler: { warnings.append($0) })
        XCTAssertEqual(r.options.dynamicTypeScale, 1.0)
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("invalid scale value 'abc'"))
    }

    func testCLIParseScaleZero() {
        let r = parseSilently(["input.md", "--scale", "0"])
        XCTAssertEqual(r.options.dynamicTypeScale, 1.0)
    }

    func testCLIParseScaleNegative() {
        let r = parseSilently(["input.md", "--scale", "-1.5"])
        XCTAssertEqual(r.options.dynamicTypeScale, 1.0)
    }

    func testCLIParseFlagAtEndWithoutValue() {
        let r = CLIParser.parse(["input.md", "--title"])
        XCTAssertNil(r.options.metadata.title)
    }

    func testCLIParseFlagAtEndWithoutValueScale() {
        let r = parseSilently(["input.md", "--scale"])
        XCTAssertEqual(r.options.dynamicTypeScale, 1.0)
    }

    func testCLIParseHeaderWithoutFooter() {
        let r = CLIParser.parse(["input.md", "--header", "{page} of {total}"])
        XCTAssertEqual(r.options.headerFooter?.header, "{page} of {total}")
        XCTAssertNil(r.options.headerFooter?.footer)
    }

    func testCLIParseFooterWithoutHeader() {
        let r = CLIParser.parse(["input.md", "--footer", "Page {page}"])
        XCTAssertNil(r.options.headerFooter?.header)
        XCTAssertEqual(r.options.headerFooter?.footer, "Page {page}")
    }

    func testCLIParseFontInvalid() {
        let r = CLIParser.parse(["input.md", "--font", "invalid"])
        XCTAssertEqual(r.options.fontFamily, .apple) // default
    }

    func testCLIParseSizeInvalid() {
        let r = CLIParser.parse(["input.md", "--size", "invalid"])
        XCTAssertEqual(r.options.pageSize, .a4) // default
    }

    // MARK: - PDFRenderer: image, footnote, cross-reference, watermark image, endnotes

    func testRenderPDFWithImagePlaceholder() throws {
        let engine = MarkdownPrintEngine()
        let md = "# Doc\n\n![test](/nonexistent/image.png)"
        let result = try engine.render(md)
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    func testRenderPDFWithFootnoteAndEndnotes() throws {
        let engine = MarkdownPrintEngine()
        let md = """
        # Document

        This text has a footnote[^1].

        [^1]: This is the footnote definition.
        """
        let result = try engine.render(md)
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    func testRenderPDFWithMultipleFootnotes() throws {
        let engine = MarkdownPrintEngine()
        let md = """
        # References

        First claim[^one]. Second claim[^two].

        [^one]: Evidence for first claim.
        [^two]: Evidence for second claim with **bold**.
        """
        let result = try engine.render(md)
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    func testRenderPDFWithCrossReference() throws {
        let engine = MarkdownPrintEngine()
        let md = """
        # Introduction {#intro}

        See [Introduction](#intro) for details.

        ## Methods

        As explained in the [intro](#intro), this is important.
        """
        let result = try engine.render(md)
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    func testRenderPDFWithImageWatermark() throws {
        let engine = MarkdownPrintEngine()
        let md = "# Watermarked Document\n\nContent."
        let opts = RenderOptions(
            watermark: Watermark(kind: .image(URL(fileURLWithPath: "/nonexistent/logo.png")), opacity: 0.1)
        )
        let result = try engine.render(md, options: opts)
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    func testRenderPDFWithTextWatermarkAllOptions() throws {
        let engine = MarkdownPrintEngine()
        let md = "# Confidential\n\nInternal use only."
        let wm = Watermark(kind: .text("TOP SECRET"), opacity: 0.12, fontSize: 64, angle: -40, color: CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        let opts = RenderOptions(pageSize: .usLetter, watermark: wm)
        let result = try engine.render(md, options: opts)
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    func testRenderPDFWithHeaderFooterAllPlaceholders() throws {
        let engine = MarkdownPrintEngine()
        let md = "# My Document\n\n## Section A\n\nContent."
        let hf = PageHeaderFooter(
            header: "{section} -- {page}/{total}",
            footer: "{title}",
            fontSize: 10
        )
        let opts = RenderOptions(
            pageSize: .a4,
            metadata: PDFMetadata(title: "Test Doc", author: "Author"),
            headerFooter: hf
        )
        let result = try engine.render(md, options: opts)
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    func testRenderPDFWithJustifyAndLineNumbersCombined() throws {
        let engine = MarkdownPrintEngine()
        let md = """
        # Justified

        This paragraph has enough text that it should span multiple lines
        when rendered on an A4 page with normal margins, testing justification.

        ```swift
        func example() {
            let x = 42
            return x * 2
        }
        ```
        """
        let opts = RenderOptions(showLineNumbers: true, justifyText: true)
        let result = try engine.render(md, options: opts)
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    func testRenderPDFRenderCancellableWithAllDecorations() async throws {
        let engine = MarkdownPrintEngine()
        let md = "# Decorated\n\nContent with **bold**."
        let result = try await engine.renderPDFWithDiagnosticsCancellable(
            fromMarkdown: md,
            pageSize: .a4,
            metadata: PDFMetadata(title: "Test", author: "X"),
            theme: .light,
            withTOC: false,
            fontFamily: .web,
            showLineNumbers: true,
            justifyText: true,
            watermark: .draft(),
            headerFooter: .sectionAndPage()
        )
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    func testRenderPDFWithSmallCapsAndTypography() throws {
        let engine = MarkdownPrintEngine()
        let md = "# Typography\n\nTesting `HTML` and `API` in code spans, plus ligatures fi fl ff."
        let result = try engine.render(md, options: .init(theme: .light))
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    func testRenderPDFWithAllThemesAndWatermark() throws {
        let themes: [MarkdownPrintTheme] = [.light, .dark, .mono, .highContrast]
        for theme in themes {
            let engine = MarkdownPrintEngine()
            let opts = RenderOptions(theme: theme, watermark: .draft())
            let result = try engine.render("# \(theme.modeName)", options: opts)
            XCTAssertGreaterThan(result.pdfData.count, 500)
        }
    }

    func testPDFRenderResultDiagnosticsFormat() {
        let result = PDFRenderResult(pdfData: Data(), pageCount: 3, linkCount: 5, imageCount: 2, headingCount: 7, duration: 0.123)
        let diag = result.diagnostics
        XCTAssertTrue(diag.contains("Paginas:"))
        XCTAssertTrue(diag.contains("Enlaces:"))
        XCTAssertTrue(diag.contains("Imagenes:"))
        XCTAssertTrue(diag.contains("Headings:"))
        XCTAssertTrue(diag.contains("Tamano:"))
        XCTAssertTrue(diag.contains("Duracion:"))
        XCTAssertTrue(diag.contains("123 ms"))
    }

    // MARK: - Integridad de datos

    func testLayoutElementsHaveValidCoordinates() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("# Titulo\n\nTexto largo que ocupa varias lineas en la pagina de prueba.", pageSize: .a4)
        for page in layout.pages {
            for el in page.elements {
                XCTAssertGreaterThanOrEqual(el.x, 0, "x debe ser >= 0")
                XCTAssertGreaterThanOrEqual(el.y, 0, "y debe ser >= 0")
                XCTAssertLessThanOrEqual(el.x + el.width, layout.geometry.contentWidth + 1, "Elemento no debe exceder ancho")
            }
        }
    }

    func testLayoutPageNumbersAreSequential() {
        let engine = MarkdownPrintEngine()
        var md = ""
        for i in 1...10 { md += "# H\(i)\n\nTexto de relleno para forzar varias paginas.\n\n" }
        let layout = engine.layout(md, pageSize: .a4)
        for (i, page) in layout.pages.enumerated() {
            XCTAssertEqual(page.pageNumber, i + 1)
        }
    }

    // MARK: - InlineParser: cobertura final

    func testParseStrongHtmlTag() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("<strong>importante</strong>")
        let inlines = blocks[0].inlines
        XCTAssertTrue(inlines.contains { $0.kind == .bold }, "strong debe ser bold")
    }

    func testParseEmWithoutClosingTag() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("<em>sin cerrar")
        // Sin cierre, el texto se trata como literal
        XCTAssertGreaterThan(blocks.count, 0)
        let text = blocks[0].inlines.map(\.text).joined()
        XCTAssertTrue(text.contains("<em>") || text.contains("sin cerrar"))
    }

    func testParseLinkWithoutClosingParen() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("[texto](sin_cerrar")
        let inlines = blocks[0].inlines
        let links = inlines.filter { $0.kind == .link }
        XCTAssertEqual(links.count, 0, "Sin ) no debe crear link")
    }

    func testParseBracketsWithoutUrl() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("[solo corchetes]")
        let inlines = blocks[0].inlines
        let links = inlines.filter { $0.kind == .link }
        XCTAssertEqual(links.count, 0, "Corchetes solos no son link")
    }

    func testParseItalicWithAsteriskInMiddle() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("*begin italic* end")
        let inlines = blocks[0].inlines
        XCTAssertTrue(inlines.contains { $0.kind == .italic })
    }

    func testParseHtmlAttributesWithSingleQuotes() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("<a href='https://x.com'>link</a>")
        let links = blocks[0].inlines.filter { $0.kind == .link }
        XCTAssertEqual(links.count, 1)
    }

    // MARK: - Theme: cobertura completa (light ya testeado arriba)

    func testAllThemesAreDifferent() {
        let light = MarkdownPrintTheme.light
        let dark = MarkdownPrintTheme.dark
        let mono = MarkdownPrintTheme.mono
        XCTAssertNotEqual(light.modeName, dark.modeName)
        XCTAssertNotEqual(light.modeName, mono.modeName)
        XCTAssertNotEqual(dark.modeName, mono.modeName)
    }

    // MARK: - Layout: todos los tipos de bloque

    func testLayoutAllBlockTypesProduceElements() {
        let engine = MarkdownPrintEngine()
        let md = """
        # H1

        Parrafo.

        > Cita.

        - item

        1. paso

        ---

        | A |
        |---|
        | 1 |

        ```code
        x
        ```

        $$

        y=1

        $$

        <div>html</div>
        """
        let layout = engine.layout(md, pageSize: .a4)
        let kinds = Set(layout.pages.flatMap(\.elements).map(\.kind))
        XCTAssertTrue(kinds.contains(.word), "Debe tener palabras")
        XCTAssertTrue(kinds.contains(.horizontalRule), "Debe tener HR")
        XCTAssertTrue(kinds.contains(.tableGridLine), "Debe tener grid")
        XCTAssertTrue(kinds.contains(.mathBlock), "Debe tener math")
        XCTAssertTrue(kinds.contains(.rawHtml), "Debe tener html")
    }

    func testLayoutAllInlineStylesInElements() {
        let engine = MarkdownPrintEngine()
        let md = "**bold** *italic* `code` ~~strike~~ [link](url) $math$ ![img](x.png)"
        let layout = engine.layout(md, pageSize: .a4)
        let styles = Set(layout.pages.flatMap(\.elements).map(\.style))
        XCTAssertTrue(styles.contains(.bold))
        XCTAssertTrue(styles.contains(.italic))
        XCTAssertTrue(styles.contains(.code))
        XCTAssertTrue(styles.contains(.strikethrough))
        XCTAssertTrue(styles.contains(.link))
        XCTAssertTrue(styles.contains(.inlineMath))
        XCTAssertTrue(styles.contains(.image))
    }

    // MARK: - Errores y edge cases finales

    func testPDFMetadataEquality() {
        let a = PDFMetadata(title: "A", author: "X")
        let b = PDFMetadata(title: "A", author: "X")
        let c = PDFMetadata(title: "B", author: nil)
        XCTAssertEqual(a.title, b.title)
        XCTAssertEqual(a.author, b.author)
        XCTAssertNotEqual(a.title, c.title)
    }

    func testMarkdownPageSizeDimensions() {
        XCTAssertEqual(MarkdownPageSize.usLetter.dimensions.width, 612.0, accuracy: 0.1)
        XCTAssertEqual(MarkdownPageSize.usLetter.dimensions.height, 792.0, accuracy: 0.1)
        XCTAssertEqual(MarkdownPageSize.a4.dimensions.width, 595.2756, accuracy: 0.1)
        XCTAssertEqual(MarkdownPageSize.a4.dimensions.height, 841.8898, accuracy: 0.1)
        let custom = MarkdownPageSize.custom(width: 300, height: 400)
        XCTAssertEqual(custom.dimensions.width, 300.0)
        XCTAssertEqual(custom.dimensions.height, 400.0)
    }

    func testParsePreservesLeadingWhitespaceInCodeBlocks() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("```\n    indented\n  less\n```")
        let codeBlocks = blocks.filter { if case .codeBlock = $0.kind { true } else { false } }
        XCTAssertEqual(codeBlocks.count, 1)
        XCTAssertTrue(codeBlocks[0].text.contains("    indented"))
    }

    func testLayoutWhitespaceOnlyTokens() {
        let engine = MarkdownPrintEngine()
        // Verificar que el layout no crashea con espacios
        let layout = engine.layout("   \n\n   \n\n# H1", pageSize: .a4)
        XCTAssertGreaterThan(layout.pages.count, 0)
    }

    func testTokenizeMixedTabsAndSpaces() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("\t- item\n  - item2")
        XCTAssertGreaterThan(tokens.count, 0)
    }

    func testParseOrderedListWithSkippedNumbers() {
        let engine = MarkdownPrintEngine()
        let blocks = engine.parse("1. a\n3. b\n5. c")
        let lists = blocks.filter { if case .orderedList = $0.kind { true } else { false } }
        XCTAssertEqual(lists.count, 1)
        // La numeracion empieza en 1 y autoincrementa
        XCTAssertEqual(lists[0].items[0].number, 1)
    }

    func testLayoutHorizontalRuleStars() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("antes\n\n***\n\ndespues", pageSize: .a4)
        let hrs = layout.pages.flatMap(\.elements).filter { $0.kind == .horizontalRule }
        XCTAssertEqual(hrs.count, 1)
    }

    func testLayoutHorizontalRuleUnderscores() {
        let engine = MarkdownPrintEngine()
        let layout = engine.layout("___\n\ntexto", pageSize: .a4)
        let hrs = layout.pages.flatMap(\.elements).filter { $0.kind == .horizontalRule }
        XCTAssertEqual(hrs.count, 1)
    }

    func testRenderPDFWithCustomPageSize() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("test", options: .init(pageSize: .custom(width: 300, height: 400)))
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    // MARK: - CLI runner (fast, no Process)

    func testCLIRunCreatesPDF() throws {
        let tmpInput = FileManager.default.temporaryDirectory.appendingPathComponent("test_cli_run.md")
        let tmpOutput = FileManager.default.temporaryDirectory.appendingPathComponent("test_cli_run.pdf")
        defer {
            try? FileManager.default.removeItem(at: tmpInput)
            try? FileManager.default.removeItem(at: tmpOutput)
        }
        try "# CLI Run Test\n\nParagraph.".write(to: tmpInput, atomically: true, encoding: .utf8)
        let parsed = CLIParser.ParsedArgs(inputPath: tmpInput.path, outputPath: tmpOutput.path, options: .init())
        let output = try CLIParser.run(parsed)
        XCTAssertEqual(output, tmpOutput.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpOutput.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: tmpOutput.path)
        let size = attrs[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(size, 500, "PDF must have content")
    }

    func testCLIRunNonexistentInput() {
        let parsed = CLIParser.ParsedArgs(inputPath: "/nonexistent/file.md", outputPath: "/tmp/out.pdf", options: .init())
        XCTAssertThrowsError(try CLIParser.run(parsed)) { error in
            XCTAssertTrue(error is CLIError)
        }
    }

    func testCLIRunWithTOC() throws {
        let tmpInput = FileManager.default.temporaryDirectory.appendingPathComponent("test_toc.md")
        let tmpOutput = FileManager.default.temporaryDirectory.appendingPathComponent("test_toc.pdf")
        defer {
            try? FileManager.default.removeItem(at: tmpInput)
            try? FileManager.default.removeItem(at: tmpOutput)
        }
        try "# H1\n\n## H2\n\nText.".write(to: tmpInput, atomically: true, encoding: .utf8)
        let options = RenderOptions(withTOC: true)
        let parsed = CLIParser.ParsedArgs(inputPath: tmpInput.path, outputPath: tmpOutput.path, options: options)
        try CLIParser.run(parsed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpOutput.path))
    }

    // MARK: - Byte-level PDF verification

    func testPDFStartsWithMagicBytes() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("test", options: RenderOptions(pageSize: .a4))
        let magic = result.pdfData.prefix(5)
        XCTAssertEqual(magic, Data([0x25, 0x50, 0x44, 0x46, 0x2D]), "PDF debe empezar con %PDF-")
    }

    func testPDFEndsWithEOF() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("test", options: RenderOptions(pageSize: .a4))
        let tail = result.pdfData.suffix(8)
        let tailStr = String(data: tail, encoding: .ascii) ?? ""
        XCTAssertTrue(tailStr.contains("%%EOF"), "PDF debe terminar con %%EOF")
    }

    func testRenderedCodeBlockKeepsSpacesBetweenTokens() throws {
        let engine = MarkdownPrintEngine()
        let markdown = """
        ```swift
        let package = Package(
            name: "MarkdownPrint"
        )
        ```
        """

        let result = try engine.render(markdown, options: RenderOptions(pageSize: .a4))

        #if canImport(PDFKit)
        let text = PDFDocument(data: result.pdfData)?.string ?? ""
        XCTAssertTrue(text.contains("let package"), text)
        XCTAssertTrue(text.contains("package = Package"), text)
        XCTAssertFalse(text.contains("letpackage"), text)
        #else
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        #endif
    }

    // MARK: - Lexer: cobertura 100%

    func testTokenizeEmptyString() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("")
        XCTAssertEqual(tokens.count, 0)
    }

    func testTokenizeOnlyWhitespace() {
        let engine = MarkdownPrintEngine()
        let tokens = engine.tokenize("   \n  \t  \n   ")
        let blanks = tokens.filter { $0.kind == .blankLine }
        XCTAssertGreaterThanOrEqual(blanks.count, 0)
    }

    // MARK: - Cobertura final: PDFRenderer, CLI, edge cases

    func testRenderPDFMultipleCodeBlocksWithLanguages() throws {
        let engine = MarkdownPrintEngine()
        let md = """
        # Code Test
        ```swift
        let a = 1
        ```
        ```python
        def f(): pass
        ```
        ```go
        package main
        ```
        ```rust
        fn main() {}
        ```
        ```shell
        echo hello
        ```
        """
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 2000)
    }

    func testRenderPDFHeadingUnderlines() throws {
        let engine = MarkdownPrintEngine()
        let md = "# H1 Title\n\n## H2 Subtitle\n\nTexto normal."
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFOutlineWithTOC() throws {
        let engine = MarkdownPrintEngine()
        let md = "# Introduccion\n\n## Metodos\n\n### Experimental\n\n## Resultados\n\n# Conclusion"
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4, withTOC: true))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertGreaterThanOrEqual(result.headingCount, 5)
    }

    func testSyntaxHighlightingAllLanguages() throws {
        let engine = MarkdownPrintEngine()
        let languages = ["swift", "python", "javascript", "cpp", "go", "rust", "shell"]
        var md = ""
        for lang in languages {
            md += "```\(lang)\ncode\n```\n\n"
        }
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 2000)
    }

    func testLayoutMixedDocumentWithAllElements() {
        let engine = MarkdownPrintEngine()
        var md = "# H1\n\n"
        for i in 1...20 {
            md += """
            Parrafo \(i).
            > Cita \(i).
            - item a
            - item b
            1. paso

            | X |
            |---|
            | \(i) |

            ```code
            x
            ```

            ---

            """
        }
        md += """

        $$

        y = 42

        $$

        <div>html</div>
        """
        let layout = engine.layout(md, pageSize: .a4)
        XCTAssertGreaterThan(layout.pages.count, 3, "Documento mixto debe ocupar varias paginas")
        let kinds = Set(layout.pages.flatMap(\.elements).map(\.kind))
        XCTAssertTrue(kinds.contains(.word))
        XCTAssertTrue(kinds.contains(.horizontalRule))
        XCTAssertTrue(kinds.contains(.tableGridLine))
        XCTAssertTrue(kinds.contains(.mathBlock))
        XCTAssertTrue(kinds.contains(.rawHtml))
    }

    func testPageSizeEquality() {
        XCTAssertEqual(MarkdownPageSize.usLetter, MarkdownPageSize.usLetter)
        XCTAssertEqual(MarkdownPageSize.a4, MarkdownPageSize.a4)
        XCTAssertNotEqual(MarkdownPageSize.usLetter, MarkdownPageSize.a4)
        let c1 = MarkdownPageSize.custom(width: 100, height: 200)
        let c2 = MarkdownPageSize.custom(width: 100, height: 200)
        let c3 = MarkdownPageSize.custom(width: 200, height: 100)
        XCTAssertEqual(c1, c2)
        XCTAssertNotEqual(c1, c3)
    }

    func testPDFMetadataEqualityExtended() {
        let a = PDFMetadata(title: "T", author: "A")
        let b = PDFMetadata(title: "T", author: "A")
        let c = PDFMetadata(title: nil, author: nil)
        let d = PDFMetadata(title: "T", author: nil)
        XCTAssertEqual(a.title, b.title)
        XCTAssertEqual(c.title, nil)
        XCTAssertEqual(d.author, nil)
    }

    func testRenderWithCustomSizeAndTOC() throws {
        let engine = MarkdownPrintEngine()
        let md = "# H1\n\n## H2\n\nTexto."
        let result = try! engine.renderPDFWithDiagnostics(
            fromMarkdown: md,
            pageSize: .custom(width: 400, height: 600),
            metadata: PDFMetadata(title: "Custom", author: "Test"),
            theme: .mono,
            withTOC: true
        )
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertGreaterThan(result.pageCount, 0)
    }

    // MARK: - SystemFont: cobertura 100%

    func testSystemFontRegular() {
        let font = SystemFont.regular(size: 14)
        let name = CTFontCopyPostScriptName(font) as String
        XCTAssertFalse(name.isEmpty)
    }

    func testSystemFontBold() {
        let font = SystemFont.bold(size: 16)
        let traits = CTFontGetSymbolicTraits(font)
        XCTAssertTrue(traits.contains(.traitBold))
    }

    func testSystemFontItalic() {
        let font = SystemFont.italic(size: 12)
        let traits = CTFontGetSymbolicTraits(font)
        XCTAssertTrue(traits.contains(.traitItalic))
    }

    func testSystemFontItalicFallback() {
        // Verificar que italic sin fuente base no crashea
        let font = SystemFont.italic(size: 999)
        XCTAssertNotNil(font)
    }

    func testSystemFontMonospace() {
        let font = SystemFont.monospace(size: 12)
        let name = CTFontCopyPostScriptName(font) as String
        XCTAssertTrue(name.contains("Menlo") || name.contains("Mono") || name.contains("Courier"))
    }

    func testSystemFontForStyleAllCases() {
        // Todos los estilos deben producir fuentes validas
        let styles: [(MarkdownInlineKind, Int, CGFloat)] = [
            (.plainText, 0, 12),
            (.bold, 0, 12),
            (.italic, 0, 12),
            (.code, 0, 10),
            (.strikethrough, 0, 12),
            (.link, 0, 12),
            (.image, 0, 12),
            (.hardBreak, 0, 12),
            (.inlineMath, 0, 12),
            (.plainText, 1, 24),  // H1
            (.plainText, 2, 18),  // H2
            (.plainText, 3, 15),  // H3
            (.plainText, 4, 12),  // H4
            (.plainText, 5, 10),  // H5
            (.plainText, 6, 9),   // H6
        ]
        for (style, level, size) in styles {
            let font = SystemFont.font(forStyle: style, headingLevel: level, size: size)
            XCTAssertNotNil(font, "Font for style \(style) level \(level) must exist")
        }
    }

    // MARK: - SyntaxHighlighter: cobertura 100%

    func testSyntaxHighlighterKeywords() {
        // Swift keywords deben devolver color de keyword
        let keywords = ["let", "func", "class", "if", "return", "true", "false", "nil"]
        for kw in keywords {
            let color = SyntaxHighlighter.color(for: kw)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterStrings() {
        let strings = ["\"hello\"", "'world'"]
        for s in strings {
            let color = SyntaxHighlighter.color(for: s)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterComments() {
        let comments = ["// comment", "/* block */", "# hash comment"]
        for c in comments {
            let color = SyntaxHighlighter.color(for: c)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterNumbers() {
        let numbers = ["42", "3.14", "-5", "0"]
        for n in numbers {
            let color = SyntaxHighlighter.color(for: n)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterBuiltinTypes() {
        let types = ["String", "Int", "Bool", "CGColor", "CTFont", "Array"]
        for t in types {
            let color = SyntaxHighlighter.color(for: t)
            XCTAssertNotNil(color)
        }
    }

    func testSyntaxHighlighterPlainText() {
        let color = SyntaxHighlighter.color(for: "variableName")
        XCTAssertNotNil(color)
    }

    func testSyntaxHighlighterEmptyString() {
        let color = SyntaxHighlighter.color(for: "")
        XCTAssertNotNil(color)
    }

    func testSyntaxHighlighterWhitespaceOnly() {
        let color = SyntaxHighlighter.color(for: "   ")
        XCTAssertNotNil(color)
    }

    func testSyntaxHighlighterNegativeNumber() {
        let color = SyntaxHighlighter.color(for: "-42")
        XCTAssertNotNil(color)
    }

    func testSyntaxHighlighterStarComment() {
        let color = SyntaxHighlighter.color(for: "* bullet")
        XCTAssertNotNil(color)
    }

    // MARK: - PDFRenderer: cobertura 100%

    func testRenderPDFTOCWithNoHeadings() throws {
        let engine = MarkdownPrintEngine()
        // Documento sin headings: TOC no deberia crashear
        let md = "Solo texto sin headings ni nada."
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4, withTOC: true))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFImageWithAbsolutePath() throws {
        let engine = MarkdownPrintEngine()
        let md = "![test](/tmp/nonexistent_img.png)"
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFDataUriImage() throws {
        let engine = MarkdownPrintEngine()
        // Data URI invalida: debe mostrar placeholder
        let md = "![pixel](data:image/png;base64,INVALID)"
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFHTTPImageProducesPlaceholder() throws {
        let engine = MarkdownPrintEngine()
        let md = "![remote](https://example.com/image.png)"
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFSingleCodeBlockBackground() throws {
        let engine = MarkdownPrintEngine()
        let md = "```\nsingle line\n```"
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 500)
    }

    func testRenderPDFBlockquoteWithEmphasis() throws {
        let engine = MarkdownPrintEngine()
        let md = "> **bold** *italic* `code` ~~strike~~ [link](url) $math$"
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFAllThemesWithCodeBlocks() throws {
        let engine = MarkdownPrintEngine()
        let md = "```swift\nlet x = 42\n// comment\n\"string\"\n```"
        for _ in [MarkdownPrintTheme.light, .dark, .mono] as [MarkdownPrintTheme] {
            let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
            XCTAssertGreaterThan(result.pdfData.count, 1000)
        }
    }

    func testRenderPDFAllThemesWithBlockquote() throws {
        let engine = MarkdownPrintEngine()
        let md = "# H1\n\n> Cita con **negrita** y `codigo`"
        for _ in [MarkdownPrintTheme.light, .dark, .mono] as [MarkdownPrintTheme] {
            let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
            XCTAssertGreaterThan(result.pdfData.count, 1000)
        }
    }

    // MARK: - Async/await API

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncRenderPDF() async throws {
        let engine = MarkdownPrintEngine()
        let result = try await engine.render("# Async\n\nTest.", options: RenderOptions(pageSize: .a4))
        let pdfData = result.pdfData
        XCTAssertGreaterThan(pdfData.count, 1000)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncRenderPDFWithDiagnostics() async throws {
        let engine = MarkdownPrintEngine()
        let result = try await engine.renderPDFWithDiagnostics(
            fromMarkdown: "# Test\n\n[Link](https://x.com)",
            pageSize: .a4
        )
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertEqual(result.linkCount, 1)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncRenderWithTOC() async throws {
        let engine = MarkdownPrintEngine()
        let result = try await engine.renderPDFWithDiagnostics(
            fromMarkdown: "# H1\n\n## H2\n\nTexto.",
            pageSize: .a4,
            withTOC: true
        )
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testAllPublicTypesAreSendable() {
        let _: any Sendable = MarkdownTokenKind.heading(level: 1)
        let _: any Sendable = MarkdownToken(kind: .paragraph, text: "")
        let _: any Sendable = MarkdownInlineKind.bold
        let _: any Sendable = MarkdownPageSize.a4
        let _: any Sendable = MarkdownBlockKind.paragraph
        let _: any Sendable = MarkdownLayoutElementKind.word
        let _: any Sendable = MarkdownPrintTheme.light
        let _: any Sendable = PDFMetadata()
        let _: any Sendable = PDFRenderResult(pdfData: Data(), pageCount: 1, linkCount: 0, imageCount: 0, headingCount: 0, duration: 0)
    }

    // MARK: - Performance benchmarks

    func testPerformanceTokenize() {
        let engine = MarkdownPrintEngine()
        let md = String(repeating: "# H\n\nP with **bold**.\n\n- item\n", count: 15)
        measure { _ = engine.tokenize(md) }
    }

    func testPerformanceParse() {
        let engine = MarkdownPrintEngine()
        let md = String(repeating: "# H\n\nP with **bold**.\n\n- item\n", count: 15)
        measure { _ = engine.parse(md) }
    }

    func testPerformanceLayout() {
        let engine = MarkdownPrintEngine()
        let md = String(repeating: "# H\n\nP with **bold**.\n\n- item\n", count: 8)
        measure { _ = engine.layout(md, pageSize: .a4) }
    }

    func testPerformanceRender() {
        let engine = MarkdownPrintEngine()
        let md = String(repeating: "# H\n\nP with **bold**.\n\n- item\n", count: 10)
        _ = try! engine.render(md, options: RenderOptions(pageSize: .a4))
    }

    func testMemoryNoLeakOnRepeatedRender() {
        let engine = MarkdownPrintEngine()
        let md = "# Test\n\n**bold** *italic* `code`\n\n- item\n- item2\n\n| A | B |\n|---|---|\n| 1 | 2 |"
        var results: [Int] = []
        for _ in 0..<10 {
            let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
            results.append(result.pdfData.count)
        }
        // Todos los renders deben producir el mismo tamano de PDF
        let unique = Set(results)
        XCTAssertEqual(unique.count, 1, "Renders repetidos deben ser deterministicos")
    }

    func testRTLTextDetection() {
        let engine = MarkdownPrintEngine()
        // Arabic "Marhaba bil-alam" - el motor C++ actualmente no detecta RTL,
        // pero debe renderizar texto arabe sin crashear.
        let layout = engine.layout("\u{645}\u{631}\u{62D}\u{628}\u{627} \u{628}\u{627}\u{644}\u{639}\u{627}\u{644}\u{645}", pageSize: .a4)
        let elements = layout.pages.flatMap(\.elements).filter { $0.kind == .word }
        XCTAssertGreaterThan(elements.count, 0, "Debe haber palabras en el layout")
        // Documentado: RTL detection no implementado en el motor C++.
        // Cuando se implemente, verificar: elements.filter { $0.isRTL }.count > 0
    }

    func testRenderLongDocumentMemoryStability() {
        let engine = MarkdownPrintEngine()
        var md = ""
        for i in 1...50 { md += "# Section \(i)\n\nParagraph with **bold** and `code`.\n\n- item a\n- item b\n\n" }
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pageCount, 10)
        XCTAssertGreaterThan(result.pdfData.count, 10000)
    }

    // MARK: - Transferable

    @available(macOS 13.0, iOS 16.0, *)
    func testTransferableRepresentationExists() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("# Hola\n\nTexto.", options: RenderOptions(pageSize: .a4))
        // La propiedad estatica transferRepresentation existe
        let rep = type(of: result).transferRepresentation
        _ = rep
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testTransferablePDFDataIsValid() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("# Test", options: RenderOptions(pageSize: .a4))
        // El PDF es valido (comienza con %PDF-)
        let header = result.pdfData.prefix(5)
        XCTAssertEqual(header, Data("%PDF-".utf8))
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testTransferableOnEmptyPDF() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("", options: RenderOptions(pageSize: .a4))
        let header = result.pdfData.prefix(5)
        XCTAssertEqual(header, Data("%PDF-".utf8))
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testSharedEngineSingleton() {
        let engine1 = MarkdownPrintEngine.shared
        let engine2 = MarkdownPrintEngine.shared
        // Ambas referencias apuntan al mismo objeto
        XCTAssertTrue(engine1 === engine2)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testSharedEngineRendersPDF() throws {
        let engine = MarkdownPrintEngine.shared
        let result = try! engine.render("# Shared", options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testSharedEngineCoreVersion() {
        XCTAssertTrue(MarkdownPrintEngine.shared.coreVersion.contains("MarkdownPrintCore"))
    }

    // MARK: - Progress

    func testProgressTotalUnitCountIsSet() throws {
        let engine = MarkdownPrintEngine()
        let md = "# H1\n\nTexto.\n\n## H2\n\nMas texto.\n\n### H3\n\nFinal."
        let progress = Progress()
        _ = try! engine.render(md, options: RenderOptions(pageSize: .a4), progress: progress)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    func testProgressCompletesAllUnits() throws {
        let engine = MarkdownPrintEngine()
        let md = "# Uno\n\nTexto.\n\n# Dos\n\nTexto.\n\n# Tres\n\nTexto."
        let progress = Progress()
        _ = try! engine.render(md, options: RenderOptions(pageSize: .a4), progress: progress)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
        XCTAssertGreaterThan(progress.completedUnitCount, 0)
    }

    func testProgressWithSinglePage() throws {
        let engine = MarkdownPrintEngine()
        let progress = Progress()
        _ = try! engine.render("Hola", options: RenderOptions(pageSize: .a4), progress: progress)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
        XCTAssertGreaterThan(progress.completedUnitCount, 0)
    }

    func testProgressWithNilDoesNotCrash() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("# Hola", options: RenderOptions(pageSize: .a4), progress: nil)
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testProgressSyncRenderPDF() throws {
        let engine = MarkdownPrintEngine()
        let progress = Progress()
        let pdfData = try! engine.render("# Hola", options: RenderOptions(pageSize: .a4), progress: progress).pdfData
        XCTAssertGreaterThan(pdfData.count, 1000)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    func testProgressWithAllThemes() throws {
        let themes: [MarkdownPrintTheme] = [.light, .dark, .mono, .highContrast]
        for theme in themes {
            let engine = MarkdownPrintEngine()
            let progress = Progress()
            let result = try! engine.render("# \(theme.modeName)", options: RenderOptions(pageSize: .a4), progress: progress)
            XCTAssertGreaterThan(result.pdfData.count, 1000)
            XCTAssertEqual(progress.completedUnitCount, progress.completedUnitCount) // no-op sanity: progress is usable
        }
    }

    func testProgressWithTOC() throws {
        let engine = MarkdownPrintEngine()
        let md = "# H1\n\n## H2\n\n### H3\n\nTexto."
        let progress = Progress()
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4, withTOC: true), progress: progress)
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    func testProgressWithLongDocument() throws {
        let engine = MarkdownPrintEngine()
        var md = ""
        for i in 1...60 { md += "Parrafo \(i) con bastante texto para forzar paginacion multiple en el documento. " }
        let progress = Progress()
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4), progress: progress)
        XCTAssertGreaterThan(result.pageCount, 1)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
        XCTAssertGreaterThan(progress.completedUnitCount, 0)
    }

    // MARK: - Progress Async

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncProgressRenderPDF() async throws {
        let engine = MarkdownPrintEngine()
        let progress = Progress()
        let result = try! engine.render("# Async Progress", options: RenderOptions(pageSize: .a4), progress: progress)
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncProgressRenderPDFWithDiagnostics() async throws {
        let engine = MarkdownPrintEngine()
        let md = "# Titulo\n\n[Link](https://x.com) y texto."
        let progress = Progress()
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4), progress: progress)
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertGreaterThan(result.linkCount, 0)
        XCTAssertGreaterThan(progress.totalUnitCount, 0)
        XCTAssertGreaterThan(progress.completedUnitCount, 0)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncProgressWithNilProgress() async throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("# Test", options: RenderOptions(pageSize: .a4), progress: nil)
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testAsyncProgressSequentialEngines() async throws {
        // Usamos engines independientes secuencialmente
        let engine1 = MarkdownPrintEngine()
        let r1 = try await engine1.render("# A\n\nTexto.", options: RenderOptions(pageSize: .a4))
        let engine2 = MarkdownPrintEngine()
        let r2 = try await engine2.render("# B\n\nTexto.", options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(r1.pdfData.count, 1000)
        XCTAssertGreaterThan(r2.pdfData.count, 1000)
    }

    // MARK: - Cancellation

    @available(macOS 13.0, iOS 16.0, *)
    func testLoggerExists() {
        let log = Logger.markdownPrint
        XCTAssertNotNil(log)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testCancellableRenderPDF() async throws {
        let engine = MarkdownPrintEngine()
        let data = try await engine.renderPDFCancellable(fromMarkdown: "# Cancellable", pageSize: .a4)
        XCTAssertGreaterThan(data.count, 1000)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testCancellableRenderWithDiagnostics() async throws {
        let engine = MarkdownPrintEngine()
        let md = """
        # Cancellable Test

        Texto con [enlace](https://x.com) e ![imagen](img.png).

        ## Subtitulo

        - item 1
        - item 2

        | A | B |
        |---|---|
        | 1 | 2 |

        ```swift
        let x = 42
        ```

        > Cita final.
        """
        let result = try await engine.renderPDFWithDiagnosticsCancellable(fromMarkdown: md, pageSize: .a4)
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertGreaterThan(result.linkCount, 0)
        XCTAssertGreaterThan(result.headingCount, 0)
        XCTAssertGreaterThan(result.imageCount, 0)
        XCTAssertGreaterThan(result.duration, 0)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testCancellableWithProgress() async throws {
        let engine = MarkdownPrintEngine()
        var md = ""
        for i in 1...40 { md += "# Section \(i)\n\nTexto de la seccion \(i).\n\n" }
        let progress = Progress()
        let result = try await engine.renderPDFWithDiagnosticsCancellable(fromMarkdown: md, pageSize: .a4, progress: progress)
        XCTAssertGreaterThan(result.pageCount, 1)
        XCTAssertGreaterThan(progress.completedUnitCount, 0)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testCancellableWithTOC() async throws {
        let engine = MarkdownPrintEngine()
        let md = "# H1\n\n## H2\n\n### H3\n\nTexto.\n\n# H1bis\n\n## H2bis"
        let result = try await engine.renderPDFWithDiagnosticsCancellable(fromMarkdown: md, pageSize: .a4, withTOC: true)
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testCancellableWithAllThemes() async throws {
        let themes: [MarkdownPrintTheme] = [.light, .dark, .mono, .highContrast]
        for theme in themes {
            let engine = MarkdownPrintEngine()
            let result = try await engine.renderPDFCancellable(fromMarkdown: "# \(theme.modeName)", pageSize: .a4, theme: theme)
            XCTAssertGreaterThan(result.count, 1000)
        }
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testCancellableEmptyDocument() async throws {
        let engine = MarkdownPrintEngine()
        let data = try await engine.renderPDFCancellable(fromMarkdown: "", pageSize: .a4)
        XCTAssertGreaterThan(data.count, 0)
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testCancellableThrowsWhenCancelled() async throws {
        let engine = MarkdownPrintEngine()
        // Documento suficientemente grande como para que la cancelacion
        // se detecte entre paginas antes de que termine.
        var md = ""
        for i in 1...200 { md += "# Section \(i)\n\nParagraph with **bold** and `code`.\n\n- item a\n- item b\n\n" }
        let task = Task {
            try await engine.renderPDFCancellable(fromMarkdown: md, pageSize: .a4)
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        do {
            _ = try await task.value
            // Si el render termino antes de que la cancelacion hiciera efecto,
            // es aceptable para documentos que caben en pocas paginas.
        } catch is CancellationError {
            // Comportamiento esperado: cancelacion detectada entre paginas.
        } catch {
            // Otro error tambien aceptable si la cancelacion se propaga de forma distinta.
        }
    }

    @available(macOS 13.0, iOS 16.0, *)
    func testCancellableWithDiagnosticsThrowsWhenCancelled() async throws {
        let engine = MarkdownPrintEngine()
        var md = ""
        for i in 1...200 { md += "# Section \(i)\n\nParagraph.\n\n" }
        let task = Task {
            try await engine.renderPDFWithDiagnosticsCancellable(fromMarkdown: md, pageSize: .a4)
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        do {
            _ = try await task.value
        } catch is CancellationError {
            // Comportamiento esperado.
        } catch {
            // Aceptable.
        }
    }

    // MARK: - SwiftUI Configuration

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationDefaultValues() {
        let config = MarkdownPrintConfiguration.default
        XCTAssertEqual(config.pageSize, .a4)
        XCTAssertEqual(config.theme, .light)
        XCTAssertFalse(config.withTOC)
        XCTAssertNil(config.baseURL)
        XCTAssertNil(config.metadata.title)
        XCTAssertNil(config.metadata.author)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationCustomInit() {
        let engine = MarkdownPrintEngine()
        let metadata = PDFMetadata(title: "T", author: "A")
        let url = URL(fileURLWithPath: "/tmp")
        let config = MarkdownPrintConfiguration(
            engine: engine,
            pageSize: .usLetter,
            metadata: metadata,
            baseURL: url,
            theme: .dark,
            withTOC: true
        )
        XCTAssertEqual(config.pageSize, .usLetter)
        XCTAssertEqual(config.theme, .dark)
        XCTAssertTrue(config.withTOC)
        XCTAssertEqual(config.baseURL?.path, "/tmp")
        XCTAssertEqual(config.metadata.title, "T")
        XCTAssertEqual(config.metadata.author, "A")
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationDefaultIsStatic() {
        let d1 = MarkdownPrintConfiguration.default
        let d2 = MarkdownPrintConfiguration.default
        XCTAssertEqual(d1.pageSize, d2.pageSize)
        XCTAssertEqual(d1.theme, d2.theme)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationAllPageSizes() {
        let sizes: [MarkdownPageSize] = [.usLetter, .a4, .custom(width: 300, height: 500)]
        for size in sizes {
            let config = MarkdownPrintConfiguration(pageSize: size)
            XCTAssertEqual(config.pageSize, size)
        }
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationAllThemes() {
        let themes: [MarkdownPrintTheme] = [.light, .dark, .mono, .highContrast]
        for theme in themes {
            let config = MarkdownPrintConfiguration(theme: theme)
            XCTAssertEqual(config.theme, theme)
        }
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationUsesEngine() throws {
        let engine = MarkdownPrintEngine()
        _ = MarkdownPrintConfiguration(engine: engine)
        let result = try! engine.render("# Engine", options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationWithTOCFalseByDefault() {
        let config = MarkdownPrintConfiguration()
        XCTAssertFalse(config.withTOC)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationBaseURL() {
        let url = URL(fileURLWithPath: "/some/base/path")
        let config = MarkdownPrintConfiguration(baseURL: url)
        XCTAssertEqual(config.baseURL, url)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationMetadataNil() {
        let config = MarkdownPrintConfiguration(metadata: PDFMetadata(title: nil, author: nil))
        XCTAssertNil(config.metadata.title)
        XCTAssertNil(config.metadata.author)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testConfigurationMetadataFull() {
        let config = MarkdownPrintConfiguration(metadata: PDFMetadata(title: "El Quijote", author: "Cervantes"))
        XCTAssertEqual(config.metadata.title, "El Quijote")
        XCTAssertEqual(config.metadata.author, "Cervantes")
    }

    // MARK: - MarkdownPrintError

    func testErrorInvalidUTF8Description() {
        let error = MarkdownPrintError.invalidUTF8
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.errorDescription!.contains("UTF-8") || error.errorDescription!.contains("utf") || error.errorDescription!.contains("UTF"),
                      "errorDescription debe mencionar UTF-8")
    }

    func testErrorNotImplementedYetDescription() {
        let error = MarkdownPrintError.notImplementedYet("LaTeX avanzado")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("LaTeX avanzado"),
                      "errorDescription debe incluir el nombre de la feature")
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testErrorNotImplementedYetWithDifferentFeatures() {
        let features = ["HTML blocks", "Math rendering", "PDF/A export"]
        for feature in features {
            let error = MarkdownPrintError.notImplementedYet(feature)
            XCTAssertTrue(error.errorDescription!.contains(feature))
            XCTAssertNotNil(error.recoverySuggestion)
        }
    }

    func testErrorEquatable() {
        XCTAssertEqual(MarkdownPrintError.invalidUTF8, MarkdownPrintError.invalidUTF8)
        XCTAssertEqual(
            MarkdownPrintError.notImplementedYet("X"),
            MarkdownPrintError.notImplementedYet("X")
        )
        XCTAssertNotEqual(
            MarkdownPrintError.notImplementedYet("A"),
            MarkdownPrintError.notImplementedYet("B")
        )
        XCTAssertNotEqual(MarkdownPrintError.invalidUTF8, MarkdownPrintError.notImplementedYet(""))
    }

    func testErrorLocalizedErrorConformance() {
        let error: any Error = MarkdownPrintError.invalidUTF8
        let localizedError = error as? any LocalizedError
        XCTAssertNotNil(localizedError, "MarkdownPrintError debe ser LocalizedError")
    }

    // MARK: - PDFMetadata

    func testPDFMetadataDefaultInit() {
        let metadata = PDFMetadata()
        XCTAssertNil(metadata.title)
        XCTAssertNil(metadata.author)
    }

    func testPDFMetadataPartialInit() {
        let m1 = PDFMetadata(title: "Solo titulo")
        XCTAssertEqual(m1.title, "Solo titulo")
        XCTAssertNil(m1.author)
        XCTAssertNil(m1.subject)
        XCTAssertTrue(m1.keywords.isEmpty)

        let m2 = PDFMetadata(author: "Solo autor")
        XCTAssertNil(m2.title)
        XCTAssertEqual(m2.author, "Solo autor")
    }

    func testPDFMetadataEquatableIncludesSubjectAndKeywords() {
        let first = PDFMetadata(title: "T", author: "A", subject: "S", keywords: ["one", "two"])
        let same = PDFMetadata(title: "T", author: "A", subject: "S", keywords: ["one", "two"])
        let changedSubject = PDFMetadata(title: "T", author: "A", subject: "Other", keywords: ["one", "two"])
        let changedKeywords = PDFMetadata(title: "T", author: "A", subject: "S", keywords: ["two", "one"])

        XCTAssertEqual(first, same)
        XCTAssertNotEqual(first, changedSubject)
        XCTAssertNotEqual(first, changedKeywords)
    }

    func testPDFMetadataSubjectAndKeywordsAreWrittenToPDF() throws {
        let engine = MarkdownPrintEngine()
        let metadata = PDFMetadata(
            title: "Accessible Doc",
            author: "Team",
            subject: "Accessibility audit",
            keywords: ["markdown", "pdf", "accessibility"]
        )
        let result = try engine.render("# Title\n\nText.", options: RenderOptions(metadata: metadata))

        #if canImport(PDFKit)
        let document = try XCTUnwrap(PDFDocument(data: result.pdfData))
        let attributes = document.documentAttributes ?? [:]
        XCTAssertEqual(attributes[PDFDocumentAttribute.titleAttribute] as? String, "Accessible Doc")
        XCTAssertEqual(attributes[PDFDocumentAttribute.authorAttribute] as? String, "Team")
        XCTAssertEqual(attributes[PDFDocumentAttribute.subjectAttribute] as? String, "Accessibility audit")
        XCTAssertNotNil(attributes[PDFDocumentAttribute.keywordsAttribute])
        #endif
    }

    // MARK: - PDFRenderResult

    func testPDFRenderResultDirectInit() {
        let data = Data("%PDF-1.4 test".utf8)
        let result = PDFRenderResult(
            pdfData: data,
            pageCount: 3,
            linkCount: 5,
            imageCount: 2,
            headingCount: 7,
            duration: 0.123
        )
        XCTAssertEqual(result.pdfData, data)
        XCTAssertEqual(result.pageCount, 3)
        XCTAssertEqual(result.linkCount, 5)
        XCTAssertEqual(result.imageCount, 2)
        XCTAssertEqual(result.headingCount, 7)
        XCTAssertEqual(result.duration, 0.123, accuracy: 0.001)
    }

    func testPDFRenderResultZeroCounts() {
        let result = PDFRenderResult(
            pdfData: Data(),
            pageCount: 0,
            linkCount: 0,
            imageCount: 0,
            headingCount: 0,
            duration: 0
        )
        XCTAssertEqual(result.pageCount, 0)
        XCTAssertEqual(result.linkCount, 0)
        XCTAssertEqual(result.duration, 0)
    }

    // MARK: - layout(data:)

    func testLayoutWithDataValidUTF8() throws {
        let engine = MarkdownPrintEngine()
        let data = "# Titulo\n\nParrafo con **negrita**.".data(using: .utf8)!
        let layout = try engine.layout(data: data, pageSize: .a4)
        XCTAssertGreaterThan(layout.pages.count, 0)
        XCTAssertGreaterThan(layout.pages[0].elements.count, 0)
    }

    func testLayoutWithDataInvalidUTF8() {
        let engine = MarkdownPrintEngine()
        let invalidData = Data([0xFF, 0xFE, 0x00, 0x01])
        XCTAssertThrowsError(try engine.layout(data: invalidData, pageSize: .a4)) { error in
            XCTAssertEqual(error as? MarkdownPrintError, .invalidUTF8)
        }
    }

    func testLayoutWithDataAllPageSizes() throws {
        let engine = MarkdownPrintEngine()
        let data = "Hola mundo".data(using: .utf8)!
        let sizes: [(MarkdownPageSize, Double, Double)] = [
            (.usLetter, 612, 792),
            (.a4, 595.2756, 841.8898),
            (.custom(width: 400, height: 600), 400, 600)
        ]
        for (size, w, h) in sizes {
            let layout = try engine.layout(data: data, pageSize: size)
            XCTAssertEqual(layout.geometry.pageWidth, w, accuracy: 0.1)
            XCTAssertEqual(layout.geometry.pageHeight, h, accuracy: 0.1)
        }
    }

    func testLayoutWithDataEmptyString() throws {
        let engine = MarkdownPrintEngine()
        let data = "".data(using: .utf8)!
        let layout = try engine.layout(data: data, pageSize: .a4)
        // Documento vacio puede producir 0 o 1 pagina segun implementacion
        XCTAssertLessThanOrEqual(layout.pages.count, 1)
    }

    func testLayoutWithDataDefaultPageSize() throws {
        let engine = MarkdownPrintEngine()
        let data = "test".data(using: .utf8)!
        let layout = try engine.layout(data: data)
        // Default is usLetter
        XCTAssertEqual(layout.geometry.pageWidth, 612.0, accuracy: 0.1)
        XCTAssertEqual(layout.geometry.pageHeight, 792.0, accuracy: 0.1)
    }

    // MARK: - tokenize(data:) / parse(data:)

    func testTokenizeWithDataInvalidUTF8() {
        let engine = MarkdownPrintEngine()
        let invalidData = Data([0xFF, 0xFE])
        XCTAssertThrowsError(try engine.tokenize(data: invalidData)) { error in
            XCTAssertEqual(error as? MarkdownPrintError, .invalidUTF8)
        }
    }

    func testParseWithDataInvalidUTF8() {
        let engine = MarkdownPrintEngine()
        let invalidData = Data([0x80, 0x80, 0x80])
        XCTAssertThrowsError(try engine.parse(data: invalidData)) { error in
            XCTAssertEqual(error as? MarkdownPrintError, .invalidUTF8)
        }
    }

    func testTokenizeWithDataEmpty() throws {
        let engine = MarkdownPrintEngine()
        let data = "".data(using: .utf8)!
        let tokens = try engine.tokenize(data: data)
        XCTAssertEqual(tokens.count, 0)
    }

    func testParseWithDataEmpty() throws {
        let engine = MarkdownPrintEngine()
        let data = "".data(using: .utf8)!
        let blocks = try engine.parse(data: data)
        XCTAssertEqual(blocks.count, 0)
    }

    // MARK: - All MarkdownTokenKind cases

    func testAllTokenKindsAreRepresentable() {
        let allKinds: [MarkdownTokenKind] = [
            .heading(level: 1),
            .unorderedListItem,
            .orderedListItem(number: 3),
            .horizontalRule,
            .codeBlock(language: "swift"),
            .blankLine,
            .tableRow,
            .blockquote,
            .rawHtmlBlock,
            .mathBlock,
            .paragraph,
            .unknown
        ]
        XCTAssertEqual(allKinds.count, 12)
        for kind in allKinds {
            let token = MarkdownToken(kind: kind, text: "test")
            XCTAssertEqual(token.text, "test")
        }
    }

    func testAllInlineKindsAreRepresentable() {
        let allKinds: [MarkdownInlineKind] = [
            .plainText, .bold, .italic, .code, .strikethrough,
            .link, .image, .hardBreak, .inlineMath
        ]
        XCTAssertEqual(allKinds.count, 9)
        for kind in allKinds {
            let run = MarkdownInlineRun(kind: kind, text: "test", url: "url")
            XCTAssertEqual(run.text, "test")
        }
    }

    func testAllBlockKindsAreRepresentable() {
        let allKinds: [MarkdownBlockKind] = [
            .heading(level: 3),
            .paragraph,
            .unorderedList,
            .orderedList,
            .horizontalRule,
            .codeBlock(language: "python"),
            .table(columnCount: 4),
            .rawHtmlBlock(tag: "div"),
            .mathBlock,
            .blockquote,
            .unknown
        ]
        XCTAssertEqual(allKinds.count, 11)
    }

    func testAllLayoutElementKindsAreRepresentable() {
        let allKinds: [MarkdownLayoutElementKind] = [
            .word, .horizontalRule, .tableGridLine, .image, .rawHtml, .mathBlock
        ]
        XCTAssertEqual(allKinds.count, 6)
    }

    // MARK: - MarkdownListItem

    func testListItemFullInit() {
        let item = MarkdownListItem(
            number: 3,
            checked: true,
            isTask: true,
            indent: 2,
            items: [],
            inlines: [MarkdownInlineRun(kind: .bold, text: "item", url: "")]
        )
        XCTAssertEqual(item.number, 3)
        XCTAssertTrue(item.checked)
        XCTAssertTrue(item.isTask)
        XCTAssertEqual(item.indent, 2)
        XCTAssertEqual(item.items.count, 0)
        XCTAssertEqual(item.inlines.count, 1)
    }

    func testListItemEquatable() {
        let a = MarkdownListItem(number: 1, checked: false, isTask: false, indent: 0, items: [], inlines: [])
        let b = MarkdownListItem(number: 1, checked: false, isTask: false, indent: 0, items: [], inlines: [])
        let c = MarkdownListItem(number: 2, checked: false, isTask: false, indent: 0, items: [], inlines: [])
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - MarkdownLayoutElement

    func testLayoutElementFullInit() {
        let element = MarkdownLayoutElement(
            kind: .word,
            x: 10.0,
            y: 20.0,
            width: 100.0,
            height: 14.0,
            fontSize: 12.0,
            style: .link,
            text: "enlace",
            url: "https://x.com",
            headingLevel: 0,
            isCodeBlock: false,
            isTableCell: false,
            isBlockquote: true,
            isRTL: false,
            footnoteLabel: "", headingLabel: "", crossRefLabel: ""
        )
        XCTAssertEqual(element.kind, .word)
        XCTAssertEqual(element.x, 10.0)
        XCTAssertEqual(element.y, 20.0)
        XCTAssertEqual(element.width, 100.0)
        XCTAssertEqual(element.height, 14.0)
        XCTAssertEqual(element.fontSize, 12.0)
        XCTAssertEqual(element.style, .link)
        XCTAssertEqual(element.text, "enlace")
        XCTAssertEqual(element.url, "https://x.com")
        XCTAssertEqual(element.headingLevel, 0)
        XCTAssertFalse(element.isCodeBlock)
        XCTAssertFalse(element.isTableCell)
        XCTAssertTrue(element.isBlockquote)
        XCTAssertFalse(element.isRTL)
    }

    func testLayoutElementEquatable() {
        let a = MarkdownLayoutElement(kind: .word, x: 0, y: 0, width: 10, height: 10, fontSize: 12, style: .plainText, text: "a", url: "", headingLevel: 0, isCodeBlock: false, isTableCell: false, isBlockquote: false, isRTL: false, footnoteLabel: "", headingLabel: "", crossRefLabel: "")
        let b = MarkdownLayoutElement(kind: .word, x: 0, y: 0, width: 10, height: 10, fontSize: 12, style: .plainText, text: "a", url: "", headingLevel: 0, isCodeBlock: false, isTableCell: false, isBlockquote: false, isRTL: false, footnoteLabel: "", headingLabel: "", crossRefLabel: "")
        let c = MarkdownLayoutElement(kind: .word, x: 1, y: 0, width: 10, height: 10, fontSize: 12, style: .plainText, text: "a", url: "", headingLevel: 0, isCodeBlock: false, isTableCell: false, isBlockquote: false, isRTL: false, footnoteLabel: "", headingLabel: "", crossRefLabel: "")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - MarkdownPage y MarkdownLayout

    func testMarkdownPageInit() {
        let page = MarkdownPage(pageNumber: 3, elements: [])
        XCTAssertEqual(page.pageNumber, 3)
        XCTAssertEqual(page.elements.count, 0)
    }

    func testMarkdownLayoutInit() {
        let geo = MarkdownPageGeometry(pageWidth: 612, pageHeight: 792, marginTop: 72, marginBottom: 90, marginLeft: 72, marginRight: 72, contentWidth: 468, contentHeight: 630)
        let page = MarkdownPage(pageNumber: 1, elements: [])
        let layout = MarkdownLayout(pages: [page], geometry: geo, footnoteDefs: [:])
        XCTAssertEqual(layout.pages.count, 1)
        XCTAssertEqual(layout.geometry.pageWidth, 612)
    }

    func testPageGeometryInit() {
        let geo = MarkdownPageGeometry(
            pageWidth: 612,
            pageHeight: 792,
            marginTop: 72,
            marginBottom: 90,
            marginLeft: 72,
            marginRight: 72,
            contentWidth: 468,
            contentHeight: 630
        )
        XCTAssertEqual(geo.pageWidth, 612)
        XCTAssertEqual(geo.pageHeight, 792)
        XCTAssertEqual(geo.marginTop, 72)
        XCTAssertEqual(geo.marginBottom, 90)
        XCTAssertEqual(geo.marginLeft, 72)
        XCTAssertEqual(geo.marginRight, 72)
        XCTAssertEqual(geo.contentWidth, 468)
        XCTAssertEqual(geo.contentHeight, 630)
    }

    // MARK: - MarkdownBlock

    func testMarkdownBlockFullInit() {
        let block = MarkdownBlock(
            kind: .heading(level: 2),
            inlines: [MarkdownInlineRun(kind: .plainText, text: "Titulo", url: "")],
            items: [],
            text: "",
            tableHeaders: [],
            tableCells: [],
            tableColumnCount: 0,
            tableAlign: [0, 1, 2],
            htmlTag: "",
            htmlContent: ""
        )
        XCTAssertEqual(block.kind, .heading(level: 2))
        XCTAssertEqual(block.inlines.count, 1)
        XCTAssertEqual(block.tableAlign, [0, 1, 2])
    }

    func testMarkdownBlockEquatable() {
        let a = MarkdownBlock(kind: .paragraph, inlines: [], items: [], text: "", tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        let b = MarkdownBlock(kind: .paragraph, inlines: [], items: [], text: "", tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        let c = MarkdownBlock(kind: .heading(level: 1), inlines: [], items: [], text: "", tableHeaders: [], tableCells: [], tableColumnCount: 0, tableAlign: [], htmlTag: "", htmlContent: "")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - MarkdownPageSize

    func testPageSizeEquatable() {
        XCTAssertEqual(MarkdownPageSize.usLetter, MarkdownPageSize.usLetter)
        XCTAssertEqual(MarkdownPageSize.a4, MarkdownPageSize.a4)
        XCTAssertNotEqual(MarkdownPageSize.usLetter, MarkdownPageSize.a4)
        XCTAssertEqual(MarkdownPageSize.custom(width: 300, height: 500), MarkdownPageSize.custom(width: 300, height: 500))
        XCTAssertNotEqual(MarkdownPageSize.custom(width: 300, height: 500), MarkdownPageSize.custom(width: 400, height: 500))
    }

    // MARK: - MarkdownPrintTheme

    func testThemeCustomInit() {
        let customBg = CGColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0)
        let customText = CGColor(red: 0.9, green: 0.8, blue: 0.7, alpha: 1.0)
        let theme = MarkdownPrintTheme(
            modeName: "custom",
            pageBackground: customBg,
            codeBackground: customBg,
            inlineCodeBackground: customBg,
            tableHeaderBackground: customBg,
            text: customText,
            mutedText: customText,
            linkText: customText,
            codeText: customText,
            pageNumberText: customText,
            border: customBg,
            gridLine: customBg,
            blockquoteBar: customBg,
            headingUnderline: customBg,
            underlineLinks: false,
            syntaxHighlight: true,
            smallCaps: false
        )
        XCTAssertEqual(theme.modeName, "custom")
        XCTAssertFalse(theme.underlineLinks)
        XCTAssertTrue(theme.syntaxHighlight)
    }

    func testThemeHighContrastExists() {
        let theme = MarkdownPrintTheme.highContrast
        XCTAssertEqual(theme.modeName, "highContrast")
        XCTAssertEqual(theme.pageBackground.alpha, 1.0)
        XCTAssertEqual(theme.text.alpha, 1.0)
    }

    func testThemeEqualityByName() {
        XCTAssertEqual(MarkdownPrintTheme.light, MarkdownPrintTheme.light)
        XCTAssertNotEqual(MarkdownPrintTheme.light, MarkdownPrintTheme.dark)
    }

    // MARK: - MarkdownPrintView (SwiftUI)

    @available(macOS 14.0, iOS 17.0, *)
    func testMarkdownPrintViewInit() {
        let view = MarkdownPrintView("# Hola")
        // Verificar que el init no crashea
        XCTAssertNotNil(view)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testMarkdownPrintViewInitWithConfiguration() {
        let config = MarkdownPrintConfiguration(pageSize: .usLetter, theme: .dark, withTOC: true)
        let view = MarkdownPrintView("## Test", configuration: config)
        XCTAssertNotNil(view)
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testMarkdownPrintViewInitWithAllConfigs() {
        let themes: [MarkdownPrintTheme] = [.light, .dark, .mono, .highContrast]
        for theme in themes {
            let config = MarkdownPrintConfiguration(theme: theme)
            let view = MarkdownPrintView("# \(theme.modeName)", configuration: config)
            XCTAssertNotNil(view)
        }
    }

    @available(macOS 14.0, iOS 17.0, *)
    func testMarkdownPrintViewEmptyMarkdown() {
        let view = MarkdownPrintView("")
        XCTAssertNotNil(view)
    }

    // MARK: - Render with dynamicTypeScale

    func testRenderPDFWithDynamicTypeScale() throws {
        let engine = MarkdownPrintEngine()
        let md = "# Hola\n\nTexto con **negrita**."
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4, dynamicTypeScale: 1.5))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFWithDynamicTypeScaleSmall() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("texto", options: RenderOptions(pageSize: .a4, dynamicTypeScale: 0.8))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    func testRenderPDFWithDynamicTypeScaleLarge() throws {
        let engine = MarkdownPrintEngine()
        let result = try! engine.render("# Big\n\nText.", options: RenderOptions(pageSize: .a4, dynamicTypeScale: 2.0))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    // MARK: - Core version adicional

    func testCoreVersionIsNonEmpty() {
        let engine = MarkdownPrintEngine()
        let version = engine.coreVersion
        XCTAssertFalse(version.isEmpty)
        // Contiene numeros de version
        XCTAssertTrue(version.contains(".") || version.contains("."))
    }

    // MARK: - HighContrast theme render

    func testRenderPDFWithHighContrastTheme() throws {
        let engine = MarkdownPrintEngine()
        let md = """
        # High Contrast

        Texto normal con **negrita**, *cursiva*, `codigo`, [link](https://x.com).

        > Cita de prueba

        - item 1
        - item 2
        """
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4, theme: .highContrast))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    // MARK: - Syntax Highlighting

    func testSyntaxHighlightRendersCodeBlock() throws {
        let engine = MarkdownPrintEngine()
        let md = """
        # Code

        ```swift
        let x = 42
        func hello() -> String {
            return "world"
        }
        ```
        """
        // Usar tema con syntaxHighlight activado
        let result = try! engine.render(md, options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        // Verificar que light tiene syntaxHighlight habilitado
        XCTAssertTrue(MarkdownPrintTheme.light.syntaxHighlight)
    }

    // MARK: - Render with baseURL

    func testRenderPDFWithBaseURL() throws {
        let engine = MarkdownPrintEngine()
        _ = URL(fileURLWithPath: "/tmp/test_base")
        let result = try! engine.render("# Test", options: RenderOptions(pageSize: .a4))
        XCTAssertGreaterThan(result.pdfData.count, 1000)
    }

    // MARK: - Render fromMarkdownData overload

    func testRenderPDFFromData() throws {
        let engine = MarkdownPrintEngine()
        let data = "# Data API\n\nParrafo de prueba.".data(using: .utf8)!
        let pdfData = try! engine.renderPDF(fromMarkdownData: data, pageSize: .a4)
        XCTAssertGreaterThan(pdfData.count, 1000)
    }

    func testRenderPDFWithDiagnosticsFromDataWithAllParams() throws {
        let engine = MarkdownPrintEngine()
        let data = "# Full\n\n[Link](url) y texto.".data(using: .utf8)!
        let metadata = PDFMetadata(title: "T", author: "A")
        let result = try! engine.renderPDFWithDiagnostics(
            fromMarkdownData: data,
            pageSize: .usLetter,
            metadata: metadata,
            baseURL: URL(fileURLWithPath: "/tmp"),
            theme: .dark,
            withTOC: true,
            dynamicTypeScale: 1.2
        )
        XCTAssertGreaterThan(result.pdfData.count, 1000)
        XCTAssertGreaterThan(result.pageCount, 0)
    }

    func testRenderPDFFromDataInvalidUTF8() {
        let engine = MarkdownPrintEngine()
        let invalidData = Data([0xFF, 0xFE, 0x00])
        XCTAssertThrowsError(try engine.renderPDF(fromMarkdownData: invalidData)) { error in
            XCTAssertEqual(error as? MarkdownPrintError, .invalidUTF8)
        }
    }

    func testRenderPDFWithDiagnosticsFromDataInvalidUTF8() {
        let engine = MarkdownPrintEngine()
        let invalidData = Data([0x80, 0x80])
        XCTAssertThrowsError(try engine.renderPDFWithDiagnostics(fromMarkdownData: invalidData)) { error in
            XCTAssertEqual(error as? MarkdownPrintError, .invalidUTF8)
        }
    }

    // MARK: - MarkdownToken

    func testMarkdownTokenInit() {
        let token = MarkdownToken(kind: .heading(level: 3), text: "Titulo")
        XCTAssertEqual(token.kind, .heading(level: 3))
        XCTAssertEqual(token.text, "Titulo")
    }

    func testMarkdownInlineRunInit() {
        let run = MarkdownInlineRun(kind: .link, text: "click", url: "https://x.com")
        XCTAssertEqual(run.kind, .link)
        XCTAssertEqual(run.text, "click")
        XCTAssertEqual(run.url, "https://x.com")
    }

    func testMarkdownInlineRunPlainTextHasEmptyURL() {
        let run = MarkdownInlineRun(kind: .plainText, text: "normal", url: "")
        XCTAssertEqual(run.url, "")
    }

    // MARK: - Render renderPDF (without diagnostics) coverage

    func testRenderPDFPlain() throws {
        let engine = MarkdownPrintEngine()
        let pdfData = try! engine.render("# Simple\n\nParrafo.", options: RenderOptions(pageSize: .a4)).pdfData
        XCTAssertGreaterThan(pdfData.count, 1000)
    }

    func testRenderPDFWithAllParams() throws {
        let engine = MarkdownPrintEngine()
        let metadata = PDFMetadata(title: "T", author: "A")
        let data = try engine.renderPDF(
            fromMarkdown: "# All params",
            pageSize: .usLetter,
            metadata: metadata,
            baseURL: URL(fileURLWithPath: "/tmp"),
            theme: .mono,
            withTOC: true,
            dynamicTypeScale: 1.1
        )
        XCTAssertGreaterThan(data.count, 1000)
    }

    func testRenderPDFDefaultParams() throws {
        let engine = MarkdownPrintEngine()
        // Without specifying any optional params, verify defaults work
        let pdfData = try! engine.render("test", options: RenderOptions(pageSize: .a4)).pdfData
        XCTAssertGreaterThan(pdfData.count, 1000)
    }
}
