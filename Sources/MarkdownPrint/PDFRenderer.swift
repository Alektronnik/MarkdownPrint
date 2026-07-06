import CoreGraphics
import CoreText
import Foundation
import ImageIO
import PDFKit
import os.log
import MarkdownPrintCore

enum PDFRenderError: Error {
    case couldNotCreateContext
}

public struct PDFMetadata: Equatable, Sendable {
    public let title: String?
    public let author: String?
    public let subject: String?
    public let keywords: [String]

    public init(title: String? = nil, author: String? = nil, subject: String? = nil, keywords: [String] = []) {
        self.title = title
        self.author = author
        self.subject = subject
        self.keywords = keywords
    }
}

private struct OutlineEntry {
    let title: String
    let pageNumber: Int
    let level: Int
}

enum PDFRenderer {

    private static let codeBlockPaddingH: CGFloat = 10.0

    static func render(_ documentLayout: MarkdownLayout, metadata: PDFMetadata = PDFMetadata(), baseURL: URL? = nil, theme: MarkdownPrintTheme = .light, withTOC: Bool = false, scaleFactor: CGFloat = 1.0, fontFamily: FontFamily = .apple, progress: Progress? = nil, showLineNumbers: Bool = false, justifyText: Bool = false, watermark: Watermark? = nil, headerFooter: PageHeaderFooter? = nil) throws -> Data {
        let geometry = documentLayout.geometry
        var mediaBox = CGRect(x: 0, y: 0, width: geometry.pageWidth, height: geometry.pageHeight)

        var auxInfo: [CFString: Any] = [
            kCGPDFContextCreator: "MarkdownPrint"
        ]
        if let title = metadata.title {
            auxInfo[kCGPDFContextTitle] = title
        }
        if let author = metadata.author {
            auxInfo[kCGPDFContextAuthor] = author
        }
        if let subject = metadata.subject {
            auxInfo[kCGPDFContextSubject] = subject
        }
        if !metadata.keywords.isEmpty {
            auxInfo[kCGPDFContextKeywords] = metadata.keywords.joined(separator: ", ")
        }

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw PDFRenderError.couldNotCreateContext
        }
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, auxInfo as CFDictionary) else {
            throw PDFRenderError.couldNotCreateContext
        }

        var outlineEntries: [OutlineEntry] = []

        // --- Cross-reference resolver: build label -> "Section X.Y" map ---
        var headingLabels: [(label: String, page: Int, level: Int, order: Int)] = []
        var hOrder = 0
        for page in documentLayout.pages {
            for el in page.elements {
                if !el.headingLabel.isEmpty && el.headingLevel > 0 {
                    hOrder += 1
                    headingLabels.append((el.headingLabel, 0, el.headingLevel, hOrder))
                }
            }
        }
        // Build section numbers: "1", "1.2", "1.2.3", etc.
        var secCounter = [0, 0, 0, 0, 0, 0, 0]
        var labelToNumber: [String: String] = [:]
        for hl in headingLabels {
            let lvl = hl.level - 1
            if lvl >= 0 && lvl < 6 {
                secCounter[lvl] += 1
                for i in (lvl + 1)..<7 { secCounter[i] = 0 }
            }
            var numParts: [String] = []
            for i in 0...lvl where secCounter[i] > 0 {
                numParts.append("\(secCounter[i])")
            }
            labelToNumber[hl.label] = numParts.joined(separator: ".")
        }

        // --- TOC: recolectar headings antes de dibujar ---
        var tocEntries: [(title: String, level: Int, targetPage: Int)] = []
        if withTOC {
            for (pageIndex, page) in documentLayout.pages.enumerated() {
                let headings = page.elements.filter { $0.headingLevel > 0 && $0.kind == .word && !$0.text.isEmpty }
                let headingLines = Dictionary(grouping: headings) { $0.y }
                let sortedY = headingLines.keys.sorted()
                for y in sortedY {
                    guard let words = headingLines[y]?.sorted(by: { $0.x < $1.x }), !words.isEmpty else { continue }
                    let title = words.map(\.text).joined(separator: " ")
                    tocEntries.append((title: title, level: words[0].headingLevel, targetPage: pageIndex + 1))
                }
            }
        }

        var tocOffset = 0
        if !tocEntries.isEmpty {
            tocOffset = drawTOC(tocEntries, geometry: geometry, theme: theme, tocStartPage: 0, in: context, scaleFactor: scaleFactor)
            context.endPDFPage()
            progress?.completedUnitCount = Int64(tocOffset)
        }

        for (pageIndex, page) in documentLayout.pages.enumerated() {
            outlineEntries.append(contentsOf: outlineEntriesForPage(page, pageOffset: tocOffset))

            context.beginPDFPage(nil)
            if let wm = watermark {
                drawWatermark(wm, geometry: geometry, in: context)
            }
            draw(page: page, geometry: geometry, in: context, baseURL: baseURL, theme: theme, pageOffset: tocOffset, scaleFactor: scaleFactor, fontFamily: fontFamily, showLineNumbers: showLineNumbers, justifyText: justifyText, labelToNumber: labelToNumber, footnoteDefs: documentLayout.footnoteDefs)

            if let hf = headerFooter {
                drawHeaderFooter(hf, page: page, geometry: geometry, in: context, theme: theme, metadata: metadata, pageOffset: tocOffset, totalPages: documentLayout.pages.count + tocOffset, labelToNumber: labelToNumber)
            }

            let linkRects = linkRectsForPage(page, geometry: geometry, theme: theme)
            for link in linkRects {
                let url = URL(string: link.url) ?? URL(string: link.url.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")
                if let url {
                    context.setURL(url as CFURL, for: link.rect)
                }
            }

            context.endPDFPage()
            progress?.completedUnitCount = Int64(pageIndex + 1 + tocOffset)
        }

        // Draw endnotes (footnote definitions) on a final page if any.
        if !documentLayout.footnoteDefs.isEmpty {
            drawEndnotes(documentLayout.footnoteDefs, geometry: geometry, in: context, theme: theme, scaleFactor: scaleFactor, fontFamily: fontFamily)
        }

        context.closePDF()

        var finalData = pdfData as Data
        if !outlineEntries.isEmpty {
            finalData = addOutline(outlineEntries, to: finalData)
        }

        return finalData
    }

    // MARK: - Cancellable rendering

    static func renderCancellable(
        _ documentLayout: MarkdownLayout,
        metadata: PDFMetadata = PDFMetadata(),
        baseURL: URL? = nil,
        theme: MarkdownPrintTheme = .light,
        withTOC: Bool = false,
        scaleFactor: CGFloat = 1.0,
        fontFamily: FontFamily = .apple,
        progress: Progress? = nil,
        isCancelled: @escaping () -> Bool = { false },
        showLineNumbers: Bool = false,
        justifyText: Bool = false,
        watermark: Watermark? = nil,
        headerFooter: PageHeaderFooter? = nil
    ) throws -> Data {
        let geometry = documentLayout.geometry
        var mediaBox = CGRect(x: 0, y: 0, width: geometry.pageWidth, height: geometry.pageHeight)
        var auxInfo: [CFString: Any] = [kCGPDFContextCreator: "MarkdownPrint"]
        if let title = metadata.title { auxInfo[kCGPDFContextTitle] = title }
        if let author = metadata.author { auxInfo[kCGPDFContextAuthor] = author }
        if let subject = metadata.subject { auxInfo[kCGPDFContextSubject] = subject }
        if !metadata.keywords.isEmpty { auxInfo[kCGPDFContextKeywords] = metadata.keywords.joined(separator: ", ") }
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, auxInfo as CFDictionary) else {
            throw PDFRenderError.couldNotCreateContext
        }
        var outlineEntries: [OutlineEntry] = []

        // Cross-reference resolver.
        var headingLabels: [(label: String, page: Int, level: Int, order: Int)] = []
        var hOrder = 0
        for page in documentLayout.pages {
            for el in page.elements {
                if !el.headingLabel.isEmpty && el.headingLevel > 0 {
                    hOrder += 1
                    headingLabels.append((el.headingLabel, 0, el.headingLevel, hOrder))
                }
            }
        }
        var secCounter = [0, 0, 0, 0, 0, 0, 0]
        var labelToNumber: [String: String] = [:]
        for hl in headingLabels {
            let lvl = hl.level - 1
            if lvl >= 0 && lvl < 6 {
                secCounter[lvl] += 1
                for i in (lvl + 1)..<7 { secCounter[i] = 0 }
            }
            var numParts: [String] = []
            for i in 0...lvl where secCounter[i] > 0 { numParts.append("\(secCounter[i])") }
            labelToNumber[hl.label] = numParts.joined(separator: ".")
        }

        var tocEntries: [(title: String, level: Int, targetPage: Int)] = []
        if withTOC {
            for (pageIndex, page) in documentLayout.pages.enumerated() {
                let headings = page.elements.filter { $0.headingLevel > 0 && $0.kind == .word && !$0.text.isEmpty }
                let headingLines = Dictionary(grouping: headings) { $0.y }
                for y in headingLines.keys.sorted() {
                    guard let words = headingLines[y]?.sorted(by: { $0.x < $1.x }), !words.isEmpty else { continue }
                    tocEntries.append((title: words.map(\.text).joined(separator: " "), level: words[0].headingLevel, targetPage: pageIndex + 1))
                }
            }
        }
        var tocOffset = 0
        if !tocEntries.isEmpty {
            tocOffset = drawTOC(tocEntries, geometry: geometry, theme: theme, tocStartPage: 0, in: context, scaleFactor: scaleFactor)
            context.endPDFPage()
            progress?.completedUnitCount = Int64(tocOffset)
        }
        for (pageIndex, page) in documentLayout.pages.enumerated() {
            if isCancelled() { throw CancellationError() }
            outlineEntries.append(contentsOf: outlineEntriesForPage(page, pageOffset: tocOffset))
            context.beginPDFPage(nil)
            if let wm = watermark { drawWatermark(wm, geometry: geometry, in: context) }
            draw(page: page, geometry: geometry, in: context, baseURL: baseURL, theme: theme, pageOffset: tocOffset, scaleFactor: scaleFactor, fontFamily: fontFamily, showLineNumbers: showLineNumbers, justifyText: justifyText, labelToNumber: labelToNumber, footnoteDefs: documentLayout.footnoteDefs)
            if let hf = headerFooter {
                drawHeaderFooter(hf, page: page, geometry: geometry, in: context, theme: theme, metadata: metadata, pageOffset: tocOffset, totalPages: documentLayout.pages.count + tocOffset, labelToNumber: labelToNumber)
            }
            let linkRects = linkRectsForPage(page, geometry: geometry, theme: theme)
            for link in linkRects { if let url = URL(string: link.url) ?? URL(string: link.url.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "") { context.setURL(url as CFURL, for: link.rect) } }
            context.endPDFPage()
            progress?.completedUnitCount = Int64(pageIndex + 1 + tocOffset)
        }
        if !documentLayout.footnoteDefs.isEmpty {
            drawEndnotes(documentLayout.footnoteDefs, geometry: geometry, in: context, theme: theme, scaleFactor: scaleFactor, fontFamily: fontFamily)
        }
        context.closePDF()
        var finalData = pdfData as Data
        if !outlineEntries.isEmpty { finalData = addOutline(outlineEntries, to: finalData) }
        return finalData
    }

    private static func outlineEntriesForPage(_ page: MarkdownPage, pageOffset: Int = 0) -> [OutlineEntry] {
        let headings = page.elements.filter { $0.headingLevel > 0 && $0.kind == .word && !$0.text.isEmpty }
        let headingLines = Dictionary(grouping: headings) { $0.y }
        let sortedLines: [(y: Double, words: [MarkdownLayoutElement])] = headingLines.keys.sorted().compactMap { y in
            guard let words = headingLines[y]?.sorted(by: { $0.x < $1.x }), !words.isEmpty else { return nil }
            return (y, words)
        }

        var entries: [OutlineEntry] = []
        var currentTitle = ""
        var currentLevel = 0
        var previousY: Double?
        var previousHeight: Double = 0

        func flushCurrent() {
            guard !currentTitle.isEmpty else { return }
            entries.append(OutlineEntry(title: currentTitle, pageNumber: page.pageNumber + pageOffset, level: currentLevel))
            currentTitle = ""
            currentLevel = 0
            previousY = nil
            previousHeight = 0
        }

        for line in sortedLines {
            guard let first = line.words.first else { continue }
            let lineTitle = line.words.map(\.text).joined(separator: " ")
            let lineLevel = first.headingLevel
            let continuesPreviousHeading = currentLevel == lineLevel &&
                previousY.map { line.y - $0 <= previousHeight * 1.25 } == true

            if continuesPreviousHeading {
                currentTitle += " " + lineTitle
            } else {
                flushCurrent()
                currentTitle = lineTitle
                currentLevel = lineLevel
            }
            previousY = line.y
            previousHeight = first.height
        }
        flushCurrent()
        return entries
    }

    private static func linkRectsForPage(_ page: MarkdownPage, geometry: MarkdownPageGeometry, theme: MarkdownPrintTheme) -> [(url: String, rect: CGRect)] {
        var rects: [(url: String, rect: CGRect)] = []
        var lineTextElements: [MarkdownLayoutElement] = []

        for element in page.elements where element.kind == .word {
            if element.isTableCell || element.isCodeBlock {
                if element.style == .link && !element.url.isEmpty {
                    rects.append((url: element.url, rect: linkRect(for: element, geometry: geometry, x: CGFloat(element.x), theme: theme)))
                }
            } else {
                lineTextElements.append(element)
            }
        }

        let groupedLines = Dictionary(grouping: lineTextElements) { $0.y }
        for y in groupedLines.keys.sorted() {
            guard let line = groupedLines[y] else { continue }
            let sorted = line.sorted { $0.x < $1.x }
            var previousEnd: CGFloat?

            for (index, element) in sorted.enumerated() {
                let naturalX = CGFloat(element.x)
                let measuredWidth = textWidth(for: element, theme: theme)
                let x: CGFloat

                if let end = previousEnd {
                    let previous = sorted[index - 1]
                    let isListContinuation = (previous.text == "\u{2022}" || previous.text.hasSuffix(".")) &&
                        previous.x < 8 && naturalX > end + 8
                    x = isListContinuation ? naturalX : end + spaceWidth(for: element, theme: theme)
                } else {
                    x = naturalX
                }

                if element.style == .link && !element.url.isEmpty {
                    rects.append((url: element.url, rect: linkRect(for: element, geometry: geometry, x: x, theme: theme)))
                }
                previousEnd = x + measuredWidth
            }
        }
        return rects
    }

    private static func linkRect(for element: MarkdownLayoutElement, geometry: MarkdownPageGeometry, x: CGFloat, theme: MarkdownPrintTheme) -> CGRect {
        let font = SystemFont.font(forStyle: element.style, headingLevel: element.headingLevel, size: CGFloat(element.fontSize))
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let topY = pdfTopY(forContentY: element.y, geometry: geometry)
        let baselineY = topY - ascent
        return CGRect(x: geometry.marginLeft + x,
                      y: baselineY - descent,
                      width: textWidth(for: element, theme: theme),
                      height: ascent + descent)
    }

    private static func addOutline(_ entries: [OutlineEntry], to pdfData: Data) -> Data {
        guard let pdfDoc = PDFDocument(data: pdfData) else { return pdfData }
        if !entries.isEmpty {
            let outlineRoot = pdfDoc.outlineRoot ?? PDFOutline()
            if pdfDoc.outlineRoot == nil { pdfDoc.outlineRoot = outlineRoot }
            var stack: [(outline: PDFOutline, level: Int)] = [(outlineRoot, 0)]
            for entry in entries {
                while let last = stack.last, last.level >= entry.level { stack.removeLast() }
                let newEntry = PDFOutline()
                newEntry.label = entry.title
                if let page = pdfDoc.page(at: entry.pageNumber - 1) {
                    newEntry.destination = PDFDestination(page: page, at: CGPoint(x: 0, y: page.bounds(for: .mediaBox).height))
                }
                let parent = stack.last?.outline ?? outlineRoot
                parent.insertChild(newEntry, at: parent.numberOfChildren)
                stack.append((newEntry, entry.level))
            }
        }
        return pdfDoc.dataRepresentation() ?? pdfData
    }

    // MARK: - TOC

    /// Dibuja el TOC en una o varias paginas. Retorna el numero de paginas ocupadas.
    private static func drawTOC(_ entries: [(title: String, level: Int, targetPage: Int)], geometry: MarkdownPageGeometry, theme: MarkdownPrintTheme, tocStartPage: Int, in context: CGContext, scaleFactor: CGFloat = 1.0) -> Int {
        guard !entries.isEmpty else { return 0 }

        let titleFont = SystemFont.font(forStyle: .bold, headingLevel: 1, size: 24 * scaleFactor)
        let entryFont = SystemFont.regular(size: 12 * scaleFactor)
        let pageFont = SystemFont.regular(size: 12 * scaleFactor)
        let titleText = "Contents"

        let marginLeft = geometry.marginLeft
        let contentWidth = geometry.contentWidth
        let pageNumWidth: CGFloat = 50.0
        let titleMaxWidth = contentWidth - pageNumWidth - 12.0
        let lineHeight: CGFloat = 22.0
        let headerHeight: CGFloat = 90.0  // titulo + separador + espaciado
        let usableHeight = geometry.contentHeight - headerHeight
        let entriesPerPage = max(1, Int(usableHeight / lineHeight))
        let totalPages = (entries.count + entriesPerPage - 1) / entriesPerPage

        for pageIdx in 0..<totalPages {
            if pageIdx > 0 {
                context.endPDFPage()
            }
            context.beginPDFPage(nil)

            // Fondo
            context.setFillColor(theme.pageBackground)
            context.fill(CGRect(x: 0, y: 0, width: geometry.pageWidth, height: geometry.pageHeight))

            var cursorY = geometry.pageHeight - geometry.marginTop - 30.0

            // Titulo (solo en la primera pagina)
            if pageIdx == 0 {
                let titleAttr: [CFString: Any] = [
                    kCTFontAttributeName: titleFont,
                    kCTForegroundColorAttributeName: theme.text
                ]
                let titleLine = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, titleText as CFString, titleAttr as CFDictionary))
                context.textPosition = CGPoint(x: marginLeft, y: cursorY)
                CTLineDraw(titleLine, context)
                cursorY -= 36.0

                context.setFillColor(theme.border)
                context.fill(CGRect(x: marginLeft, y: cursorY + 8, width: contentWidth, height: 0.5))
                cursorY -= 24.0
            }

            let startEntry = pageIdx * entriesPerPage
            let endEntry = min(startEntry + entriesPerPage, entries.count)

            for i in startEntry..<endEntry {
                let entry = entries[i]
                let indent = CGFloat(entry.level - 1) * 20.0

                // Titulo de entrada
                let entryAttr: [CFString: Any] = [
                    kCTFontAttributeName: entryFont,
                    kCTForegroundColorAttributeName: entry.level <= 2 ? theme.text : theme.mutedText
                ]
                let entryLine = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, entry.title as CFString, entryAttr as CFDictionary))
                let entryWidth = CTLineGetTypographicBounds(entryLine, nil, nil, nil)
                let clippedWidth = min(entryWidth, titleMaxWidth - indent)
                let entryX = marginLeft + indent

                context.textPosition = CGPoint(x: entryX, y: cursorY)
                if clippedWidth < entryWidth {
                    context.saveGState()
                    context.clip(to: CGRect(x: entryX, y: cursorY - 6, width: clippedWidth, height: 18))
                }
                CTLineDraw(entryLine, context)
                if clippedWidth < entryWidth {
                    context.restoreGState()
                }

                // Puntos guia
                let dotStr = "." as CFString
                let dotAttr: [CFString: Any] = [
                    kCTFontAttributeName: SystemFont.regular(size: 10),
                    kCTForegroundColorAttributeName: theme.mutedText
                ]
                let dotLine = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, dotStr, dotAttr as CFDictionary))
                let dotWidth = CTLineGetTypographicBounds(dotLine, nil, nil, nil)

                // Numero de pagina
                let pageStr = "\(entry.targetPage + tocStartPage + totalPages)" as CFString
                let pageAttr: [CFString: Any] = [
                    kCTFontAttributeName: pageFont,
                    kCTForegroundColorAttributeName: theme.mutedText
                ]
                let pageLine = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, pageStr, pageAttr as CFDictionary))
                let pageWidth = CTLineGetTypographicBounds(pageLine, nil, nil, nil)
                let pageNumX = marginLeft + contentWidth - pageWidth

                var dotX = entryX + clippedWidth + 4
                while dotX + dotWidth + 8 < pageNumX {
                    context.textPosition = CGPoint(x: dotX, y: cursorY)
                    CTLineDraw(dotLine, context)
                    dotX += dotWidth + 2
                }

                context.textPosition = CGPoint(x: pageNumX, y: cursorY)
                CTLineDraw(pageLine, context)

                cursorY -= lineHeight
            }

            // Numero de pagina del TOC (romanos)
            let tocNum = tocStartPage + pageIdx + 1
            let tocNumText = romanNumeral(tocNum) as CFString
            let numAttr: [CFString: Any] = [
                kCTFontAttributeName: SystemFont.regular(size: 9 * scaleFactor),
                kCTForegroundColorAttributeName: theme.pageNumberText
            ]
            guard let numStr = CFAttributedStringCreate(nil, tocNumText, numAttr as CFDictionary) else { continue }
            let numLine = CTLineCreateWithAttributedString(numStr)
            let numWidth = CTLineGetTypographicBounds(numLine, nil, nil, nil)
            context.textPosition = CGPoint(x: (geometry.pageWidth - numWidth) / 2.0, y: geometry.marginBottom * 0.4)
            CTLineDraw(numLine, context)
        }

        return totalPages
    }

    private static func draw(page: MarkdownPage, geometry: MarkdownPageGeometry, in context: CGContext, baseURL: URL?, theme: MarkdownPrintTheme, pageOffset: Int = 0, scaleFactor: CGFloat = 1.0, fontFamily: FontFamily = .apple, useRoman: Bool = false, showLineNumbers: Bool = false, justifyText: Bool = false, labelToNumber: [String: String] = [:], footnoteDefs: [String: String] = [:]) {
        let marginLeft = geometry.marginLeft

        // Fondo de pagina.
        context.setFillColor(theme.pageBackground)
        context.fill(CGRect(x: 0, y: 0, width: geometry.pageWidth, height: geometry.pageHeight))

        // --- Pase 1: fondos de bloques de codigo y cabeceras de tabla ---
        var codeBlockRects: [CGRect] = []
        var inCodeBlock = false
        var codeBlockTop: Double = 0
        var codeBlockBottom: Double = 0

        for element in page.elements {
            if element.isCodeBlock && element.kind == .word {
                let topY = pdfTopY(forContentY: element.y, geometry: geometry)
                let bottomY = topY - element.height
                if !inCodeBlock {
                    codeBlockTop = topY
                    codeBlockBottom = bottomY
                    inCodeBlock = true
                } else {
                    codeBlockTop = max(codeBlockTop, topY)
                    codeBlockBottom = min(codeBlockBottom, bottomY)
                }
            } else {
                if inCodeBlock {
                    let rect = CGRect(x: marginLeft - codeBlockPaddingH,
                                      y: codeBlockBottom,
                                      width: geometry.contentWidth + codeBlockPaddingH * 2,
                                      height: codeBlockTop - codeBlockBottom)
                    codeBlockRects.append(rect)
                    inCodeBlock = false
                }
            }
        }
        if inCodeBlock {
            let rect = CGRect(x: marginLeft - codeBlockPaddingH,
                              y: codeBlockBottom,
                              width: geometry.contentWidth + codeBlockPaddingH * 2,
                              height: codeBlockTop - codeBlockBottom)
            codeBlockRects.append(rect)
        }

        context.setFillColor(theme.codeBackground)
        for rect in codeBlockRects {
            let radius: CGFloat = 6.0
            let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            context.addPath(path)
            context.fillPath()
        }

        drawTableHeaderBackgrounds(page: page, geometry: geometry, in: context, theme: theme)
        drawHeadingUnderlines(page: page, geometry: geometry, in: context, theme: theme)

        // --- Pase 2: dibujar elementos estructurales y texto ---
        var lineTextElements: [MarkdownLayoutElement] = []
        var codeLineTextElements: [MarkdownLayoutElement] = []
        var rawHtmlRects: [CGRect] = []
        var inRawHtml = false
        var rawHtmlTop: Double = 0
        var rawHtmlBottom: Double = 0

        // Line number tracking for code blocks.
        var lastCodeLineY: Double? = nil
        var codeLineNumber = 0
        let lineNumFont = SystemFont.regular(size: 9)
        let lineNumColor = theme.mutedText

        func flushRawHtml() {
            if inRawHtml {
                let rect = CGRect(x: geometry.marginLeft,
                                  y: rawHtmlBottom,
                                  width: geometry.contentWidth,
                                  height: rawHtmlTop - rawHtmlBottom)
                rawHtmlRects.append(rect)
                inRawHtml = false
            }
        }

        for element in page.elements {
            switch element.kind {
            case .horizontalRule:
                flushRawHtml()
                drawRule(element, geometry: geometry, in: context, theme: theme)
            case .tableGridLine:
                flushRawHtml()
                drawGridLine(element, geometry: geometry, in: context, theme: theme)
            case .image:
                flushRawHtml()
                drawImage(element, geometry: geometry, in: context, baseURL: baseURL, theme: theme)
            case .rawHtml:
                let topY = pdfTopY(forContentY: element.y, geometry: geometry)
                let bottomY = topY - element.height
                if !inRawHtml {
                    rawHtmlTop = topY
                    rawHtmlBottom = bottomY
                    inRawHtml = true
                } else {
                    rawHtmlTop = max(rawHtmlTop, topY)
                    rawHtmlBottom = min(rawHtmlBottom, bottomY)
                }
                drawWord(element, geometry: geometry, in: context, theme: theme, fontFamily: fontFamily)
            case .mathBlock:
                flushRawHtml()
                drawMathElement(element, geometry: geometry, in: context, theme: theme, scaleFactor: scaleFactor)
            case .footnoteRef:
                flushRawHtml()
                drawFootnoteRef(element, geometry: geometry, in: context, theme: theme)
            case .word:
                flushRawHtml()
                // Resolve cross-reference text before drawing.
                let resolvedText: String
                if !element.crossRefLabel.isEmpty, let number = labelToNumber[element.crossRefLabel] {
                    resolvedText = "Section \(number)"
                } else {
                    resolvedText = element.text
                }
                if element.isTableCell || element.isCodeBlock {
                    // Line numbers for code blocks.
                    if showLineNumbers && element.isCodeBlock {
                        if lastCodeLineY != element.y {
                            lastCodeLineY = element.y
                            codeLineNumber += 1
                            let numStr = "\(codeLineNumber)" as CFString
                            let attr: [CFString: Any] = [
                                kCTFontAttributeName: lineNumFont,
                                kCTForegroundColorAttributeName: lineNumColor
                            ]
                            if let aStr = CFAttributedStringCreate(nil, numStr, attr as CFDictionary) {
                                let ln = CTLineCreateWithAttributedString(aStr)
                                let lnW = CTLineGetTypographicBounds(ln, nil, nil, nil)
                                let topY = pdfTopY(forContentY: element.y, geometry: geometry)
                                let ascent = CTFontGetAscent(lineNumFont)
                                let lnX = geometry.marginLeft - lnW - 10
                                let lnY = topY - ascent
                                context.textPosition = CGPoint(x: lnX, y: lnY)
                                CTLineDraw(ln, context)
                            }
                        }
                    }
                    if element.isCodeBlock {
                        codeLineTextElements.append(element.withText(resolvedText))
                    } else {
                        drawWord(element.withText(resolvedText), geometry: geometry, in: context, theme: theme, scaleFactor: scaleFactor, fontFamily: fontFamily)
                    }
                } else {
                    lineTextElements.append(element.withText(resolvedText))
                }
            }
        }
        flushRawHtml()

        // Dibujar fondos de bloques HTML raw.
        if let fadedBg = theme.codeBackground.copy(alpha: 0.6) {
            context.setFillColor(fadedBg)
        } else {
            context.setFillColor(theme.codeBackground)
        }
        for rect in rawHtmlRects {
            let radius: CGFloat = 4.0
            let path = CGPath(roundedRect: rect.insetBy(dx: -2, dy: -2), cornerWidth: radius, cornerHeight: radius, transform: nil)
            context.addPath(path)
            context.fillPath()
        }

        let groupedLines = Dictionary(grouping: lineTextElements) { $0.y }
        for y in groupedLines.keys.sorted() {
            guard let line = groupedLines[y] else { continue }
            drawTextLine(line, geometry: geometry, in: context, theme: theme, scaleFactor: scaleFactor, fontFamily: fontFamily, justifyText: justifyText)
        }
        let groupedCodeLines = Dictionary(grouping: codeLineTextElements) { $0.y }
        for y in groupedCodeLines.keys.sorted() {
            guard let line = groupedCodeLines[y] else { continue }
            drawTextLine(line, geometry: geometry, in: context, theme: theme, scaleFactor: scaleFactor, fontFamily: fontFamily)
        }

        // --- Footnotes at page bottom ---
        if !footnoteDefs.isEmpty {
            var pageLabels: [String] = []
            for el in page.elements where !el.footnoteLabel.isEmpty {
                if !pageLabels.contains(el.footnoteLabel) {
                    pageLabels.append(el.footnoteLabel)
                }
            }
            if !pageLabels.isEmpty {
                drawPageFootnotes(pageLabels, footnoteDefs, geometry: geometry, in: context, theme: theme)
            }
        }

        // --- Numero de pagina al pie ---
        drawPageNumber(page: page, geometry: geometry, in: context, theme: theme, pageOffset: pageOffset, useRoman: useRoman)
    }

    private static func pdfTopY(forContentY y: Double, geometry: MarkdownPageGeometry) -> Double {
        geometry.pageHeight - geometry.marginTop - y
    }

    private static func drawTableHeaderBackgrounds(page: MarkdownPage, geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme) {
        let headerWords = page.elements.filter { $0.isTableCell && $0.style == .bold && $0.kind == .word }
        guard !headerWords.isEmpty else { return }
        let horizontalLines = page.elements.filter { $0.kind == .tableGridLine && $0.width > $0.height }.sorted { $0.y < $1.y }
        guard horizontalLines.count >= 2 else { return }
        let headerRows = Set(headerWords.map(\.y))
        var paintedRects = Set<String>()
        context.setFillColor(theme.tableHeaderBackground)
        for headerY in headerRows.sorted() {
            guard let topLine = horizontalLines.last(where: { $0.y <= headerY }),
                  let bottomLine = horizontalLines.first(where: { $0.y > headerY }) else { continue }
            let key = "\(topLine.y)-\(bottomLine.y)"
            guard !paintedRects.contains(key) else { continue }
            paintedRects.insert(key)
            let topY = pdfTopY(forContentY: topLine.y, geometry: geometry)
            let bottomY = pdfTopY(forContentY: bottomLine.y, geometry: geometry)
            let rect = CGRect(x: geometry.marginLeft + topLine.x, y: bottomY, width: topLine.width, height: topY - bottomY)
            context.fill(rect)
        }
    }

    private static func drawHeadingUnderlines(page: MarkdownPage, geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme) {
        let headingWords = page.elements.filter { $0.headingLevel == 1 && $0.kind == .word }
        let headingLines = Dictionary(grouping: headingWords) { $0.y }
        let sortedLines: [(y: Double, words: [MarkdownLayoutElement])] = headingLines.keys.sorted().compactMap { y in
            guard let words = headingLines[y], let first = words.first else { return nil }
            return (y, [first])
        }
        var previousY: Double?
        var previousHeight: Double = 0
        var underlineY: Double?
        func drawCurrentUnderline() {
            guard let underlineY else { return }
            context.setFillColor(theme.headingUnderline)
            context.fill(CGRect(x: geometry.marginLeft, y: underlineY, width: geometry.contentWidth, height: 0.5))
        }
        for line in sortedLines {
            guard let first = line.words.first else { continue }
            let continuesPrevious = previousY.map { line.y - $0 <= previousHeight * 1.25 } == true
            if !continuesPrevious { drawCurrentUnderline() }
            let y = pdfTopY(forContentY: first.y, geometry: geometry)
            underlineY = y - first.height - 3.0
            previousY = line.y
            previousHeight = first.height
        }
        drawCurrentUnderline()
    }

    private static func drawPageNumber(page: MarkdownPage, geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme, pageOffset: Int = 0, useRoman: Bool = false) {
        let num = page.pageNumber + pageOffset
        let text: String
        if useRoman {
            text = romanNumeral(num) as CFString as String
        } else {
            text = "\(num)"
        }
        let cfText = text as CFString
        let font = SystemFont.regular(size: 9)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: theme.pageNumberText
        ]
        guard let attrStr = CFAttributedStringCreate(nil, cfText, attributes as CFDictionary) else { return }
        let line = CTLineCreateWithAttributedString(attrStr)
        let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        let x = (geometry.pageWidth - lineWidth) / 2.0
        let y = geometry.marginBottom * 0.4
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    private static func drawRule(_ element: MarkdownLayoutElement, geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme) {
        let topY = pdfTopY(forContentY: element.y, geometry: geometry)
        let rect = CGRect(x: geometry.marginLeft + element.x, y: topY - element.height, width: element.width, height: element.height)
        // Barras estrechas (< 10pt ancho) son barras de blockquote; usar blockquoteBar
        let isBlockquoteBar = element.width < 10.0
        context.setFillColor(isBlockquoteBar ? theme.blockquoteBar : theme.border)
        context.fill(rect)
    }

    private static func drawGridLine(_ element: MarkdownLayoutElement, geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme) {
        let topY = pdfTopY(forContentY: element.y, geometry: geometry)
        let rect = CGRect(x: geometry.marginLeft + element.x, y: topY - element.height, width: element.width, height: element.height)
        context.setFillColor(theme.gridLine)
        context.fill(rect)
    }

    private static func drawImage(_ element: MarkdownLayoutElement, geometry: MarkdownPageGeometry, in context: CGContext, baseURL: URL?, theme: MarkdownPrintTheme) {
        let topY = pdfTopY(forContentY: element.y, geometry: geometry)
        let outerRect = CGRect(x: geometry.marginLeft + element.x, y: topY - element.height, width: element.width, height: element.height)
        let insetRect = outerRect.insetBy(dx: 0, dy: 6)
        guard let image = loadImage(from: element.url, baseURL: baseURL) else {
            drawImagePlaceholder(element, rect: insetRect, in: context, theme: theme)
            return
        }
        let imageSize = CGSize(width: image.width, height: image.height)
        guard imageSize.width > 0 && imageSize.height > 0 else {
            drawImagePlaceholder(element, rect: insetRect, in: context, theme: theme)
            return
        }
        let scale = min(insetRect.width / imageSize.width, insetRect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(x: insetRect.midX - drawSize.width / 2, y: insetRect.midY - drawSize.height / 2, width: drawSize.width, height: drawSize.height)
        context.saveGState()
        context.clip(to: insetRect)
        context.draw(image, in: drawRect)
        context.restoreGState()

        // Alt text como caption bajo la imagen.
        if !element.text.isEmpty {
            let captionFont = SystemFont.regular(size: 9)
            let captionAttr: [CFString: Any] = [
                kCTFontAttributeName: captionFont,
                kCTForegroundColorAttributeName: theme.mutedText
            ]
            guard let captionStr = CFAttributedStringCreate(nil, element.text as CFString, captionAttr as CFDictionary) else { return }
            let captionLine = CTLineCreateWithAttributedString(captionStr)
            let captionWidth = CTLineGetTypographicBounds(captionLine, nil, nil, nil)
            let captionX = insetRect.midX - captionWidth / 2
            let captionY = insetRect.minY - CTFontGetAscent(captionFont) - 4
            // Only draw if there's room below the image.
            if captionY > geometry.marginBottom {
                context.textPosition = CGPoint(x: captionX, y: captionY)
                CTLineDraw(captionLine, context)
            }
        }
    }

    private static func drawImagePlaceholder(_ element: MarkdownLayoutElement, rect: CGRect, in context: CGContext, theme: MarkdownPrintTheme) {
        context.setFillColor(theme.codeBackground)
        context.fill(rect)
        context.setStrokeColor(theme.border)
        context.stroke(rect, width: 0.7)
        let label = element.text.isEmpty ? "Image unavailable" : element.text
        let font = SystemFont.regular(size: 11)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: theme.mutedText
        ]
        guard let attrStr = CFAttributedStringCreate(nil, label as CFString, attributes as CFDictionary) else { return }
        let line = CTLineCreateWithAttributedString(attrStr)
        let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        let x = rect.minX + max(8, (rect.width - lineWidth) / 2)
        let y = rect.midY - 4
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    private static func drawMathElement(_ element: MarkdownLayoutElement, geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme, scaleFactor: CGFloat = 1.0) {
        let topY = pdfTopY(forContentY: element.y, geometry: geometry)

        // Intenta renderizar con LaTeX primero. Si no hay pdflatex o falla,
        // cae en el renderizado de texto estilizado.
        if let mathPage = MathRenderer.render(element.text, displayStyle: element.kind == .mathBlock) {
            let pageRect = mathPage.getBoxRect(.mediaBox)
            let scaleX = element.width > 0 ? CGFloat(element.width) / pageRect.width : 1.0
            let scaleY = element.height > 0 ? CGFloat(element.height) / pageRect.height : 1.0
            let scale = min(scaleX, scaleY, 2.0) // No ampliar mas de 2x

            let drawWidth = pageRect.width * scale
            let drawHeight = pageRect.height * scale
            let drawRect = CGRect(
                x: geometry.marginLeft + element.x,
                y: topY - drawHeight,
                width: drawWidth,
                height: drawHeight
            )

            context.saveGState()
            // Fondo sutil para distinguir el bloque matematico.
            let mathBg = theme.codeBackground.copy(alpha: 0.2) ?? theme.codeBackground
            context.setFillColor(mathBg)
            let bgRect = drawRect.insetBy(dx: -4, dy: -4)
            let path = CGPath(roundedRect: bgRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
            context.addPath(path)
            context.fillPath()

            context.clip(to: drawRect)
            context.translateBy(x: drawRect.minX, y: drawRect.minY)
            context.scaleBy(x: scale, y: scale)
            context.drawPDFPage(mathPage)
            context.restoreGState()
            return
        }

        // Fallback: renderizado de texto estilizado.
        let font = SystemFont.monospace(size: CGFloat(element.fontSize) * scaleFactor)
        let padH: CGFloat = 4.0

        // Fondo sutil
        let bgRect = CGRect(x: geometry.marginLeft + element.x - padH,
                            y: topY - element.height,
                            width: element.width + padH * 2,
                            height: element.height)
        let mathBg = theme.codeBackground.copy(alpha: 0.3) ?? theme.codeBackground
        context.setFillColor(mathBg)
        context.fill(bgRect)

        // Borde izquierdo sutil
        context.setFillColor(theme.linkText)
        context.fill(CGRect(x: bgRect.minX, y: bgRect.minY, width: 2.0, height: bgRect.height))

        // Texto
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: theme.text
        ]
        guard let attrStr = CFAttributedStringCreate(nil, element.text as CFString, attributes as CFDictionary) else { return }
        let line = CTLineCreateWithAttributedString(attrStr)
        let ascent = CTFontGetAscent(font)
        let baselineY = topY - ascent
        context.textPosition = CGPoint(x: geometry.marginLeft + element.x + 2, y: baselineY)
        CTLineDraw(line, context)
    }

    private static func drawFootnoteRef(_ element: MarkdownLayoutElement, geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme) {
        let topY = pdfTopY(forContentY: element.y, geometry: geometry)
        let font = SystemFont.regular(size: CGFloat(element.fontSize * 0.75))
        let ascent = CTFontGetAscent(font)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: theme.linkText
        ]
        guard let attrStr = CFAttributedStringCreate(nil, element.text as CFString, attributes as CFDictionary) else { return }
        let line = CTLineCreateWithAttributedString(attrStr)
        let x = geometry.marginLeft + element.x
        let y = topY - ascent * 0.5 // superscript: above baseline
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    private static func drawEndnotes(_ footnoteDefs: [String: String], geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme, scaleFactor: CGFloat = 1.0, fontFamily: FontFamily = .apple) {
        context.beginPDFPage(nil)

        let font = SystemFont.bold(size: 14 * scaleFactor)
        let bodyFont = SystemFont.regular(size: 11 * scaleFactor)
        let lineH: CGFloat = 18.0 * scaleFactor
        let marginLeft = geometry.marginLeft
        var cursorY = geometry.pageHeight - geometry.marginTop

        // Section title.
        let titleAttr: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: theme.text
        ]
        guard let titleStr = CFAttributedStringCreate(nil, "Notas" as CFString, titleAttr as CFDictionary) else { return }
        let titleLine = CTLineCreateWithAttributedString(titleStr)
        context.textPosition = CGPoint(x: marginLeft, y: cursorY - CTFontGetAscent(font))
        CTLineDraw(titleLine, context)
        cursorY -= CTFontGetAscent(font) + 12

        // Separator line.
        context.setFillColor(theme.border)
        context.fill(CGRect(x: marginLeft, y: cursorY, width: geometry.contentWidth * 0.33, height: 1.0))
        cursorY -= 8

        // Definitions sorted by label.
        let sortedLabels = footnoteDefs.keys.sorted { a, b in
            let na = Int(a) ?? 0, nb = Int(b) ?? 0
            return na < nb || (na == nb && a < b)
        }

        for label in sortedLabels {
            guard let def = footnoteDefs[label] else { continue }

            if cursorY - lineH < geometry.marginBottom {
                context.endPDFPage()
                context.beginPDFPage(nil)
                cursorY = geometry.pageHeight - geometry.marginTop
            }

            let numberText = "[\(label)] "
            let defText = numberText + def
            guard let defAttrStr = CFAttributedStringCreate(nil, defText as CFString, [
                kCTFontAttributeName: bodyFont,
                kCTForegroundColorAttributeName: theme.text
            ] as CFDictionary) else { continue }

            let defLine = CTLineCreateWithAttributedString(defAttrStr)
            context.textPosition = CGPoint(x: marginLeft, y: cursorY - CTFontGetAscent(bodyFont))
            CTLineDraw(defLine, context)
            cursorY -= lineH
        }

        context.endPDFPage()
    }

    private static func drawWatermark(_ watermark: Watermark, geometry: MarkdownPageGeometry, in context: CGContext) {
        context.saveGState()
        context.setAlpha(watermark.opacity)

        switch watermark.kind {
        case .text(let text):
            let font = SystemFont.bold(size: watermark.fontSize)
            let attr: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: watermark.color
            ]
            guard let aStr = CFAttributedStringCreate(nil, text as CFString, attr as CFDictionary) else {
                context.restoreGState(); return
            }
            let line = CTLineCreateWithAttributedString(aStr)
            let tw = CTLineGetTypographicBounds(line, nil, nil, nil)
            let cx = geometry.pageWidth / 2.0
            let cy = geometry.pageHeight / 2.0

            context.translateBy(x: cx, y: cy)
            context.rotate(by: watermark.angle * .pi / 180.0)
            context.textPosition = CGPoint(x: -tw / 2.0, y: -watermark.fontSize / 2.0)
            CTLineDraw(line, context)

        case .image(let url):
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                context.restoreGState(); return
            }
            let iw = CGFloat(image.width)
            let ih = CGFloat(image.height)
            let maxDim = min(geometry.pageWidth, geometry.pageHeight) * 0.4
            let scale = min(maxDim / iw, maxDim / ih, 1.0)
            let dw = iw * scale
            let dh = ih * scale
            let rect = CGRect(x: (geometry.pageWidth - dw) / 2.0,
                              y: (geometry.pageHeight - dh) / 2.0,
                              width: dw, height: dh)
            context.draw(image, in: rect)
        }

        context.restoreGState()
    }

    private static func drawHeaderFooter(_ hf: PageHeaderFooter, page: MarkdownPage, geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme, metadata: PDFMetadata, pageOffset: Int, totalPages: Int, labelToNumber: [String: String]) {
        let font = SystemFont.regular(size: hf.fontSize)
        let color = hf.color ?? theme.mutedText
        let attr: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]

        // Resolve placeholders.
        func resolve(_ template: String?) -> String? {
            guard let t = template else { return nil }
            var result = t
            result = result.replacingOccurrences(of: "{page}", with: "\(page.pageNumber + pageOffset)")
            result = result.replacingOccurrences(of: "{total}", with: "\(totalPages)")
            result = result.replacingOccurrences(of: "{title}", with: metadata.title ?? "")
            // Find the first heading on this page for {section}.
            if result.contains("{section}") {
                var sectionText = ""
                for el in page.elements where el.headingLevel > 0 && el.headingLevel <= 2 {
                    sectionText = el.text
                    // Resolve cross-refs in section text.
                    if !el.crossRefLabel.isEmpty, let num = labelToNumber[el.crossRefLabel] {
                        sectionText = "Section \(num)"
                    }
                    // Reconstruct heading from all words on the same line.
                    let headingWords = page.elements.filter { $0.headingLevel == el.headingLevel && $0.y == el.y }
                        .sorted { $0.x < $1.x }
                    sectionText = headingWords.map(\.text).joined(separator: " ")
                    break
                }
                result = result.replacingOccurrences(of: "{section}", with: sectionText)
            }
            return result
        }

        // Draw header.
        if let headerText = resolve(hf.header), !headerText.isEmpty,
           let aStr = CFAttributedStringCreate(nil, headerText as CFString, attr as CFDictionary) {
            let line = CTLineCreateWithAttributedString(aStr)
            let tw = CTLineGetTypographicBounds(line, nil, nil, nil)
            let x = (geometry.pageWidth - tw) / 2.0
            let y = geometry.pageHeight - geometry.marginTop + 15
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        }

        // Draw footer.
        if let footerText = resolve(hf.footer), !footerText.isEmpty,
           let aStr = CFAttributedStringCreate(nil, footerText as CFString, attr as CFDictionary) {
            let line = CTLineCreateWithAttributedString(aStr)
            let tw = CTLineGetTypographicBounds(line, nil, nil, nil)
            let x = (geometry.pageWidth - tw) / 2.0
            let y = geometry.marginBottom * 0.5
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        }
    }

    private static func drawPageFootnotes(_ labels: [String], _ defs: [String: String], geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme) {
        let font = SystemFont.regular(size: 8)
        let lineH: CGFloat = 12
        let marginLeft = geometry.marginLeft
        let separatorY = geometry.marginBottom + 30

        // Separator line
        context.setFillColor(theme.border)
        context.fill(CGRect(x: marginLeft, y: separatorY, width: geometry.contentWidth * 0.25, height: 0.5))

        var cursorY = separatorY - 6
        for label in labels {
            guard let def = defs[label], cursorY > geometry.marginBottom else { break }
            let text = "[\(label)] \(def)" as CFString
            let attr: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: theme.mutedText]
            guard let aStr = CFAttributedStringCreate(nil, text, attr as CFDictionary) else { continue }
            let line = CTLineCreateWithAttributedString(aStr)
            context.textPosition = CGPoint(x: marginLeft, y: cursorY)
            CTLineDraw(line, context)
            cursorY -= lineH
        }
    }

    private static func loadImage(from source: String, baseURL: URL?) -> CGImage? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("data:image/"),
           let comma = trimmed.firstIndex(of: ",") {
            let metadata = trimmed[..<comma].lowercased()
            let payload = String(trimmed[trimmed.index(after: comma)...])
            guard metadata.contains(";base64"), let data = Data(base64Encoded: payload) else { return nil }
            return imageFromData(data)
        }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") { return nil }
        let imageURL: URL
        if trimmed.hasPrefix("/") {
            imageURL = URL(fileURLWithPath: trimmed)
        } else if let url = URL(string: trimmed), url.isFileURL || url.scheme != nil {
            imageURL = url
        } else if let baseURL {
            imageURL = baseURL.appendingPathComponent(trimmed)
        } else {
            imageURL = URL(fileURLWithPath: trimmed)
        }
        guard let data = try? Data(contentsOf: imageURL) else {
            Logger.markdownPrint.warning("Could not load image at \(imageURL.path)")
            return nil
        }
        return imageFromData(data)
    }

    private static func imageFromData(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    // MARK: - Word drawing

    private static func drawWord(_ element: MarkdownLayoutElement, geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme, scaleFactor: CGFloat = 1.0, textOverride: String? = nil) {
        drawWord(element, geometry: geometry, in: context, xOverride: nil, widthOverride: nil, theme: theme, scaleFactor: scaleFactor)
    }

    private static func drawTextLine(_ elements: [MarkdownLayoutElement], geometry: MarkdownPageGeometry, in context: CGContext, theme: MarkdownPrintTheme, scaleFactor: CGFloat = 1.0, fontFamily: FontFamily = .apple, justifyText: Bool = false) {
        let sorted = elements.sorted { $0.x < $1.x }
        guard !sorted.isEmpty else { return }
        let measuredWidths = sorted.map { textWidth(for: $0, theme: theme, fontFamily: fontFamily) }
        let naturalRight = zip(sorted, measuredWidths).map { CGFloat($0.0.x) + $0.1 }.max() ?? 0
        let shouldJustify = justifyText && sorted.count > 1 && naturalRight >= CGFloat(geometry.contentWidth) * 0.96
        let naturalTotalWidth = measuredWidths.reduce(0, +) + CGFloat(max(0, sorted.count - 1)) * spaceWidth(for: sorted[0], theme: theme, fontFamily: fontFamily)
        let extraGap = shouldJustify && sorted.count > 1
            ? max(0, CGFloat(geometry.contentWidth) - naturalTotalWidth) / CGFloat(sorted.count - 1)
            : 0
        var previousEnd: CGFloat?

        for (index, element) in sorted.enumerated() {
            let measuredWidth = textWidth(for: element, theme: theme, fontFamily: fontFamily)
            let naturalX = CGFloat(element.x)
            let x: CGFloat
            if let end = previousEnd {
                let previous = sorted[index - 1]
                let isOrderedMarker = previous.text.hasSuffix(".") &&
                    previous.text.dropLast().allSatisfy(\.isNumber)
                let isListContinuation = (previous.text == "\u{2022}" || isOrderedMarker) &&
                    previous.x < 8 && naturalX > end + 8
                x = isListContinuation ? naturalX : end + spaceWidth(for: element, theme: theme, fontFamily: fontFamily) + extraGap
            } else {
                x = naturalX
            }
            drawWord(element, geometry: geometry, in: context, xOverride: Double(x), widthOverride: Double(measuredWidth), theme: theme, scaleFactor: scaleFactor, fontFamily: fontFamily)
            previousEnd = x + measuredWidth
        }
    }

    private static func textWidth(for element: MarkdownLayoutElement, theme: MarkdownPrintTheme, fontFamily: FontFamily = .apple) -> CGFloat {
        let font = SystemFont.font(forStyle: element.style, headingLevel: element.headingLevel, size: CGFloat(element.fontSize), family: fontFamily)
        var attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTLigatureAttributeName: 1
        ]
        if element.headingLevel >= 1 && element.headingLevel <= 3 {
            let kern: Double = element.headingLevel == 1 ? 0.5 : (element.headingLevel == 2 ? 0.3 : 0.15)
            attributes[kCTKernAttributeName] = NSNumber(value: kern)
        }
        if element.isTableCell {
            let features: [[CFString: Any]] = [[
                kCTFontFeatureTypeIdentifierKey: kNumberSpacingType,
                kCTFontFeatureSelectorIdentifierKey: kMonospacedNumbersSelector
            ]]
            attributes[kCTFontFeatureSettingsAttribute] = features
        }
        if theme.smallCaps && element.style == .code && !element.isCodeBlock {
            let scalars = Array(element.text.unicodeScalars)
            if scalars.count >= 2 && scalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }) {
                let scFeatures: [[CFString: Any]] = [[
                    kCTFontFeatureTypeIdentifierKey: kLetterCaseType,
                    kCTFontFeatureSelectorIdentifierKey: kSmallCapsSelector
                ]]
                if let existing = attributes[kCTFontFeatureSettingsAttribute] as? [[CFString: Any]] {
                    attributes[kCTFontFeatureSettingsAttribute] = existing + scFeatures
                } else {
                    attributes[kCTFontFeatureSettingsAttribute] = scFeatures
                }
            }
        }
        guard let attributedString = CFAttributedStringCreate(nil, element.text as CFString, attributes as CFDictionary) else {
            return CGFloat(element.width)
        }
        let line = CTLineCreateWithAttributedString(attributedString)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private static func spaceWidth(for element: MarkdownLayoutElement, theme: MarkdownPrintTheme, fontFamily: FontFamily = .apple) -> CGFloat {
        let font = SystemFont.font(forStyle: element.style, headingLevel: element.headingLevel, size: CGFloat(element.fontSize), family: fontFamily)
        let attributes: [CFString: Any] = [kCTFontAttributeName: font]
        guard let attributedString = CFAttributedStringCreate(nil, " " as CFString, attributes as CFDictionary) else { return 4 }
        let line = CTLineCreateWithAttributedString(attributedString)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private static func drawWord(_ element: MarkdownLayoutElement, geometry: MarkdownPageGeometry, in context: CGContext, xOverride: CGFloat? = nil, widthOverride: CGFloat? = nil, theme: MarkdownPrintTheme, scaleFactor: CGFloat = 1.0, fontFamily: FontFamily = .apple) {
        let scaledFontSize = CGFloat(element.fontSize) * scaleFactor
        let font = SystemFont.font(forStyle: element.style, headingLevel: element.headingLevel, size: scaledFontSize, family: fontFamily)
        var attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTLigatureAttributeName: 1
        ]

        // Kerning optico en titulos grandes (H1-H3).
        // CoreText aplica kerning metrico automatico, pero un ajuste
        // adicional mejora la lectura en cuerpos grandes.
        if element.headingLevel >= 1 && element.headingLevel <= 3 {
            let kern: Double = element.headingLevel == 1 ? 0.5 : (element.headingLevel == 2 ? 0.3 : 0.15)
            attributes[kCTKernAttributeName] = NSNumber(value: kern)
        }

        // Numeros tabulares en celdas de tabla: todos los digitos ocupan
        // el mismo ancho, alineando columnas de precios, stock, etc.
        if element.isTableCell {
            let features: [[CFString: Any]] = [[
                kCTFontFeatureTypeIdentifierKey: kNumberSpacingType,
                kCTFontFeatureSelectorIdentifierKey: kMonospacedNumbersSelector
            ]]
            attributes[kCTFontFeatureSettingsAttribute] = features
        }

        // Small caps para acronimos en inline code (HTML, API, CSS, JSON...).
        // Detectamos palabras de 2+ mayusculas consecutivas.
        if theme.smallCaps && element.style == .code && !element.isCodeBlock {
            let scalars = Array(element.text.unicodeScalars)
            if scalars.count >= 2 && scalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }) {
                let smallCapsFeatures: [[CFString: Any]] = [[
                    kCTFontFeatureTypeIdentifierKey: kLetterCaseType,
                    kCTFontFeatureSelectorIdentifierKey: kSmallCapsSelector
                ]]
                if let existingFeatures = attributes[kCTFontFeatureSettingsAttribute] as? [[CFString: Any]] {
                    attributes[kCTFontFeatureSettingsAttribute] = existingFeatures + smallCapsFeatures
                } else {
                    attributes[kCTFontFeatureSettingsAttribute] = smallCapsFeatures
                }
            }
        }

        // Color segun estilo
        if element.isCodeBlock && theme.syntaxHighlight {
            attributes[kCTForegroundColorAttributeName] = SyntaxHighlighter.color(for: element.text)
        } else {
            switch element.style {
        case .link:         attributes[kCTForegroundColorAttributeName] = theme.linkText
        case .code:         attributes[kCTForegroundColorAttributeName] = theme.codeText
        case .strikethrough: attributes[kCTForegroundColorAttributeName] = theme.mutedText
        case .inlineMath:
            attributes[kCTFontAttributeName] = SystemFont.monospace(size: CGFloat(element.fontSize))
            attributes[kCTForegroundColorAttributeName] = theme.linkText
        default:
            if element.headingLevel == 6 || element.isBlockquote {
                attributes[kCTForegroundColorAttributeName] = theme.mutedText
            } else {
                attributes[kCTForegroundColorAttributeName] = theme.text
            }
            }
        }

        // Fondo de codigo inline
        var bgRect: CGRect?
        if element.style == .code && !element.isCodeBlock {
            let topY = pdfTopY(forContentY: element.y, geometry: geometry)
            let bgX = (xOverride ?? CGFloat(element.x)) - 3
            let bgW = (widthOverride ?? CGFloat(element.width)) + 6
            bgRect = CGRect(x: geometry.marginLeft + bgX,
                            y: topY - CGFloat(element.height),
                            width: bgW,
                            height: CGFloat(element.height))
        }
        if element.style == .inlineMath {
            let topY = pdfTopY(forContentY: element.y, geometry: geometry)
            let bgX = (xOverride ?? CGFloat(element.x)) - 2
            let bgW = (widthOverride ?? CGFloat(element.width)) + 4
            bgRect = CGRect(x: geometry.marginLeft + bgX,
                            y: topY - CGFloat(element.height),
                            width: bgW,
                            height: CGFloat(element.height))
        }

        if let bgRect {
            context.setFillColor(theme.inlineCodeBackground)
            let radius: CGFloat = 3.0
            let path = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            context.addPath(path)
            context.fillPath()
        }

        guard let attrStr = CFAttributedStringCreate(nil, element.text as CFString, attributes as CFDictionary) else { return }
        let line = CTLineCreateWithAttributedString(attrStr)
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let topY = pdfTopY(forContentY: element.y, geometry: geometry)
        let drawWidth = widthOverride ?? CGFloat(element.width)
        let drawX = xOverride ?? CGFloat(element.x)
        // Medir con CoreText el ancho real (puede ser mayor que element.width aproximado)
        let ctWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        let actualWidth = max(CGFloat(ctWidth), drawWidth)
        let available = max(0, geometry.contentWidth - drawX)
        let overflows = actualWidth > available || drawX + actualWidth > geometry.contentWidth

        if overflows {
            context.saveGState()
            context.clip(to: CGRect(x: geometry.marginLeft, y: topY - element.height - 5, width: geometry.contentWidth, height: element.height + 10))
        }

        let baselineY = topY - ascent
        context.textPosition = CGPoint(x: geometry.marginLeft + drawX, y: baselineY)
        CTLineDraw(line, context)

        // Subrayado en enlaces
        if element.style == .link && theme.underlineLinks {
            let underlineY = topY - ascent + descent + 0.5
            context.setFillColor(theme.linkText)
            context.fill(CGRect(x: geometry.marginLeft + drawX, y: underlineY, width: drawWidth, height: 0.7))
        }

        // Tachado
        if element.style == .strikethrough {
            let midY = topY - element.height / 2
            if let xOvr = xOverride {
                context.setFillColor(theme.mutedText)
                context.fill(CGRect(x: geometry.marginLeft + xOvr, y: midY, width: drawWidth, height: 0.7))
            }
        }

        if overflows {
            context.restoreGState()
        }
    }
}

// MARK: - Helpers

/// Converts an integer to a Roman numeral string.
/// 1 -> I, 4 -> IV, 9 -> IX, 42 -> XLII, etc.
private func romanNumeral(_ n: Int) -> String {
    guard n > 0 && n < 4000 else { return "\(n)" }
    let values = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
                  (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
                  (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
    var result = ""
    var remaining = n
    for (value, symbol) in values {
        while remaining >= value {
            result += symbol
            remaining -= value
        }
    }
    return result
}
