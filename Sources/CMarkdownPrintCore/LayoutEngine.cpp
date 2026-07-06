#include "LayoutEngine.hpp"
#include "Hyphenator.hpp"
#include "InlineParser.hpp"

#include <cctype>
#include <functional>

namespace mdcore {

namespace {

struct StyledWord {
    std::string text;
    InlineKind style = InlineKind::PlainText;
    std::string url;
    std::string footnoteLabel; // For FootnoteRef
    std::string crossRefLabel; // For CrossRef
    bool spaceBefore = false;
    bool isImage = false;
    bool isHardBreak = false;
};

// Aplana los fragmentos con énfasis de un bloque en una secuencia de
// palabras con estilo, recordando si cada palabra llevaba un espacio
// delante en el texto original (para no perder ni inventar espacios
// al reconstruir la línea, incluso cuando una palabra y la puntuación
// que la sigue vienen de fragmentos con estilos distintos, p. ej.
// "**negrita**,").
std::vector<StyledWord> wordsFromInlines(const std::vector<InlineRun>& inlines) {
    std::vector<StyledWord> words;
    bool pendingSpaceBefore = false;

    for (const auto& run : inlines) {
        if (run.kind == InlineKind::Image) {
            StyledWord image;
            image.text = run.text;
            image.style = InlineKind::Image;
            image.url = run.url;
            image.spaceBefore = words.empty() ? false : pendingSpaceBefore;
            image.isImage = true;
            words.push_back(std::move(image));
            pendingSpaceBefore = true;
            continue;
        }

        if (run.kind == InlineKind::HardBreak) {
            StyledWord hb;
            hb.style = InlineKind::HardBreak;
            hb.isHardBreak = true;
            hb.spaceBefore = words.empty() ? false : pendingSpaceBefore;
            words.push_back(std::move(hb));
            pendingSpaceBefore = false;
            continue;
        }

        if (run.kind == InlineKind::InlineMath) {
            const std::string& mathText = run.text;
            StyledWord mw;
            mw.text = "$" + mathText + "$";
            mw.style = InlineKind::InlineMath;
            mw.spaceBefore = words.empty() ? false : pendingSpaceBefore;
            words.push_back(std::move(mw));
            pendingSpaceBefore = true;
            continue;
        }

        if (run.kind == InlineKind::FootnoteRef) {
            StyledWord fn;
            fn.text = "[" + run.text + "]"; // show [label] as visible ref
            fn.style = InlineKind::FootnoteRef;
            fn.footnoteLabel = run.text;
            fn.spaceBefore = words.empty() ? false : pendingSpaceBefore;
            words.push_back(std::move(fn));
            pendingSpaceBefore = true;
            continue;
        }

        if (run.kind == InlineKind::CrossRef) {
            StyledWord cr;
            cr.text = run.text; // "[@sec:label]" - will be replaced by renderer
            cr.style = InlineKind::CrossRef;
            cr.crossRefLabel = run.crossRefLabel;
            cr.spaceBefore = words.empty() ? false : pendingSpaceBefore;
            words.push_back(std::move(cr));
            pendingSpaceBefore = true;
            continue;
        }

        const std::string& text = run.text;
        std::size_t i = 0;
        bool sawAnyWord = false;

        while (i < text.size()) {
            while (i < text.size() && std::isspace(static_cast<unsigned char>(text[i]))) {
                pendingSpaceBefore = true;
                ++i;
            }
            std::size_t start = i;
            while (i < text.size() && !std::isspace(static_cast<unsigned char>(text[i]))) {
                ++i;
            }
            if (i > start) {
                StyledWord word;
                word.text = text.substr(start, i - start);
                word.style = run.kind;
                word.url = run.url;
                word.spaceBefore = words.empty() ? false : pendingSpaceBefore;
                words.push_back(std::move(word));
                pendingSpaceBefore = false;
                sawAnyWord = true;
            }
        }

        if (!sawAnyWord && !text.empty()) {
            pendingSpaceBefore = true; // el fragmento era solo espacio en blanco
        }
    }

    return words;
}

struct Line {
    std::vector<StyledWord> words;
    std::vector<double> wordX; // offset x de cada palabra respecto al inicio de línea
    double width = 0;
};

std::string textFromLine(const Line& line) {
    std::string text;
    for (const auto& word : line.words) {
        if (!text.empty() && word.spaceBefore) {
            text += ' ';
        }
        text += word.text;
    }
    return text;
}

std::vector<StyledWord> splitOversizedWord(const StyledWord& word, double fontSize,
                                           double maxWidth, const FontMetrics& metrics,
                                           const Hyphenator* hyphenator) {
    std::vector<StyledWord> pieces;
    if (word.isImage) {
        pieces.push_back(word);
        return pieces;
    }
    if (word.text.empty() || metrics.widthOfText(word.text, fontSize) <= maxWidth) {
        pieces.push_back(word);
        return pieces;
    }

    // Try hyphenation first if available.
    if (hyphenator) {
        auto hPoints = hyphenator->hyphenationPoints(word.text);
        std::size_t start = 0;
        bool firstPiece = true;

        while (start < word.text.size()) {
            // Find the best hyphenation break point within maxWidth.
            std::size_t bestBreak = start; // last valid break
            std::size_t end = start;

            while (end < word.text.size()) {
                std::string candidate = word.text.substr(start, end - start + 1);
                double candWidth = metrics.widthOfText(candidate, fontSize);

                if (candWidth > maxWidth) {
                    // Candidate doesn't fit. Stop here.
                    break;
                }

                // Check if end is a valid hyphenation point.
                std::size_t hIdx = end + 1; // hyphenation point AFTER character 'end'
                if (hIdx < hPoints.size() && hPoints[hIdx] == 1) {
                    bestBreak = end + 1;
                }

                ++end;
            }

            // If no hyphenation point works, fall back to character split.
            if (bestBreak == start) {
                // Character-by-character fitting.
                end = start;
                while (end < word.text.size()) {
                    std::string candidate = word.text.substr(start, end - start + 1);
                    if (metrics.widthOfText(candidate, fontSize) > maxWidth) {
                        break;
                    }
                    ++end;
                }
                if (end == start) end = start + 1; // at least one char
                bestBreak = end;
            }

            std::string pieceText = word.text.substr(start, bestBreak - start);
            // Append hyphen to non-final fragments.
            if (bestBreak < word.text.size()) {
                // Only add hyphen if the piece + "-" fits. Otherwise trim.
                std::string withHyphen = pieceText + "-";
                if (metrics.widthOfText(withHyphen, fontSize) <= maxWidth ||
                    pieceText.size() <= 1) {
                    pieceText = withHyphen;
                }
            }

            StyledWord piece;
            piece.text = pieceText;
            piece.style = word.style;
            piece.url = word.url;
            piece.spaceBefore = firstPiece ? word.spaceBefore : false;
            piece.isImage = word.isImage;
            pieces.push_back(std::move(piece));

            start = bestBreak;
            firstPiece = false;
        }
        return pieces;
    }

    // Fallback: character splitting (original behavior).
    std::size_t start = 0;
    bool firstPiece = true;
    while (start < word.text.size()) {
        std::size_t end = start;
        std::size_t lastFit = start;
        while (end < word.text.size()) {
            std::string candidate = word.text.substr(start, end - start + 1);
            if (metrics.widthOfText(candidate, fontSize) > maxWidth) {
                break;
            }
            lastFit = end + 1;
            ++end;
        }

        if (lastFit == start) {
            lastFit = start + 1;
        }

        StyledWord piece;
        piece.text = word.text.substr(start, lastFit - start);
        piece.style = word.style;
        piece.url = word.url;
        piece.spaceBefore = firstPiece ? word.spaceBefore : false;
        piece.isImage = word.isImage;
        pieces.push_back(std::move(piece));

        start = lastFit;
        firstPiece = false;
    }

    return pieces;
}

std::vector<StyledWord> splitOversizedWords(const std::vector<StyledWord>& words, double fontSize,
                                            double maxWidth, const FontMetrics& metrics,
                                            const Hyphenator* hyphenator) {
    std::vector<StyledWord> result;
    for (const auto& word : words) {
        auto pieces = splitOversizedWord(word, fontSize, maxWidth, metrics, hyphenator);
        result.insert(result.end(), pieces.begin(), pieces.end());
    }
    return result;
}

std::vector<Line> breakIntoLines(const std::vector<StyledWord>& words, double fontSize,
                                  double maxWidth, const FontMetrics& metrics,
                                  const Hyphenator* hyphenator, bool justified) {
    std::vector<Line> lines;
    const double spaceWidth = metrics.widthOfText(" ", fontSize);

    Line current;
    auto safeWords = splitOversizedWords(words, fontSize, maxWidth, metrics, hyphenator);
    for (const auto& word : safeWords) {
        if (word.isImage) {
            if (!current.words.empty()) {
                lines.push_back(std::move(current));
                current = Line();
            }
            Line imageLine;
            imageLine.words.push_back(word);
            imageLine.wordX.push_back(0.0);
            imageLine.width = maxWidth;
            lines.push_back(std::move(imageLine));
            continue;
        }

        if (word.isHardBreak) {
            if (!current.words.empty()) {
                lines.push_back(std::move(current));
                current = Line();
            }
            continue;
        }

        double wordWidth = metrics.widthOfText(word.text, fontSize);
        double gap = (!current.words.empty() && word.spaceBefore) ? spaceWidth : 0.0;

        if (!current.words.empty() && current.width + gap + wordWidth > maxWidth) {
            lines.push_back(std::move(current));
            current = Line();
            gap = 0.0;
        }

        current.wordX.push_back(current.width + (current.words.empty() ? 0.0 : gap));
        current.width += gap + wordWidth;
        current.words.push_back(word);
    }
    if (!current.words.empty()) {
        lines.push_back(std::move(current));
    }

    // Apply justification to all lines except the last one and except
    // lines that end with a hard break or are single-word lines.
    if (justified && lines.size() >= 2) {
        for (size_t li = 0; li < lines.size() - 1; ++li) {
            auto& line = lines[li];
            if (line.words.empty()) continue;
            // Don't justify single-word lines or lines ending with hard break.
            bool lastIsHardBreak = line.words.back().isHardBreak;
            if (line.words.size() <= 1 || lastIsHardBreak) continue;

            double slack = maxWidth - line.width;
            if (slack <= 0.0) continue;

            int gaps = static_cast<int>(line.words.size()) - 1;
            if (gaps <= 0) continue;
            double extraPerGap = slack / static_cast<double>(gaps);

            // Redistribute x positions.
            double accumExtra = 0.0;
            for (size_t wi = 0; wi < line.words.size(); ++wi) {
                line.wordX[wi] += accumExtra;
                if (wi > 0 || line.wordX[wi] > 0.001) {
                    accumExtra += extraPerGap;
                }
            }
            line.width = maxWidth;
        }
    }

    return lines;
}

} // namespace

LayoutEngine::LayoutEngine(PageGeometry geometry, const FontMetrics& metrics, Typography typography,
                             const Hyphenator* hyphenator)
    : geometry_(geometry), metrics_(metrics), typography_(typography), hyphenator_(hyphenator) {}

Layout LayoutEngine::layout(const std::vector<Block>& blocks) const {
    Layout result;
    result.geometry = geometry_;
    Page page;
    page.pageNumber = 1;
    double cursorY = 0.0; // relativo al área de contenido (0 = justo bajo el margen superior)

    auto startNewPage = [&]() {
        result.pages.push_back(std::move(page));
        page = Page();
        page.pageNumber = static_cast<int>(result.pages.size()) + 1;
        cursorY = 0.0;
    };

    auto placeLine = [&](const Line& line, double x0, double fontSize, double lineH, int headingLevel, bool blockquote = false) {
        if (line.words.size() == 1 && line.words[0].isImage) {
            constexpr double defaultImageHeight = 220.0;
            double imageHeight = defaultImageHeight;
            if (cursorY + imageHeight > geometry_.contentHeight()) {
                startNewPage();
            }
            LayoutElement el;
            el.kind = LayoutElementKind::Image;
            el.x = x0;
            el.y = cursorY;
            el.width = geometry_.contentWidth() - x0;
            el.height = imageHeight;
            el.fontSize = fontSize;
            el.style = InlineKind::Image;
            el.text = line.words[0].text;
            el.url = line.words[0].url;
            el.headingLevel = headingLevel;
            el.isBlockquote = blockquote;
            el.isRTL = false;
            page.elements.push_back(std::move(el));
            cursorY += imageHeight;
            return;
        }

        if (cursorY + lineH > geometry_.contentHeight()) {
            startNewPage();
        }
        for (std::size_t i = 0; i < line.words.size(); ++i) {
            LayoutElement el;
            el.kind = (line.words[i].style == InlineKind::FootnoteRef)
                ? LayoutElementKind::FootnoteRef : LayoutElementKind::Word;
            el.x = x0 + line.wordX[i];
            el.y = cursorY;
            el.width = metrics_.widthOfText(line.words[i].text, fontSize);
            el.height = lineH;
            el.fontSize = fontSize;
            el.style = line.words[i].style;
            el.url = line.words[i].url;
            el.text = line.words[i].text;
            el.footnoteLabel = line.words[i].footnoteLabel;
            el.crossRefLabel = line.words[i].crossRefLabel;
            el.headingLevel = headingLevel;
            el.isBlockquote = blockquote;
            el.isRTL = false;
            page.elements.push_back(std::move(el));
        }
        cursorY += lineH;
    };

    auto placeParagraphLike = [&](const std::vector<InlineRun>& inlines, double fontSize,
                                   double x0, double maxWidth, int headingLevel = 0, bool blockquote = false, bool justify = false) {
        auto words = wordsFromInlines(inlines);
        if (words.empty()) {
            return;
        }
        auto lines = breakIntoLines(words, fontSize, maxWidth, metrics_, hyphenator_, justify);
        double lineH = metrics_.lineHeight(fontSize);
        for (const auto& line : lines) {
            placeLine(line, x0, fontSize, lineH, headingLevel, blockquote);
        }
    };

    auto placeListMarker = [&](const std::string& text, double fontSize, double indentX = 0.0) {
        double lineH = metrics_.lineHeight(fontSize);
        if (cursorY + lineH > geometry_.contentHeight()) {
            startNewPage();
        }
        LayoutElement marker;
        marker.kind = LayoutElementKind::Word;
        marker.x = indentX;
        marker.y = cursorY;
        marker.width = metrics_.widthOfText(text, fontSize);
        marker.height = lineH;
        marker.fontSize = fontSize;
        marker.style = InlineKind::PlainText;
        marker.text = text;
        page.elements.push_back(std::move(marker));
    };

    for (const auto& block : blocks) {
        switch (block.kind) {
            case BlockKind::Heading: {
                double fontSize = typography_.headingFontSize(block.level);
                // Extract {#label} from heading text if present.
                std::string headingLabel;
                auto inlines = block.inlines;
                for (auto it = inlines.begin(); it != inlines.end(); ) {
                    if (it->kind == InlineKind::PlainText) {
                        std::string& t = it->text;
                        auto pos = t.find("{#");
                        if (pos != std::string::npos) {
                            auto end = t.find('}', pos + 2);
                            if (end != std::string::npos) {
                                headingLabel = t.substr(pos + 2, end - pos - 2);
                                t.erase(pos, end - pos + 1);
                                if (t.empty()) {
                                    it = inlines.erase(it);
                                    continue;
                                }
                            }
                        }
                    }
                    ++it;
                }
                placeParagraphLike(inlines, fontSize, 0.0, geometry_.contentWidth(), block.level, false, false);
                // Tag heading elements with the label.
                if (!headingLabel.empty()) {
                    for (auto& el : page.elements) {
                        if (el.headingLevel == block.level && el.y == cursorY - metrics_.lineHeight(fontSize)) {
                            el.headingLabel = headingLabel;
                        }
                    }
                }
                cursorY += typography_.spacingAfterHeading;
                break;
            }

            case BlockKind::Blockquote: {
                constexpr double barWidth = 4.0;
                constexpr double barPadding = 12.0;
                double fontSize = typography_.paragraphFontSize;
                double indent = barWidth + barPadding;

                double barTop = cursorY;
                placeParagraphLike(block.inlines, fontSize, indent, geometry_.contentWidth() - indent, 0, true, typography_.textJustified);
                double barHeight = cursorY - barTop;
                if (barHeight < 0) barHeight = 0;

                LayoutElement bar;
                bar.kind = LayoutElementKind::HorizontalRule;
                bar.x = 0.0;
                bar.y = barTop;
                bar.width = barWidth;
                bar.height = barHeight;
                page.elements.push_back(std::move(bar));

                cursorY += typography_.spacingAfterParagraph;
                break;
            }

            case BlockKind::Paragraph: {
                placeParagraphLike(block.inlines, typography_.paragraphFontSize, 0.0, geometry_.contentWidth(), 0, false, typography_.textJustified);
                cursorY += typography_.spacingAfterParagraph;
                break;
            }

            case BlockKind::UnorderedList: {
                double fontSize = typography_.listItemFontSize;
                double baseIndent = typography_.listIndent;
                std::function<void(const std::vector<ListItem>&, double)> placeItems;
                placeItems = [&](const std::vector<ListItem>& items, double parentIndent) {
                    for (const auto& item : items) {
                        double markerX = parentIndent;
                        double textIndent = parentIndent + baseIndent;
                        std::string marker = "\xE2\x80\xA2";
                        if (item.isTask) {
                            marker = item.checked ? "\xE2\x98\x92" : "\xE2\x98\x90";
                        }
                        placeListMarker(marker, fontSize, markerX);
                        double textX = textIndent + metrics_.widthOfText(marker + " ", fontSize) - baseIndent;
                        placeParagraphLike(item.inlines, fontSize, textX, geometry_.contentWidth() - textX, 0, false, typography_.textJustified);
                        cursorY += typography_.spacingAfterListItem;
                        if (!item.items.empty()) {
                            placeItems(item.items, textIndent);
                        }
                    }
                };
                placeItems(block.items, 0);
                cursorY += typography_.spacingAfterList;
                break;
            }

            case BlockKind::OrderedList: {
                double fontSize = typography_.listItemFontSize;
                double baseIndent = typography_.listIndent;
                std::function<void(const std::vector<ListItem>&, double)> placeItems;
                placeItems = [&](const std::vector<ListItem>& items, double parentIndent) {
                    for (const auto& item : items) {
                        double markerX = parentIndent;
                        double textIndent = parentIndent + baseIndent;
                        std::string marker = std::to_string(item.number) + ".";
                        placeListMarker(marker, fontSize, markerX);
                        double textX = textIndent + metrics_.widthOfText(marker + " ", fontSize) - baseIndent;
                        placeParagraphLike(item.inlines, fontSize, textX, geometry_.contentWidth() - textX, 0, false, typography_.textJustified);
                        cursorY += typography_.spacingAfterListItem;
                        if (!item.items.empty()) {
                            placeItems(item.items, textIndent);
                        }
                    }
                };
                placeItems(block.items, 0);
                cursorY += typography_.spacingAfterList;
                break;
            }

            case BlockKind::HorizontalRule: {
                constexpr double ruleHeight = 1.0;
                if (cursorY + ruleHeight > geometry_.contentHeight()) {
                    startNewPage();
                }
                LayoutElement rule;
                rule.kind = LayoutElementKind::HorizontalRule;
                rule.x = 0.0;
                rule.y = cursorY;
                rule.width = geometry_.contentWidth();
                rule.height = ruleHeight;
                page.elements.push_back(std::move(rule));
                cursorY += ruleHeight + typography_.spacingAfterHorizontalRule;
                break;
            }

            case BlockKind::CodeBlock: {
                double fontSize = typography_.codeFontSize;
                double lineH = metrics_.lineHeight(fontSize);
                std::size_t start = 0;
                while (start <= block.text.size()) {
                    std::size_t nl = block.text.find('\n', start);
                    std::string codeLine = (nl == std::string::npos)
                        ? block.text.substr(start)
                        : block.text.substr(start, nl - start);

                    // Dividir la linea de codigo en palabras por espacios
                    // para que el line-breaking envuelva en limites de palabra.
                    std::vector<StyledWord> codeWords;
                    std::size_t pos = 0;
                    bool first = true;
                    while (pos < codeLine.size()) {
                        // Saltar espacios iniciales
                        while (pos < codeLine.size() && codeLine[pos] == ' ') ++pos;
                        if (pos >= codeLine.size()) break;
                        // Encontrar siguiente espacio
                        std::size_t sp = codeLine.find(' ', pos);
                        std::string token = (sp == std::string::npos)
                            ? codeLine.substr(pos)
                            : codeLine.substr(pos, sp - pos);
                        StyledWord w;
                        w.text = token;
                        w.style = InlineKind::Code;
                        w.spaceBefore = !first;
                        first = false;
                        codeWords.push_back(w);
                        pos = (sp == std::string::npos) ? codeLine.size() : sp;
                    }

                    if (codeWords.empty()) {
                        StyledWord emptyWord;
                        emptyWord.text = "";
                        emptyWord.style = InlineKind::Code;
                        emptyWord.spaceBefore = false;
                        codeWords.push_back(emptyWord);
                    }

                    auto wrappedLines = breakIntoLines(codeWords, fontSize, geometry_.contentWidth(), metrics_, hyphenator_, false);
                    if (wrappedLines.empty()) {
                        wrappedLines.push_back(Line());
                        wrappedLines.back().words.push_back(codeWords.empty() ? StyledWord() : codeWords[0]);
                        wrappedLines.back().wordX.push_back(0.0);
                    }

                    for (const auto& line : wrappedLines) {
                        if (cursorY + lineH > geometry_.contentHeight()) {
                            startNewPage();
                        }
                        for (std::size_t i = 0; i < line.words.size(); ++i) {
                            LayoutElement el;
                            el.kind = LayoutElementKind::Word;
                            el.x = line.wordX.empty() ? 0.0 : line.wordX[i];
                            el.y = cursorY;
                            el.width = metrics_.widthOfText(line.words[i].text, fontSize);
                            el.height = lineH;
                            el.fontSize = fontSize;
                            el.style = InlineKind::Code;
                            el.text = line.words[i].text;
                            el.isCodeBlock = true;
                            page.elements.push_back(std::move(el));
                        }
                        cursorY += lineH;
                    }

                    if (nl == std::string::npos) {
                        break;
                    }
                    start = nl + 1;
                }
                cursorY += typography_.spacingAfterCodeBlock;
                break;
            }

            case BlockKind::Table: {
                int cols = block.tableColumnCount;
                if (cols <= 0) break;

                double fontSize = typography_.paragraphFontSize;
                double lineH = metrics_.lineHeight(fontSize);
                double padH = typography_.tableCellPaddingH;
                double padV = typography_.tableCellPaddingV;
                double availWidth = geometry_.contentWidth();
                double colWidth = availWidth / cols;
                double maxCellTextW = colWidth - padH * 2;
                if (maxCellTextW < 1.0) maxCellTextW = 1.0;

                // Helper: x alineado de una celda.
                auto cellAlignedX = [&](int col, double textW) -> double {
                    double leftX = col * colWidth + padH;
                    int align = (col < static_cast<int>(block.tableAlign.size())) ? block.tableAlign[col] : 0;
                    if (align == 1) return leftX + (maxCellTextW - textW) / 2.0;  // center
                    if (align == 2) return leftX + maxCellTextW - textW;            // right
                    return leftX;  // left (default)
                };

                int totalCells = static_cast<int>(block.tableCells.size());
                int totalRows = (totalCells + cols - 1) / cols;

                // Pre-calcular lineas envueltas por celda y altura de cada fila.
                std::vector<std::vector<std::string>> cellLines(totalCells);
                std::vector<double> rowHeights(totalRows, 0.0);

                for (int cellIdx = 0; cellIdx < totalCells; ++cellIdx) {
                    int row = cellIdx / cols;
                    const std::string& cellText = block.tableCells[cellIdx];
                    if (cellText.empty()) continue;

                    InlineKind cellStyle = (row == 0) ? InlineKind::Bold : InlineKind::PlainText;
                    auto words = wordsFromInlines({InlineRun(cellStyle, cellText)});
                    auto lines = breakIntoLines(words, fontSize, maxCellTextW, metrics_, hyphenator_, false);
                    for (const auto& line : lines) {
                        std::string lineText = textFromLine(line);
                        if (!lineText.empty()) {
                            cellLines[cellIdx].push_back(lineText);
                        }
                    }
                    double cellH = padV * 2 + static_cast<double>(cellLines[cellIdx].size()) * lineH;
                    if (cellH > rowHeights[row]) rowHeights[row] = cellH;
                }

                for (double& h : rowHeights) {
                    if (h < lineH + padV * 2) h = lineH + padV * 2;
                }

                // --- Paginacion: dividir filas entre paginas ---
                constexpr double gridW = 0.5;
                int firstRow = 0;
                while (firstRow < totalRows) {
                    // Calcular cuantas filas caben en el espacio restante.
                    double usedH = 0;
                    int lastRow = firstRow;
                    double maxPageH = geometry_.contentHeight();
                    double headerH = (firstRow == 0) ? 0 : rowHeights[0]; // re-encabezado en paginas posteriores
                    while (lastRow < totalRows && usedH + rowHeights[lastRow] <= maxPageH - cursorY - headerH) {
                        usedH += rowHeights[lastRow];
                        ++lastRow;
                    }
                    if (lastRow == firstRow) {
                        if (cursorY > 0) {
                            startNewPage();
                            continue;
                        }
                        // Una fila individual puede ser mas alta que el area
                        // disponible. La colocamos igualmente para evitar un
                        // bucle infinito; el renderer recortara lo que exceda.
                        lastRow = firstRow + 1;
                        usedH = rowHeights[firstRow];
                    }
                    if (firstRow == 0 && totalRows > 1 && lastRow == 1 && cursorY > 0) {
                        startNewPage();
                        continue;
                    }

                    double tableTop = cursorY;
                    double dataTop = tableTop;
                    int pageRows = lastRow - firstRow;
                    bool hasHeader = (firstRow > 0);

                    // Si es pagina posterior, dibujar cabecera repetida.
                    int drawStart = firstRow;
                    if (hasHeader) {
                        // Cabecera repetida.
                        for (int r = 0; r <= 1; ++r) { // linea sobre y bajo cabecera
                            LayoutElement hLine;
                            hLine.kind = LayoutElementKind::TableGridLine;
                            hLine.x = 0;
                            hLine.y = tableTop + r * rowHeights[0];
                            hLine.width = availWidth;
                            hLine.height = gridW;
                            page.elements.push_back(std::move(hLine));
                        }
                        for (int c = 0; c <= cols; ++c) {
                            LayoutElement vLine;
                            vLine.kind = LayoutElementKind::TableGridLine;
                            vLine.x = c * colWidth;
                            vLine.y = tableTop;
                            vLine.width = gridW;
                            vLine.height = rowHeights[0];
                            page.elements.push_back(std::move(vLine));
                        }
                        // Texto de cabecera.
                        double cellY = tableTop + padV;
                        for (int col = 0; col < cols; ++col) {
                            int cellIdx = col;
                            double lineY = cellY;
                            for (const auto& lt : cellLines[cellIdx]) {
                                double cellX = cellAlignedX(col, metrics_.widthOfText(lt, fontSize));
                                LayoutElement el;
                                el.kind = LayoutElementKind::Word;
                                el.x = cellX; el.y = lineY;
                                el.width = metrics_.widthOfText(lt, fontSize);
                                el.height = lineH; el.fontSize = fontSize;
                                el.style = InlineKind::Bold; el.text = lt;
                                el.isTableCell = true;
                                page.elements.push_back(std::move(el));
                                lineY += lineH;
                            }
                        }
                        dataTop += rowHeights[0];
                    }

                    // Lineas horizontales para las filas de datos.
                    double rowY = dataTop;
                    for (int r = firstRow; r <= lastRow; ++r) {
                        LayoutElement hLine;
                        hLine.kind = LayoutElementKind::TableGridLine;
                        hLine.x = 0; hLine.y = rowY;
                        hLine.width = availWidth; hLine.height = gridW;
                        page.elements.push_back(std::move(hLine));
                        if (r < lastRow) rowY += rowHeights[r];
                    }

                    // Lineas verticales para todo el bloque.
                    double blockH = (hasHeader ? rowHeights[0] : 0);
                    double dataBlockH = 0;
                    for (int r = firstRow; r < lastRow; ++r) blockH += rowHeights[r];
                    for (int r = firstRow; r < lastRow; ++r) dataBlockH += rowHeights[r];
                    for (int c = 0; c <= cols; ++c) {
                        LayoutElement vLine;
                        vLine.kind = LayoutElementKind::TableGridLine;
                        vLine.x = c * colWidth; vLine.y = dataTop;
                        vLine.width = gridW; vLine.height = dataBlockH;
                        page.elements.push_back(std::move(vLine));
                    }

                    // Texto de celdas de datos.
                    rowY = dataTop;
                    for (int row = firstRow; row < lastRow; ++row) {
                        for (int col = 0; col < cols; ++col) {
                            int cellIdx = row * cols + col;
                            if (cellIdx >= totalCells) break;
                            double lineY = rowY + padV;
                            for (const auto& lt : cellLines[cellIdx]) {
                                double cellX = cellAlignedX(col, metrics_.widthOfText(lt, fontSize));
                                LayoutElement el;
                                el.kind = LayoutElementKind::Word;
                                el.x = cellX; el.y = lineY;
                                el.width = metrics_.widthOfText(lt, fontSize);
                                el.height = lineH; el.fontSize = fontSize;
                                el.style = (row == 0 && !hasHeader) ? InlineKind::Bold : InlineKind::PlainText;
                                el.text = lt;
                                el.isTableCell = true;
                                page.elements.push_back(std::move(el));
                                lineY += lineH;
                            }
                        }
                        rowY += rowHeights[row];
                    }

                    cursorY += blockH;
                    cursorY += typography_.spacingAfterTable;

                    firstRow = lastRow;
                }
                break;
            }

            case BlockKind::MathBlock: {
                double fontSize = typography_.codeFontSize;
                double lineH = metrics_.lineHeight(fontSize);
                const double padH = 20.0;

                std::size_t start = 0;
                while (start <= block.text.size()) {
                    std::size_t nl = block.text.find('\n', start);
                    std::string mathLine = (nl == std::string::npos)
                        ? block.text.substr(start)
                        : block.text.substr(start, nl - start);

                    StyledWord word;
                    word.text = mathLine;
                    word.style = InlineKind::InlineMath;
                    word.spaceBefore = false;
                    auto wrappedLines = breakIntoLines({word}, fontSize,
                        geometry_.contentWidth() - padH * 2, metrics_, hyphenator_, false);
                    if (wrappedLines.empty()) {
                        wrappedLines.push_back(Line());
                        wrappedLines.back().words.push_back(word);
                        wrappedLines.back().wordX.push_back(0.0);
                    }

                    for (const auto& ln : wrappedLines) {
                        if (cursorY + lineH > geometry_.contentHeight()) {
                            startNewPage();
                        }
                        for (std::size_t i = 0; i < ln.words.size(); ++i) {
                            LayoutElement el;
                            el.kind = LayoutElementKind::MathBlock;
                            el.x = padH + (ln.wordX.empty() ? 0.0 : ln.wordX[i]);
                            el.y = cursorY;
                            el.width = metrics_.widthOfText(ln.words[i].text, fontSize);
                            el.height = lineH;
                            el.fontSize = fontSize;
                            el.style = InlineKind::InlineMath;
                            el.text = ln.words[i].text;
                            page.elements.push_back(std::move(el));
                        }
                        cursorY += lineH;
                    }

                    if (nl == std::string::npos) break;
                    start = nl + 1;
                }
                cursorY += typography_.spacingAfterCodeBlock;
                break;
            }

            case BlockKind::FootnoteDef: {
                FootnoteDef fd;
                fd.label = block.footnoteLabel;
                fd.text = block.text;
                result.footnoteDefs.push_back(std::move(fd));
                break;
            }

            case BlockKind::RawHtmlBlock: {
                double fontSize = typography_.codeFontSize;
                double lineH = metrics_.lineHeight(fontSize);
                const double padH = 10.0;

                std::size_t start = 0;
                while (start <= block.htmlContent.size()) {
                    std::size_t nl = block.htmlContent.find('\n', start);
                    std::string line = (nl == std::string::npos)
                        ? block.htmlContent.substr(start)
                        : block.htmlContent.substr(start, nl - start);

                    StyledWord word;
                    word.text = line;
                    word.style = InlineKind::PlainText;
                    word.spaceBefore = false;
                    auto wrappedLines = breakIntoLines({word}, fontSize,
                        geometry_.contentWidth() - padH * 2, metrics_, hyphenator_, false);
                    if (wrappedLines.empty()) {
                        wrappedLines.push_back(Line());
                        wrappedLines.back().words.push_back(word);
                        wrappedLines.back().wordX.push_back(0.0);
                    }

                    for (const auto& ln : wrappedLines) {
                        if (cursorY + lineH > geometry_.contentHeight()) {
                            startNewPage();
                        }
                        for (std::size_t i = 0; i < ln.words.size(); ++i) {
                            LayoutElement el;
                            el.kind = LayoutElementKind::RawHtml;
                            el.x = padH + (ln.wordX.empty() ? 0.0 : ln.wordX[i]);
                            el.y = cursorY;
                            el.width = metrics_.widthOfText(ln.words[i].text, fontSize);
                            el.height = lineH;
                            el.fontSize = fontSize;
                            el.style = InlineKind::Code;
                            el.text = ln.words[i].text;
                            page.elements.push_back(std::move(el));
                        }
                        cursorY += lineH;
                    }

                    if (nl == std::string::npos) break;
                    start = nl + 1;
                }
                cursorY += typography_.spacingAfterCodeBlock;
                break;
            }

            default:
                break;
        }
    }

    result.pages.push_back(std::move(page));
    return result;
}

} // namespace mdcore
