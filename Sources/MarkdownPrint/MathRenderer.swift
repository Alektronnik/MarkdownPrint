import CoreGraphics
import CoreText
import Foundation
import PDFKit
import CMarkdownPrintCore
import MarkdownPrintCore

enum MathRenderer {

    static let isAvailable: Bool = true

    static func render(
        _ latex: String,
        displayStyle: Bool = false,
        baseFontSize: CGFloat = 12.0
    ) -> CGPDFPage? {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let engine = mdcore.Engine(std.string("en"))
        let cppLayout = engine.layoutMath(std.string(trimmed), displayStyle, Double(baseFontSize))

        let glyphCount = Int(cppLayout.glyphs.size())
        guard glyphCount > 0 else { return nil }

        var glyphs: [MathGlyph] = []
        glyphs.reserveCapacity(glyphCount)
        for g in cppLayout.glyphs {
            glyphs.append(MathGlyph(
                x: g.x, y: g.y, width: g.width, height: g.height,
                depth: g.depth, fontSize: g.fontSize,
                unicode: String(g.unicode), text: String(g.text),
                isRule: g.isRule, isRadical: g.isRadical,
                radicalContentHeight: g.radicalContentHeight,
                radicalContentWidth: g.radicalContentWidth
            ))
        }

        let totalW = cppLayout.totalWidth
        let totalH = cppLayout.totalHeight
        let totalD = cppLayout.totalDepth

        let padX: CGFloat = 8.0
        let padY: CGFloat = 6.0
        let pdfW = CGFloat(totalW) + padX * 2
        let pdfH = CGFloat(totalH + totalD) + padY * 2
        guard pdfW > 0 && pdfH > 0 else { return nil }

        var mediaBox = CGRect(x: 0, y: 0, width: pdfW, height: pdfH)
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        context.setFillColor(CGColor.white)
        context.fill(mediaBox)

        let baselinePDFY = padY + CGFloat(totalD)

        for glyph in glyphs {
            if glyph.isRule {
                let ruleRect = CGRect(
                    x: padX + CGFloat(glyph.x),
                    y: baselinePDFY + CGFloat(glyph.y),
                    width: CGFloat(glyph.width),
                    height: max(CGFloat(glyph.height), 1.0)
                )
                context.setFillColor(CGColor.black)
                context.fill(ruleRect)
            } else {
                let unicode = glyph.unicode
                guard !unicode.isEmpty else { continue }
                let fontSize = CGFloat(glyph.fontSize)
                let font = SystemFont.regular(size: fontSize)
                let attrStr = NSAttributedString(
                    string: unicode,
                    attributes: [.font: font, .foregroundColor: CGColor.black]
                )
                let line = CTLineCreateWithAttributedString(attrStr)
                let x = padX + CGFloat(glyph.x)
                let y = baselinePDFY + CGFloat(glyph.y)
                context.textPosition = CGPoint(x: x, y: y)
                CTLineDraw(line, context)
            }
        }

        context.closePDF()

        guard let provider = CGDataProvider(data: pdfData as CFData),
              let pdfDoc = CGPDFDocument(provider) else {
            return nil
        }
        return pdfDoc.page(at: 1)
    }
}

private struct MathGlyph {
    let x, y, width, height, depth, fontSize: Double
    let unicode, text: String
    let isRule, isRadical: Bool
    let radicalContentHeight, radicalContentWidth: Double
}
