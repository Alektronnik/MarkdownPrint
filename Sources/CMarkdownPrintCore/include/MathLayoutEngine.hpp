#pragma once

#include "MathAST.hpp"
#include <vector>

namespace mdcore {
namespace math {

// === Math Layout ===
//
// TeX-style box-and-glue layout for math expressions.
// Each MathBox has a width, height (above baseline), and depth (below baseline).

struct MathBox {
    double x = 0.0;       // horizontal offset from parent origin
    double y = 0.0;       // vertical offset from parent baseline
    double width = 0.0;
    double height = 0.0;  // above baseline (positive)
    double depth = 0.0;   // below baseline (positive)
    double fontSize = 12.0;

    // The Unicode text to render.
    std::string unicode;
    std::string text;     // fallback: ASCII or LaTeX command

    // True if this box represents a fraction rule (horizontal line).
    bool isRule = false;
    // True for radical root symbol (drawn with special glyph + overline).
    bool isRadical = false;
    // For radical: the radicand box this radical encloses.
    // The renderer uses this to draw the overline.
    double radicalContentHeight = 0.0;
    double radicalContentWidth = 0.0;
};

struct MathLayout {
    std::vector<MathBox> boxes;
    double totalWidth = 0.0;
    double totalHeight = 0.0;  // above baseline
    double totalDepth = 0.0;   // below baseline
    double baselineY = 0.0;    // position of baseline from top of bounding box (= totalHeight)
};

// === Layout Engine ===
//
// Walks a MathNode tree and produces a MathLayout with positioned boxes.

class MathLayoutEngine {
public:
    MathLayoutEngine();

    // Compute layout for a parsed math tree.
    // fontSize: base font size in points.
    // displayStyle: true for display math (bigger operators, limits above/below).
    MathLayout layout(const MathNodePtr& root, double fontSize, bool displayStyle);

private:
    // Internal recursive layout. Returns a MathLayout for the subtree.
    MathLayout layoutNode(const MathNode& node, double fontSize, bool displayStyle);

    // Helpers for specific node types.
    MathLayout layoutFraction(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutRadical(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutLargeOp(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutDelimited(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutSubSup(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutMatrix(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutAccentOver(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutAccentUnder(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutOverUnder(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutBinomial(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutCases(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutSubStack(const MathNode& node, double fontSize, bool displayStyle);
    MathLayout layoutTextBox(const MathNode& node, double fontSize, bool displayStyle);

    // Core Text sized helpers — these use approximate metrics.
    double glyphWidth(const std::string& unicode, double fontSize) const;
    double glyphHeight(const std::string& unicode, double fontSize) const;
    double glyphDepth(const std::string& unicode, double fontSize) const;

    // For building result layouts.
    static MathBox makeGlyphBox(const std::string& unicode, const std::string& text,
                                double x, double y, double w, double h, double d, double fs);
    static MathBox makeRuleBox(double x, double y, double w, double thickness);
};

} // namespace math
} // namespace mdcore
