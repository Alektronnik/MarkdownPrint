#pragma once

#include <string>
#include <vector>
#include "Block.hpp"
#include "Hyphenator.hpp"
#include "LayoutTypes.hpp"
#include "Token.hpp"

namespace mdcore {

struct MathGlyphInfo {
    double x, y, width, height, depth, fontSize;
    bool isRule, isRadical;
    std::string unicode;
    std::string text;
    double radicalContentHeight, radicalContentWidth;
};

struct MathLayoutInfo {
    std::vector<MathGlyphInfo> glyphs;
    double totalWidth, totalHeight, totalDepth, baselineY;
};

class Engine {
public:
    explicit Engine(const std::string& language = "en");

    std::string engineVersion() const;
    std::vector<Token> tokenize(const std::string& markdown) const;
    std::vector<Block> parse(const std::string& markdown) const;
    Layout layout(const std::string& markdown, double pageWidth, double pageHeight) const;

    MathLayoutInfo layoutMath(const std::string& latex, bool displayStyle, double fontSize) const;

    const Hyphenator& hyphenator() const { return hyphenator_; }

    /// Set text justification. Call before layout().
    void setJustifyText(bool v) const { justifyText_ = v; }
    bool justifyText() const { return justifyText_; }

private:
    Hyphenator hyphenator_;
    mutable bool justifyText_ = false;
};

} // namespace mdcore
