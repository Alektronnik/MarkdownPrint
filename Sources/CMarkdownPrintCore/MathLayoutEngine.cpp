#include "MathLayoutEngine.hpp"
#include "MathParser.hpp"
#include <algorithm>
#include <cmath>
#include <unordered_map>

namespace mdcore {
namespace math {

// ===================================================================
// Approximate Math Font Metrics
// ===================================================================
//
// These approximate the metrics of STIX Math / SF Math at a given
// point size. The actual rendering uses CoreText with precise metrics,
// but the layout engine needs approximate widths to decide line breaks
// and positioning. The Swift renderer can adjust x positions afterward.

namespace {

// Average width ratio relative to point size for different glyph classes.
constexpr double kDigitWidthRatio     = 0.6;   // 0-9
constexpr double kUpperWidthRatio     = 0.72;  // A-Z
constexpr double kLowerWidthRatio     = 0.55;  // a-z
constexpr double kGreekWidthRatio     = 0.6;   // Greek letters
constexpr double kSymbolWidthRatio    = 0.65;  // Math symbols (∞, ±, ∫...)
constexpr double kLargeOpWidthRatio   = 0.85;  // ∑, ∏, ∫ (wider)
constexpr double kDelimWidthRatio     = 0.5;   // (, ), [, ], {, }
constexpr double kCommaWidthRatio     = 0.3;
constexpr double kAscenderRatio       = 0.7;   // Height above baseline / pt size
constexpr double kDescenderRatio      = 0.25;  // Depth below baseline / pt size
constexpr double kLargeOpHeightRatio  = 0.9;   // Big operators taller
constexpr double kLargeOpDepthRatio   = 0.3;

// Superscript/subscript scaling.
constexpr double kScriptScale = 0.7;       // Script font size ratio
constexpr double kScriptScriptScale = 0.5; // Second-level script

// Spacing constants (in em = times pt size).
constexpr double kThinSpace   = 0.1667;  // \,
constexpr double kMedSpace    = 0.2222;  // \:
constexpr double kThickSpace  = 0.2778;  // \;
constexpr double kOperatorSpacing = 0.15; // Space around binary operators
constexpr double kRelationSpacing = 0.28; // Space around relations (=, <, >)

// Radical constants.
constexpr double kRadicalRuleThickness = 0.05; // em
constexpr double kRadicalExtraAscender = 0.25; // extra height for radical

// Fraction constants.
constexpr double kFractionRuleThickness = 0.05; // em
constexpr double kFractionNumShift = 0.1;       // shift numerator up from rule
constexpr double kFractionDenShift = 0.1;       // shift denominator down from rule

// Delimiter constants.
constexpr double kDelimBaseHeight = 0.9;  // full height ratio for ()
constexpr double kDelimMinRatio = 0.65;   // minimum scaling for delimiters

// Returns average glyph width for a character.
double charWidthRatio(uint32_t cp) {
    if (cp >= '0' && cp <= '9') return kDigitWidthRatio;
    if (cp >= 'A' && cp <= 'Z') return kUpperWidthRatio;
    if (cp >= 'a' && cp <= 'z') return kLowerWidthRatio;
    // Greek (U+0391-U+03C9)
    if ((cp >= 0x0391 && cp <= 0x03A9) || (cp >= 0x03B1 && cp <= 0x03C9)) {
        return kGreekWidthRatio;
    }
    // Math operators and symbols (U+2200-U+22FF, U+2A00-U+2AFF)
    if ((cp >= 0x2200 && cp <= 0x22FF) || (cp >= 0x2A00 && cp <= 0x2AFF)) {
        // Large operators
        if (cp == 0x2211 || cp == 0x220F || cp == 0x222B || cp == 0x222C ||
            cp == 0x222D || cp == 0x222E || cp == 0x22C0 || cp == 0x22C1 ||
            cp == 0x22C2 || cp == 0x22C3 || cp == 0x2A00 || cp == 0x2A01 ||
            cp == 0x2A02 || cp == 0x2A04 || cp == 0x2A06) {
            return kLargeOpWidthRatio;
        }
        return kSymbolWidthRatio;
    }
    // Arrows (U+2190-U+21FF)
    if (cp >= 0x2190 && cp <= 0x21FF) return kSymbolWidthRatio * 1.2;
    // Delimiters
    if (cp == '(' || cp == ')' || cp == '[' || cp == ']' || cp == '{' || cp == '}') {
        return kDelimWidthRatio;
    }
    if (cp == ',' || cp == ';') return kCommaWidthRatio;
    if (cp == '|') return 0.15;
    // Default: assume narrow symbol
    return kSymbolWidthRatio;
}

double stringWidth(const std::string& s, double ptSize) {
    if (s.empty()) return 0.0;
    // If it's a single Unicode char, use the ratio.
    double total = 0.0;
    // Simple: treat first char's Unicode value.
    // For multi-byte UTF-8, this is approximate.
    uint32_t cp = static_cast<unsigned char>(s[0]);
    if ((cp & 0x80) && s.size() >= 2) {
        if ((cp & 0xE0) == 0xC0 && s.size() >= 2) {
            cp = ((cp & 0x1F) << 6) | (static_cast<unsigned char>(s[1]) & 0x3F);
        } else if ((cp & 0xF0) == 0xE0 && s.size() >= 3) {
            cp = ((cp & 0x0F) << 12) | ((static_cast<unsigned char>(s[1]) & 0x3F) << 6)
                 | (static_cast<unsigned char>(s[2]) & 0x3F);
        } else if ((cp & 0xF8) == 0xF0 && s.size() >= 4) {
            cp = ((cp & 0x07) << 18) | ((static_cast<unsigned char>(s[1]) & 0x3F) << 12)
                 | ((static_cast<unsigned char>(s[2]) & 0x3F) << 6)
                 | (static_cast<unsigned char>(s[3]) & 0x3F);
        }
    }
    return charWidthRatio(cp) * ptSize;
}

} // namespace

// ===================================================================
// LayoutEngine implementation
// ===================================================================

MathLayoutEngine::MathLayoutEngine() {}

MathLayout MathLayoutEngine::layout(const MathNodePtr& root, double fontSize, bool displayStyle) {
    if (!root) {
        MathLayout empty;
        return empty;
    }
    return layoutNode(*root, fontSize, displayStyle);
}

MathLayout MathLayoutEngine::layoutNode(const MathNode& node, double fontSize, bool displayStyle) {
    switch (node.kind) {
        case MathNodeKind::Number:
        case MathNodeKind::Identifier:
        case MathNodeKind::GreekLetter:
        case MathNodeKind::MathSymbol: {
            MathLayout result;
            std::string uni = node.unicode.empty() ? node.text : node.unicode;
            double w = stringWidth(uni, fontSize);
            double h = fontSize * kAscenderRatio;
            double d = fontSize * kDescenderRatio;

            // Large operators in display mode are bigger.
            if (node.kind == MathNodeKind::LargeOp) {
                h = fontSize * kLargeOpHeightRatio;
                d = fontSize * kLargeOpDepthRatio;
            }

            result.boxes.push_back(makeGlyphBox(uni, node.text, 0, 0, w, h, d, fontSize));
            result.totalWidth = w;
            result.totalHeight = h;
            result.totalDepth = d;
            result.baselineY = h;
            return result;
        }

        case MathNodeKind::Group: {
            if (node.children.empty()) return MathLayout();
            return layoutNode(*node.children[0], fontSize, displayStyle);
        }

        case MathNodeKind::Superscript:
        case MathNodeKind::Subscript:
        case MathNodeKind::SubSup:
            return layoutSubSup(node, fontSize, displayStyle);

        case MathNodeKind::Fraction:
            return layoutFraction(node, fontSize, displayStyle);

        case MathNodeKind::Radical:
            return layoutRadical(node, fontSize, displayStyle);

        case MathNodeKind::LargeOp:
            return layoutLargeOp(node, fontSize, displayStyle);

        case MathNodeKind::Delimited:
            return layoutDelimited(node, fontSize, displayStyle);

        case MathNodeKind::BinaryOp: {
            if (node.children.size() < 2) {
                // Degraded: return left child only.
                if (!node.children.empty()) return layoutNode(*node.children[0], fontSize, displayStyle);
                return MathLayout();
            }

            auto left = layoutNode(*node.children[0], fontSize, displayStyle);
            auto right = layoutNode(*node.children[1], fontSize, displayStyle);

            double opWidth = stringWidth(node.unicode.empty() ? node.text : node.unicode, fontSize);
            double space = kOperatorSpacing * fontSize;
            double totalSpacing = space * 2 + opWidth;

            // Offset right child.
            double rightX = left.totalWidth + totalSpacing;
            for (auto& box : right.boxes) {
                box.x += rightX;
            }

            // Operator box.
            double opH = fontSize * kAscenderRatio;
            double opD = fontSize * kDescenderRatio;
            double opX = left.totalWidth + space;
            // Center operator vertically on the math axis (approx mid-height).
            double totalH = std::max(left.totalHeight, right.totalHeight);
            double totalD = std::max(left.totalDepth, right.totalDepth);
            double axis = fontSize * 0.25;
            double opY = (totalH - axis) - opH * 0.5;

            MathLayout result;
            result.boxes = std::move(left.boxes);
            result.boxes.push_back(makeGlyphBox(
                node.unicode.empty() ? node.text : node.unicode, node.text,
                opX, opY, opWidth, opH, opD, fontSize));
            for (auto& box : right.boxes) result.boxes.push_back(std::move(box));

            result.totalWidth = rightX + right.totalWidth;
            result.totalHeight = totalH;
            result.totalDepth = totalD;
            result.baselineY = totalH;
            return result;
        }

        case MathNodeKind::UnaryOp: {
            if (node.children.empty()) return MathLayout();
            auto operand = layoutNode(*node.children[0], fontSize, displayStyle);
            double opWidth = stringWidth(node.unicode.empty() ? node.text : node.unicode, fontSize);
            double space = kThinSpace * fontSize;

            for (auto& box : operand.boxes) box.x += opWidth + space;

            MathLayout result;
            double opH = fontSize * kAscenderRatio;
            double opD = fontSize * kDescenderRatio;
            result.boxes.push_back(makeGlyphBox(
                node.unicode.empty() ? node.text : node.unicode, node.text,
                0, 0, opWidth, opH, opD, fontSize));
            for (auto& box : operand.boxes) result.boxes.push_back(std::move(box));

            result.totalWidth = opWidth + space + operand.totalWidth;
            result.totalHeight = std::max(opH, operand.totalHeight);
            result.totalDepth = std::max(opD, operand.totalDepth);
            result.baselineY = result.totalHeight;
            return result;
        }

        case MathNodeKind::AccentOver:
            return layoutAccentOver(node, fontSize, displayStyle);
        case MathNodeKind::AccentUnder:
            return layoutAccentUnder(node, fontSize, displayStyle);
        case MathNodeKind::OverUnder:
            return layoutOverUnder(node, fontSize, displayStyle);
        case MathNodeKind::Binomial:
            return layoutBinomial(node, fontSize, displayStyle);
        case MathNodeKind::CasesBlock:
            return layoutCases(node, fontSize, displayStyle);
        case MathNodeKind::SubStack:
            return layoutSubStack(node, fontSize, displayStyle);
        case MathNodeKind::TextBox:
            return layoutTextBox(node, fontSize, displayStyle);

        case MathNodeKind::Matrix:
            return layoutMatrix(node, fontSize, displayStyle);

        default: {
            // Unknown node — render as plain text.
            MathLayout result;
            if (!node.text.empty()) {
                double w = stringWidth(node.text, fontSize);
                double h = fontSize * kAscenderRatio;
                double d = fontSize * kDescenderRatio;
                result.boxes.push_back(makeGlyphBox(node.text, node.text, 0, 0, w, h, d, fontSize));
                result.totalWidth = w;
                result.totalHeight = h;
                result.totalDepth = d;
                result.baselineY = h;
            }
            return result;
        }
    }
}

MathLayout MathLayoutEngine::layoutFraction(const MathNode& node, double fontSize, bool displayStyle) {
    if (node.children.size() < 2) {
        // Degraded fraction (missing num or den).
        MathLayout result;
        if (!node.children.empty()) return layoutNode(*node.children[0], fontSize, displayStyle);
        return result;
    }

    // Fraction uses smaller font for num/den unless display style.
    double scriptSize = displayStyle ? fontSize : fontSize * kScriptScale;
    auto numLayout = layoutNode(*node.children[0], scriptSize, displayStyle);
    auto denLayout = layoutNode(*node.children[1], scriptSize, displayStyle);

    double ruleThickness = kFractionRuleThickness * fontSize;
    double numShift = kFractionNumShift * fontSize;
    double denShift = kFractionDenShift * fontSize;

    double maxContentWidth = std::max(numLayout.totalWidth, denLayout.totalWidth);
    double halfGap = std::max(0.0, (maxContentWidth - numLayout.totalWidth) / 2.0);

    // Position numerator centered above baseline.
    double numY = ruleThickness + numShift;
    for (auto& box : numLayout.boxes) {
        box.x += halfGap;
        box.y = numY + numLayout.totalDepth; // shift numerator above baseline
    }

    // Position denominator centered below baseline.
    double denGap = std::max(0.0, (maxContentWidth - denLayout.totalWidth) / 2.0);
    double denY = -(ruleThickness + denShift + denLayout.totalHeight);
    for (auto& box : denLayout.boxes) {
        box.x += denGap;
        box.y = denY;
    }

    // Rule width = max(num width, den width) + small overhang.
    double ruleWidth = maxContentWidth + fontSize * 0.1;
    double ruleX = (maxContentWidth - ruleWidth) / 2.0;

    MathLayout result;
    result.boxes = std::move(numLayout.boxes);
    for (auto& box : denLayout.boxes) result.boxes.push_back(std::move(box));
    result.boxes.push_back(makeRuleBox(ruleX, 0, ruleWidth, ruleThickness));

    result.totalWidth = maxContentWidth;
    result.totalHeight = numLayout.totalHeight + numShift + ruleThickness;
    result.totalDepth = denLayout.totalDepth + denShift + ruleThickness;
    result.baselineY = result.totalHeight;
    return result;
}

MathLayout MathLayoutEngine::layoutRadical(const MathNode& node, double fontSize, bool displayStyle) {
    // children[0] = index (optional), children[last] = radicand.
    if (node.children.empty()) return MathLayout();

    bool hasIndex = node.children.size() >= 2;
    // Use references to avoid copying unique_ptrs.
    const MathNode& radicandNode = hasIndex ? *node.children[1] : *node.children[0];

    auto contentLayout = layoutNode(radicandNode, fontSize, displayStyle);

    double ruleThickness = kRadicalRuleThickness * fontSize;
    double clearance = fontSize * 0.1;
    double extraAscender = kRadicalExtraAscender * fontSize;

    // Radical symbol: √ (U+221A)
    double radicalWidth = stringWidth("√", fontSize);
    // Scale up radical to cover content height.
    double contentTotalH = contentLayout.totalHeight + ruleThickness + clearance;
    double radicalScale = std::max(1.0, contentTotalH / (fontSize * 0.8));

    // Position content to the right of radical symbol.
    double contentX = radicalWidth * radicalScale * 0.7;
    double ruleX = contentX - fontSize * 0.1;
    double ruleWidth = contentLayout.totalWidth + fontSize * 0.15;

    for (auto& box : contentLayout.boxes) {
        box.x += contentX;
        box.y = 0;
    }

    MathLayout result;
    // Radical glyph.
    auto radBox = makeGlyphBox("√", "\\sqrt", 0, 0,
        radicalWidth * radicalScale, contentTotalH, 0, fontSize * radicalScale);
    radBox.isRadical = true;
    radBox.radicalContentHeight = contentTotalH;
    radBox.radicalContentWidth = contentLayout.totalWidth + contentX;
    result.boxes.push_back(std::move(radBox));

    // Overline.
    result.boxes.push_back(makeRuleBox(ruleX, contentLayout.totalHeight + clearance,
        ruleWidth, ruleThickness));

    for (auto& box : contentLayout.boxes) result.boxes.push_back(std::move(box));

    // Index (if present) positioned above radical.
    if (hasIndex) {
        const MathNode& indexNode = *node.children[0];
        double idxSize = fontSize * kScriptScriptScale;
        auto idxLayout = layoutNode(indexNode, idxSize, displayStyle);
        double idxX = radicalWidth * 0.3;
        double idxY = contentTotalH - idxLayout.totalDepth * 0.5;
        for (auto& box : idxLayout.boxes) {
            box.x += idxX;
            box.y += idxY;
        }
        for (auto& box : idxLayout.boxes) result.boxes.push_back(std::move(box));
        result.totalHeight = std::max(contentTotalH, idxY + idxLayout.totalHeight);
    } else {
        result.totalHeight = contentTotalH;
    }

    result.totalWidth = ruleX + ruleWidth;
    result.totalDepth = std::max(contentLayout.totalDepth, 0.0);
    result.baselineY = result.totalHeight;
    return result;
}

MathLayout MathLayoutEngine::layoutLargeOp(const MathNode& node, double fontSize, bool displayStyle) {
    // Base operator.
    double opSize = displayStyle ? fontSize * 1.4 : fontSize;
    std::string uni = node.unicode.empty() ? node.text : node.unicode;
    double opW = stringWidth(uni, opSize);
    double opH = opSize * kLargeOpHeightRatio;
    double opD = opSize * kLargeOpDepthRatio;

    MathLayout result;
    double totalW = opW;
    double totalH = opH;
    double totalD = opD;

    // In display style, limits go above and below.
    if (displayStyle && node.children.size() >= 2) {
        double limitSize = fontSize * kScriptScale;

        // Upper limit.
        auto upperLayout = layoutNode(*node.children[1], limitSize, displayStyle);
        double upperShift = opH + fontSize * 0.1;
        double upperOffsetX = (opW - upperLayout.totalWidth) / 2.0;
        for (auto& box : upperLayout.boxes) {
            box.x += upperOffsetX;
            box.y += upperShift + upperLayout.totalDepth;
        }
        totalW = std::max(totalW, upperLayout.totalWidth);
        totalH = upperShift + upperLayout.totalHeight;

        // Lower limit.
        auto lowerLayout = layoutNode(*node.children[0], limitSize, displayStyle);
        double lowerShift = -(opD + fontSize * 0.1 + lowerLayout.totalHeight);
        double lowerOffsetX = (opW - lowerLayout.totalWidth) / 2.0;
        for (auto& box : lowerLayout.boxes) {
            box.x += lowerOffsetX;
            box.y += lowerShift;
        }
        totalW = std::max(totalW, lowerLayout.totalWidth);
        totalD = opD + fontSize * 0.1 + lowerLayout.totalDepth + lowerLayout.totalHeight;

        for (auto& box : upperLayout.boxes) result.boxes.push_back(std::move(box));
        for (auto& box : lowerLayout.boxes) result.boxes.push_back(std::move(box));
    } else if (!displayStyle) {
        // In inline mode, limits are sub/superscripts handled by SubSup node.
        // If there are children here (from old parsing), treat as limits.
        if (node.children.size() == 1) {
            double limitSize = fontSize * kScriptScale;
            auto subLayout = layoutNode(*node.children[0], limitSize, displayStyle);
            double shift = -(opD + fontSize * 0.05);
            double offsetX = opW;
            for (auto& box : subLayout.boxes) {
                box.x += offsetX;
                box.y += shift;
            }
            totalW = opW + subLayout.totalWidth;
            totalD = std::max(totalD, opD + fontSize * 0.05 + subLayout.totalDepth + subLayout.totalHeight);
            for (auto& box : subLayout.boxes) result.boxes.push_back(std::move(box));
        } else if (node.children.size() >= 2) {
            // Both limits as sub/superscripts (inline mode).
            double limitSize = fontSize * kScriptScale;
            auto subLayout = layoutNode(*node.children[0], limitSize, displayStyle);
            auto superLayout = layoutNode(*node.children[1], limitSize, displayStyle);

            double subShift = -(opD + fontSize * 0.05);
            double superShift = opH + fontSize * 0.05;
            double subX = opW;
            double superX = opW;

            for (auto& box : subLayout.boxes) {
                box.x += subX;
                box.y += subShift;
            }
            for (auto& box : superLayout.boxes) {
                box.x += superX;
                box.y += superShift;
            }

            totalW = opW + std::max(subLayout.totalWidth, superLayout.totalWidth);
            totalH = std::max(totalH, opH + fontSize * 0.05 + superLayout.totalHeight);
            totalD = std::max(totalD, opD + fontSize * 0.05 + subLayout.totalDepth + subLayout.totalHeight);

            for (auto& box : subLayout.boxes) result.boxes.push_back(std::move(box));
            for (auto& box : superLayout.boxes) result.boxes.push_back(std::move(box));
        }
    }

    // Center the operator horizontally if limits are wider.
    double opCenterX = (totalW - opW) / 2.0;
    result.boxes.insert(result.boxes.begin(), makeGlyphBox(uni, node.text,
        opCenterX, 0, opW, opH, opD, opSize));

    result.totalWidth = totalW;
    result.totalHeight = totalH;
    result.totalDepth = totalD;
    result.baselineY = totalH;
    return result;
}

MathLayout MathLayoutEngine::layoutDelimited(const MathNode& node, double fontSize, bool displayStyle) {
    if (node.children.empty()) {
        // Just the delimiters.
        MathLayout result;
        double delimW = stringWidth(node.unicode.empty() ? node.text : node.unicode, fontSize);
        double h = fontSize * kDelimBaseHeight;
        double d = fontSize * kDescenderRatio;
        std::string leftDelim = node.text;
        std::string rightDelim;

        // Find matching right delimiter.
        if (leftDelim.size() >= 2 && leftDelim[0] == '\\') {
            std::string cmd = leftDelim.substr(1);
            rightDelim = "\\" + SymbolTable::instance().matchingRightDelim(cmd);
        } else {
            rightDelim = SymbolTable::instance().matchingRightDelim(leftDelim);
        }

        result.boxes.push_back(makeGlyphBox(node.unicode, node.text, 0, 0, delimW, h, d, fontSize));
        if (!rightDelim.empty()) {
            double rw = stringWidth(rightDelim, fontSize);
            result.boxes.push_back(makeGlyphBox(rightDelim, rightDelim, delimW + kThinSpace * fontSize, 0, rw, h, d, fontSize));
            result.totalWidth = delimW + kThinSpace * fontSize + rw;
        } else {
            result.totalWidth = delimW;
        }
        result.totalHeight = h;
        result.totalDepth = d;
        result.baselineY = h;
        return result;
    }

    // Layout inner content.
    double totalContentW = 0;
    double maxH = 0, maxD = 0;
    std::vector<MathLayout> parts;

    for (const auto& child : node.children) {
        auto part = layoutNode(*child, fontSize, displayStyle);
        totalContentW += part.totalWidth;
        maxH = std::max(maxH, part.totalHeight);
        maxD = std::max(maxD, part.totalDepth);
        parts.push_back(std::move(part));
    }

    // Determine delimiter height (must cover content).
    double contentHeight = maxH + maxD;
    double delimScale = std::max(kDelimMinRatio, contentHeight / (fontSize * kDelimBaseHeight));

    // Left delimiter.
    std::string leftGlyph;
    std::string leftCmd = node.text;
    if (leftCmd == "(" || leftCmd == "\\(") leftGlyph = "(";
    else if (leftCmd == "[" || leftCmd == "\\[") leftGlyph = "[";
    else if (leftCmd == "{" || leftCmd == "\\{") leftGlyph = "{";
    else if (leftCmd == "|" || leftCmd == "\\|") leftGlyph = "|";
    else if (leftCmd == "\\langle") leftGlyph = "⟨";
    else if (leftCmd == "\\lfloor") leftGlyph = "⌊";
    else if (leftCmd == "\\lceil") leftGlyph = "⌈";
    else leftGlyph = "("; // fallback

    double delimW = stringWidth(leftGlyph, fontSize * delimScale);
    double leftX = 0;
    double leftY = -maxD;
    double delimH = contentHeight;

    MathLayout result;
    result.boxes.push_back(makeGlyphBox(leftGlyph, leftCmd, leftX, leftY, delimW, delimH, 0, fontSize * delimScale));

    // Content positioned after left delimiter + space.
    double contentX = delimW + kMedSpace * fontSize;
    double cumX = contentX;
    for (auto& part : parts) {
        for (auto& box : part.boxes) {
            box.x += cumX;
            box.y = 0;
        }
        cumX += part.totalWidth;
        for (auto& box : part.boxes) result.boxes.push_back(std::move(box));
    }

    // Right delimiter.
    std::string rightGlyph;
    if (leftCmd == "(" || leftCmd == "\\(") rightGlyph = ")";
    else if (leftCmd == "[" || leftCmd == "\\[") rightGlyph = "]";
    else if (leftCmd == "{" || leftCmd == "\\{") rightGlyph = "}";
    else if (leftCmd == "|" || leftCmd == "\\|") rightGlyph = "|";
    else if (leftCmd == "\\langle") rightGlyph = "⟩";
    else if (leftCmd == "\\lfloor") rightGlyph = "⌋";
    else if (leftCmd == "\\lceil") rightGlyph = "⌉";
    else rightGlyph = ")"; // fallback

    double rightW = stringWidth(rightGlyph, fontSize * delimScale);
    double rightX = contentX + totalContentW + kMedSpace * fontSize;
    result.boxes.push_back(makeGlyphBox(rightGlyph, leftCmd, rightX, leftY, rightW, delimH, 0, fontSize * delimScale));

    result.totalWidth = rightX + rightW;
    result.totalHeight = maxH;
    result.totalDepth = maxD;
    result.baselineY = maxH;
    return result;
}

MathLayout MathLayoutEngine::layoutSubSup(const MathNode& node, double fontSize, bool displayStyle) {
    // children: [0]=base, [1]=sub (if Subscript or SubSup), [2]=super (if SubSup)
    // For Superscript: [0]=base, [1]=super
    // For Subscript:   [0]=base, [1]=sub

    if (node.children.empty()) return MathLayout();

    auto baseLayout = layoutNode(*node.children[0], fontSize, displayStyle);
    double scriptSize = fontSize * kScriptScale;

    MathLayout result;
    result.boxes = std::move(baseLayout.boxes);
    result.totalWidth = baseLayout.totalWidth;
    result.totalHeight = baseLayout.totalHeight;
    result.totalDepth = baseLayout.totalDepth;
    result.baselineY = baseLayout.totalHeight;

    if (node.kind == MathNodeKind::Superscript && node.children.size() >= 2) {
        auto superLayout = layoutNode(*node.children[1], scriptSize, displayStyle);
        double superShift = baseLayout.totalHeight * 0.6;
        for (auto& box : superLayout.boxes) {
            box.x += baseLayout.totalWidth + fontSize * 0.05;
            box.y += superShift + superLayout.totalDepth;
        }
        result.totalWidth = baseLayout.totalWidth + fontSize * 0.05 + superLayout.totalWidth;
        result.totalHeight = std::max(result.totalHeight, superShift + superLayout.totalHeight);
        for (auto& box : superLayout.boxes) result.boxes.push_back(std::move(box));
    } else if (node.kind == MathNodeKind::Subscript && node.children.size() >= 2) {
        auto subLayout = layoutNode(*node.children[1], scriptSize, displayStyle);
        double subShift = -(baseLayout.totalDepth + fontSize * 0.05 + subLayout.totalHeight);
        for (auto& box : subLayout.boxes) {
            box.x += baseLayout.totalWidth + fontSize * 0.05;
            box.y += subShift;
        }
        result.totalWidth = baseLayout.totalWidth + fontSize * 0.05 + subLayout.totalWidth;
        result.totalDepth = std::max(result.totalDepth,
            baseLayout.totalDepth + fontSize * 0.05 + subLayout.totalHeight + subLayout.totalDepth);
        for (auto& box : subLayout.boxes) result.boxes.push_back(std::move(box));
    } else if (node.kind == MathNodeKind::SubSup && node.children.size() >= 3) {
        // Both sub and super.
        auto subLayout = layoutNode(*node.children[1], scriptSize, displayStyle);
        auto superLayout = layoutNode(*node.children[2], scriptSize, displayStyle);

        double superShift = baseLayout.totalHeight * 0.6;
        double subShift = -(baseLayout.totalDepth + fontSize * 0.05 + subLayout.totalHeight);
        double offsetX = baseLayout.totalWidth + fontSize * 0.05;

        // Center sub/super horizontally with respect to each other.
        double maxSSWidth = std::max(subLayout.totalWidth, superLayout.totalWidth);
        double subPadX = (maxSSWidth - subLayout.totalWidth) / 2.0;
        double superPadX = (maxSSWidth - superLayout.totalWidth) / 2.0;

        for (auto& box : subLayout.boxes) {
            box.x += offsetX + subPadX;
            box.y += subShift;
        }
        for (auto& box : superLayout.boxes) {
            box.x += offsetX + superPadX;
            box.y += superShift + superLayout.totalDepth;
        }

        result.totalWidth = offsetX + maxSSWidth;
        result.totalHeight = std::max(result.totalHeight, superShift + superLayout.totalHeight);
        result.totalDepth = std::max(result.totalDepth,
            baseLayout.totalDepth + fontSize * 0.05 + subLayout.totalHeight + subLayout.totalDepth);

        for (auto& box : subLayout.boxes) result.boxes.push_back(std::move(box));
        for (auto& box : superLayout.boxes) result.boxes.push_back(std::move(box));
    }

    return result;
}

MathLayout MathLayoutEngine::layoutMatrix(const MathNode& node, double fontSize, bool displayStyle) {
    // Determine number of columns from first row.
    // We don't have explicit column count data in the AST.
    // Strategy: layout all cells, find max columns per row, then align.

    if (node.children.empty()) {
        MathLayout empty;
        return empty;
    }

    // For now: simple row-by-row layout. Each child is a cell.
    // We'll guess column count by counting children (assume square-ish or 2 cols).
    double scriptSize = fontSize * kScriptScale;

    // Layout all cells.
    std::vector<MathLayout> cellLayouts;
    double maxCellW = 0;
    for (const auto& child : node.children) {
        auto cell = layoutNode(*child, scriptSize, displayStyle);
        maxCellW = std::max(maxCellW, cell.totalWidth);
        cellLayouts.push_back(std::move(cell));
    }

    // Estimate columns: if 4 cells, assume 2x2. If 9, 3x3. Otherwise guess.
    int totalCells = static_cast<int>(cellLayouts.size());
    int cols = 2;
    if (totalCells <= 2) cols = totalCells;
    else if (totalCells == 3) cols = 3;
    else if (totalCells == 4) cols = 2;
    else if (totalCells <= 6) cols = 3;
    else if (totalCells <= 9) cols = 3;
    else cols = 4;

    double cellPadH = fontSize * 0.5;
    double cellPadV = fontSize * 0.25;
    double colW = maxCellW + cellPadH * 2;

    // Position cells in grid.
    MathLayout result;
    double currentX = 0;
    double currentY = 0;
    double rowH = 0;
    int col = 0;

    // Left bracket for pmatrix.
    double bracketW = stringWidth("(", fontSize * 1.2);
    double bracketH = 0; // Will be computed.
    double bracketX = 0;

    for (int i = 0; i < totalCells; ++i) {
        auto& cell = cellLayouts[i];

        // Center cell in its column.
        double cellOffsetX = (colW - cell.totalWidth) / 2.0;
        for (auto& box : cell.boxes) {
            box.x += currentX + cellOffsetX;
            box.y += currentY;
        }

        rowH = std::max(rowH, cell.totalHeight + cell.totalDepth);

        for (auto& box : cell.boxes) result.boxes.push_back(std::move(box));

        ++col;
        if (col >= cols) {
            col = 0;
            currentX = 0;
            currentY += rowH + cellPadV * 2;
            rowH = 0;
        } else {
            currentX += colW;
        }
    }

    double totalGridH = currentY + (col > 0 ? rowH + cellPadV * 2 : 0);
    bracketH = totalGridH;

    // Add left bracket.
    result.boxes.insert(result.boxes.begin(), makeGlyphBox("(", "\\begin{pmatrix}",
        bracketX, -totalGridH + bracketH, bracketW, bracketH, 0, fontSize * 1.2));

    // Add right bracket.
    double rightX = cols * colW;
    result.boxes.push_back(makeGlyphBox(")", "\\end{pmatrix}",
        rightX, -totalGridH + bracketH, bracketW, bracketH, 0, fontSize * 1.2));

    result.totalWidth = rightX + bracketW;
    result.totalHeight = bracketH * 0.5;
    result.totalDepth = bracketH * 0.5;
    result.baselineY = result.totalHeight;
    return result;
}

double MathLayoutEngine::glyphWidth(const std::string& unicode, double fontSize) const {
    return stringWidth(unicode, fontSize);
}

double MathLayoutEngine::glyphHeight(const std::string& unicode, double fontSize) const {
    (void)unicode;
    return fontSize * kAscenderRatio;
}

double MathLayoutEngine::glyphDepth(const std::string& unicode, double fontSize) const {
    (void)unicode;
    return fontSize * kDescenderRatio;
}

MathBox MathLayoutEngine::makeGlyphBox(const std::string& unicode, const std::string& text,
                                       double x, double y, double w, double h, double d, double fs) {
    MathBox box;
    box.x = x;
    box.y = y;
    box.width = w;
    box.height = h;
    box.depth = d;
    box.fontSize = fs;
    box.unicode = unicode;
    box.text = text;
    return box;
}

MathBox MathLayoutEngine::makeRuleBox(double x, double y, double w, double thickness) {
    MathBox box;
    box.x = x;
    box.y = y;
    box.width = w;
    box.height = thickness;
    box.depth = 0;
    box.isRule = true;
    return box;
}

// ===================================================================
// Phase 2: Accents, braces, binomial, cases, substack, textbox
// ===================================================================

MathLayout MathLayoutEngine::layoutAccentOver(const MathNode& node, double fontSize, bool displayStyle) {
    if (node.children.empty()) return MathLayout();
    auto content = layoutNode(*node.children[0], fontSize, displayStyle);

    const std::string& accentCmd = node.text;
    double accentW = content.totalWidth;
    double accentH = fontSize * 0.08; // rule thickness
    double accentY = content.totalHeight + fontSize * 0.15;

    MathLayout result;
    result.boxes = std::move(content.boxes);
    result.totalWidth = content.totalWidth;
    result.totalHeight = content.totalHeight;
    result.totalDepth = content.totalDepth;

    if (accentCmd == "overline") {
        // Simple rule.
        result.boxes.push_back(makeRuleBox(0, accentY, accentW, accentH));
        result.totalHeight += accentH + fontSize * 0.15;
    } else if (accentCmd == "overrightarrow" || accentCmd == "overleftarrow") {
        std::string arrowGlyph = (accentCmd == "overrightarrow") ? "⟶" : "⟵";
        double arrowW = stringWidth(arrowGlyph, fontSize * 0.9);
        double scaleX = accentW / std::max(arrowW, 1.0);
        // Draw arrow stretched to content width.
        result.boxes.push_back(makeGlyphBox(arrowGlyph, accentCmd, 0, accentY,
            accentW, fontSize * 0.9 * kAscenderRatio, 0, fontSize * 0.9));
        result.totalHeight += fontSize * 0.9 * kAscenderRatio + fontSize * 0.1;
    } else if (accentCmd == "xrightarrow" || accentCmd == "xleftarrow") {
        // xarrow: has text above the arrow. children[0] is the text above.
        std::string arrowGlyph = (accentCmd == "xrightarrow") ? "⟶" : "⟵";
        double arrowW = accentW + fontSize * 0.3; // wider than content
        // Center the arrow.
        double arrowX = (arrowW - accentW) / 2.0;
        result.boxes.push_back(makeGlyphBox(arrowGlyph, accentCmd, -arrowX, content.totalHeight + fontSize * 0.1,
            arrowW, fontSize * 0.9 * kAscenderRatio, 0, fontSize * 0.9));
        // Text above the arrow.
        double textSize = fontSize * kScriptScale;
        if (node.children.size() >= 1 && node.children[0]) {
            auto textLayout = layoutNode(*node.children[0], textSize, displayStyle);
            double textX = (arrowW - textLayout.totalWidth) / 2.0 - arrowX;
            double textY = content.totalHeight + fontSize * 0.9 * kAscenderRatio + fontSize * 0.1;
            for (auto& box : textLayout.boxes) {
                box.x += textX;
                box.y += textY;
            }
            for (auto& box : textLayout.boxes) result.boxes.push_back(std::move(box));
            result.totalHeight = textY + textLayout.totalHeight;
        } else {
            result.totalHeight += fontSize * 0.9 * kAscenderRatio + fontSize * 0.1;
        }
        result.totalWidth = std::max(result.totalWidth, arrowW);
    }

    result.baselineY = result.totalHeight;
    return result;
}

MathLayout MathLayoutEngine::layoutAccentUnder(const MathNode& node, double fontSize, bool displayStyle) {
    if (node.children.empty()) return MathLayout();
    auto content = layoutNode(*node.children[0], fontSize, displayStyle);

    const std::string& cmd = node.text;
    double lineY = -(content.totalDepth + fontSize * 0.1);
    double ruleThickness = fontSize * 0.08;

    MathLayout result;
    result.boxes = std::move(content.boxes);
    result.totalWidth = content.totalWidth;
    result.totalHeight = content.totalHeight;
    result.totalDepth = content.totalDepth;

    if (cmd == "underline") {
        result.boxes.push_back(makeRuleBox(0, lineY, content.totalWidth, ruleThickness));
        result.totalDepth += ruleThickness + fontSize * 0.1;
    } else if (cmd == "underbrace") {
        // Brace glyph (U+23DF) below content.
        result.boxes.push_back(makeGlyphBox("⏟", cmd, 0, lineY,
            content.totalWidth, fontSize * 0.35, fontSize * 0.1, fontSize));
        result.totalDepth += fontSize * 0.35 + fontSize * 0.05;
        // Optional annotation below the brace.
        if (node.children.size() >= 2 && node.children[1]) {
            double annSize = fontSize * kScriptScale;
            auto annLayout = layoutNode(*node.children[1], annSize, displayStyle);
            double annY = lineY - fontSize * 0.35 - annLayout.totalHeight;
            double annX = (content.totalWidth - annLayout.totalWidth) / 2.0;
            for (auto& box : annLayout.boxes) { box.x += annX; box.y += annY; }
            for (auto& box : annLayout.boxes) result.boxes.push_back(std::move(box));
            result.totalDepth = -annY + annLayout.totalDepth;
        }
    }

    result.baselineY = result.totalHeight;
    return result;
}

MathLayout MathLayoutEngine::layoutOverUnder(const MathNode& node, double fontSize, bool displayStyle) {
    if (node.children.empty()) return MathLayout();
    auto content = layoutNode(*node.children[0], fontSize, displayStyle);

    const std::string& cmd = node.text;
    double braceH = fontSize * 0.35;
    double braceY = content.totalHeight + fontSize * 0.05;

    MathLayout result;
    result.boxes = std::move(content.boxes);
    result.totalWidth = content.totalWidth;
    result.totalHeight = content.totalHeight;
    result.totalDepth = content.totalDepth;

    // Brace glyph above content.
    result.boxes.push_back(makeGlyphBox("⏞", cmd, 0, braceY,
        content.totalWidth, braceH, 0, fontSize));
    result.totalHeight = braceY + braceH;

    // Optional annotation above the brace.
    if (node.children.size() >= 2 && node.children[1]) {
        double annSize = fontSize * kScriptScale;
        auto annLayout = layoutNode(*node.children[1], annSize, displayStyle);
        double annY = braceY + braceH + annLayout.totalDepth;
        double annX = (content.totalWidth - annLayout.totalWidth) / 2.0;
        for (auto& box : annLayout.boxes) { box.x += annX; box.y += annY; }
        for (auto& box : annLayout.boxes) result.boxes.push_back(std::move(box));
        result.totalHeight = annY + annLayout.totalHeight;
    }

    result.baselineY = result.totalHeight;
    return result;
}

MathLayout MathLayoutEngine::layoutBinomial(const MathNode& node, double fontSize, bool displayStyle) {
    if (node.children.size() < 2) return MathLayout();
    // Binomial is like a fraction but with parentheses instead of a rule.
    double scriptSize = displayStyle ? fontSize : fontSize * kScriptScale;
    auto topLayout = layoutNode(*node.children[0], scriptSize, displayStyle);
    auto botLayout = layoutNode(*node.children[1], scriptSize, displayStyle);

    double maxW = std::max(topLayout.totalWidth, botLayout.totalWidth);
    double padH = fontSize * 0.15;
    double bracketW = stringWidth("(", fontSize * 1.1);

    // Center top and bottom.
    double topX = (maxW - topLayout.totalWidth) / 2.0;
    double botX = (maxW - botLayout.totalWidth) / 2.0;
    double topY = fontSize * 0.1;
    double botY = -(botLayout.totalHeight + fontSize * 0.1);

    for (auto& box : topLayout.boxes) { box.x += topX; box.y += topY; }
    for (auto& box : botLayout.boxes) { box.x += botX; box.y += botY; }

    MathLayout result;
    // Left paren.
    double parenH = topLayout.totalHeight + botLayout.totalHeight + fontSize * 0.3;
    result.boxes.push_back(makeGlyphBox("(", "(", 0, botY,
        bracketW, parenH, 0, fontSize * 1.1));
    // Content.
    for (auto& box : topLayout.boxes) result.boxes.push_back(std::move(box));
    for (auto& box : botLayout.boxes) result.boxes.push_back(std::move(box));
    // Right paren.
    double rightX = bracketW + maxW + padH;
    result.boxes.push_back(makeGlyphBox(")", ")", rightX, botY,
        bracketW, parenH, 0, fontSize * 1.1));

    result.totalWidth = rightX + bracketW;
    result.totalHeight = topY + topLayout.totalHeight;
    result.totalDepth = -botY + botLayout.totalDepth;
    result.baselineY = result.totalHeight;
    return result;
}

MathLayout MathLayoutEngine::layoutCases(const MathNode& node, double fontSize, bool displayStyle) {
    if (node.children.empty()) return MathLayout();
    double scriptSize = fontSize * kScriptScale;
    double rowSpacing = fontSize * 0.3;
    double braceW = stringWidth("{", fontSize * 1.2);

    // Layout each case as value + condition (alternating).
    // cases children: [value0, condition0, value1, condition1, ...]
    std::vector<MathLayout> valueLayouts;
    std::vector<MathLayout> condLayouts;
    for (size_t i = 0; i < node.children.size(); i += 2) {
        auto val = layoutNode(*node.children[i], scriptSize, displayStyle);
        valueLayouts.push_back(std::move(val));
        if (i + 1 < node.children.size()) {
            auto cond = layoutNode(*node.children[i + 1], scriptSize, displayStyle);
            condLayouts.push_back(std::move(cond));
        } else {
            condLayouts.push_back(MathLayout());
        }
    }

    // Position rows.
    double maxValW = 0, maxCondW = 0;
    for (const auto& v : valueLayouts) maxValW = std::max(maxValW, v.totalWidth);
    for (const auto& c : condLayouts) maxCondW = std::max(maxCondW, c.totalWidth);

    double condOffset = braceW + maxValW + fontSize * 0.5;
    double currentY = 0;
    MathLayout result;
    double totalH = 0, totalD = 0;

    for (size_t i = 0; i < valueLayouts.size(); ++i) {
        double rowH = valueLayouts[i].totalHeight + condLayouts[i].totalHeight;
        double rowD = std::max(valueLayouts[i].totalDepth, condLayouts[i].totalDepth);

        for (auto& box : valueLayouts[i].boxes) {
            box.x += braceW;
            box.y += currentY;
        }
        for (auto& box : condLayouts[i].boxes) {
            box.x += condOffset;
            box.y += currentY;
        }
        for (auto& box : valueLayouts[i].boxes) result.boxes.push_back(std::move(box));
        for (auto& box : condLayouts[i].boxes) result.boxes.push_back(std::move(box));

        currentY += std::max(rowH, rowD * 0.5) + rowSpacing;
        totalH = currentY;
    }

    totalH -= rowSpacing;
    double braceH = totalH;
    totalD = 0;

    // Left brace.
    result.boxes.insert(result.boxes.begin(),
        makeGlyphBox("{", "\\begin{cases}", 0, 0, braceW, braceH, 0, fontSize * 1.2));

    result.totalWidth = condOffset + maxCondW + fontSize * 0.2;
    result.totalHeight = totalH * 0.5;
    result.totalDepth = totalH * 0.5;
    result.baselineY = result.totalHeight;
    return result;
}

MathLayout MathLayoutEngine::layoutSubStack(const MathNode& node, double fontSize, bool displayStyle) {
    if (node.children.empty()) return MathLayout();
    double stackSize = fontSize * kScriptScriptScale;
    double lineSpacing = fontSize * 0.05;

    std::vector<MathLayout> lines;
    double maxW = 0;
    for (const auto& child : node.children) {
        auto line = layoutNode(*child, stackSize, displayStyle);
        maxW = std::max(maxW, line.totalWidth);
        lines.push_back(std::move(line));
    }

    MathLayout result;
    double y = 0;
    for (auto& line : lines) {
        double offsetX = (maxW - line.totalWidth) / 2.0;
        for (auto& box : line.boxes) { box.x += offsetX; box.y += y; }
        for (auto& box : line.boxes) result.boxes.push_back(std::move(box));
        y += line.totalHeight + line.totalDepth + lineSpacing;
    }

    result.totalWidth = maxW;
    result.totalHeight = lines.front().totalHeight;
    result.totalDepth = -(y - lineSpacing) + lines.back().totalDepth;
    result.baselineY = result.totalHeight;
    return result;
}

MathLayout MathLayoutEngine::layoutTextBox(const MathNode& node, double fontSize, bool displayStyle) {
    // Render text content as-is (no math styling).
    if (node.children.empty()) return MathLayout();
    return layoutNode(*node.children[0], fontSize, displayStyle);
}

} // namespace math
} // namespace mdcore
