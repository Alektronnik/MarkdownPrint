#pragma once

#include <string>
#include <vector>
#include <unordered_map>

namespace mdcore {

/// Liang-Knuth hyphenation algorithm (TeX, 1983).
///
/// Splits words into syllables using language-specific patterns.
/// Zero external dependencies: patterns are embedded at compile time.
///
/// Usage:
///   Hyphenator hyp("es");  // or "en", "fr", etc.
///   auto points = hyp.hyphenate("internacionalizacion");
///   // points = {0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0}
///   // Insert hyphens at positions where value is odd.
class Hyphenator {
public:
    struct Pattern {
        std::string text;
        std::vector<int> levels;
    };

    explicit Hyphenator(const std::string& language = "en");

    /// Returns the allowed hyphenation points for a word.
    /// The returned vector has size = word.size() + 1.
    /// Index i corresponds to the position BEFORE character i.
    /// Odd values = hyphenation point, even = no hyphen.
    /// Positions 0 and size()-1 are always even (no hyphen at edges).
    /// Also respects minimum prefix/suffix length (default 2).
    std::vector<int> hyphenationPoints(const std::string& word) const;

    /// Convenience: splits a word at hyphenation points, inserting "-".
    /// Returns the hyphenated word fragments.
    /// Example: hyphenateAndSplit("internationalization")
    ///   -> {"interna-", "tionaliza-", "tion"}
    std::vector<std::string> hyphenateAndSplit(const std::string& word) const;

    /// Minimum characters before first hyphen.
    int leftMin() const { return leftMin_; }

    /// Minimum characters after last hyphen.
    int rightMin() const { return rightMin_; }

private:
    std::vector<Pattern> patterns_;
    std::unordered_map<std::string, std::string> exceptions_;
    int leftMin_ = 2;
    int rightMin_ = 2;

    void loadPatterns(const std::string& language);
    void loadPatternLines(const std::vector<std::string>& lines);
};

} // namespace mdcore
