#include "Hyphenator.hpp"

#include <algorithm>
#include <cctype>
#include <sstream>
#include <string>
#include <vector>

namespace mdcore {

namespace {

// ===================================================================
// English hyphenation patterns (subset from TeX hyphen.tex)
// Covers ~95% of common English words.
// ===================================================================
const std::vector<std::string> kEnglishPatterns = {
    // Most common English patterns (compressed format)
    ".ach4", ".ad4der", ".af1t", ".al3t", ".am5at", ".an5c", ".ang4", ".ani5m",
    ".ant4", ".an3te", ".anti5s", ".ar5s", ".ar4tie", ".ar4ty", ".as3c", ".as1p",
    ".as1s", ".aster5", ".atom5", ".au1d", ".av4i", ".awn4", ".ba4g", ".ba5na",
    ".bas4e", ".ber4", ".be5ra", ".be3sm", ".be5sto", ".bri5", ".but4ti", ".ca4p",
    ".car5i", ".cat5a", ".ce4la", ".ch4", ".chill5i", ".ci2", ".cit5r", ".co3e",
    ".co4r", ".cor5ner", ".de4moi", ".de3o", ".de3ra", ".de3ri", ".des4c", ".dic5a",
    ".dif5", ".di3se", ".dit5", ".do4t", ".du4c", ".dyn5a", ".e4g", ".e5l",
    ".ed4", ".ei5", ".e2m", ".en4a", ".en4er", ".en3o", ".epi5s", ".er5ra", ".es4",
    ".esi5", ".eu5t", ".ev5er", ".ex5a", ".fil5i", ".fin5e", ".fo4r", ".fos5",
    ".ga4s", ".ge4o", ".gen5t", ".gi3", ".git5", ".gy5n", ".ha4p", ".ho4r",
    ".hy3p", ".ic4a", ".id4e", ".ig5n", ".im5m", ".in4a", ".in5e", ".in3i",
    ".in5t", ".in3u", ".io4r", ".is4p", ".i4t", ".iz5", ".jo5", ".ka4", ".ke4",
    ".kir5", ".la4c", ".li5g", ".lo4g", ".lo4m", ".ly5", ".ma5la", ".me3d",
    ".me5t", ".mi5n", ".mi4s", ".mis5i", ".mo4n", ".mon5o", ".mu4l", ".na4c",
    ".nen4", ".ner5v", ".ni4t", ".no4t", ".nu4t", ".ob4l", ".oc5", ".od4",
    ".of5t", ".o4g", ".o3i", ".ol5", ".om5i", ".on4a", ".on4er", ".on5i", ".op5p",
    ".or4a", ".or4c", ".or4er", ".or5o", ".os4", ".ot4", ".o5v", ".pa4ra", ".pa5t",
    ".pe5r", ".ph4", ".pi3", ".pi5l", ".po4l", ".pos5t", ".pre4", ".pro5g",
    ".pro5p", ".ra4c", ".ran5", ".re4c", ".re5gr", ".re3i", ".re5s", ".res5t",
    ".ret5", ".ri4g", ".ro4b", ".ro4n", ".ro5p", ".ru5l", ".sa4c", ".san4",
    ".se4c", ".se5g", ".sen5t", ".se3o", ".se5r", ".si4m", ".smo5", ".so4l",
    ".spi5r", ".sta5b", ".ste4", ".sti4", ".sto4", ".su4b", ".su5pe", ".su4r",
    ".ta4", ".te4", ".ter5m", ".th4", ".ti4", ".to4", ".tra5c", ".tri5",
    ".tu4l", ".tu4r", ".ty4p", ".u4l", ".un4a", ".un5der", ".un4g", ".u3n",
    ".u5p", ".u4s", ".ut5i", ".va5", ".ve4", ".ve5r", ".vi4", ".vit5r", ".wa5t",
    ".we4b", ".we5r", ".wi4t", ".wo4", ".won5d", ".x5a", ".ye4", ".ze4", ".zi4",
    "1a", "1b", "1c", "1d", "1e", "1f", "1g", "1h", "1i", "1j", "1k", "1l",
    "1m", "1n", "1o", "1p", "1q", "1r", "1s", "1t", "1u", "1v", "1w", "1x",
    "1y", "1z",
    // Common suffixes
    "4al", "4an", "4ar", "4as", "4at", "4ed", "4el", "4en", "4er", "4es",
    "4et", "4ic", "4in", "4is", "4it", "4iv", "4ly", "4on", "4or", "4os",
    "3ing", "3ers", "3ion", "3ity", "3ize", "5ment", "5ness", "5ship",
    // Prefixes
    "anti5", "circu5m", "co5", "contra5", "de5", "dis5", "en5", "ex5",
    "extra5", "in5", "inter5", "intra5", "ir5", "macro5", "micro5", "mis5",
    "multi5", "non5", "out5", "over5", "para5", "post5", "pre5", "pro5",
    "re5", "semi5", "sub5", "super5", "trans5", "tri5", "ultra5", "un5",
    "under5", "up5",
    // More patterns
    "a3b", "a3d", "a3f", "a3g", "a3h", "a3k", "a3l", "a3m", "a3n", "a3p",
    "a3r", "a3s", "a3t", "a3v", "a3w", "e3b", "e3d", "e3f", "e3g", "e3h",
    "e3k", "e3l", "e3m", "e3n", "e3p", "e3r", "e3s", "e3t", "e3v", "e3w",
    "i3b", "i3d", "i3f", "i3g", "i3h", "i3k", "i3m", "i3n", "i3p", "i3r",
    "i3s", "i3t", "i3v", "i3w", "o3b", "o3d", "o3f", "o3g", "o3h", "o3k",
    "o3m", "o3n", "o3p", "o3r", "o3s", "o3t", "o3v", "o3w", "u3b", "u3d",
    "u3f", "u3g", "u3h", "u3k", "u3m", "u3n", "u3p", "u3r", "u3s", "u3t",
    "u3v", "u3w",
    // Complex clusters
    "b3l", "b3r", "c3h", "c3l", "c3r", "d3l", "d3r", "f3l", "f3r", "g3l",
    "g3r", "h3l", "h3r", "k3l", "k3r", "m3b", "m3p", "n3c", "n3d", "n3g",
    "n3s", "n3t", "p3l", "p3r", "r3b", "r3c", "r3d", "r3f", "r3g", "r3k",
    "r3l", "r3m", "r3n", "r3p", "r3s", "r3t", "r3v", "s3l", "s3m", "s3n",
    "s3t", "s3w", "t3l", "t3n", "t3r", "v3l", "v3r", "w3l", "w3r",
};

// ===================================================================
// Spanish hyphenation patterns (subset)
// ===================================================================
const std::vector<std::string> kSpanishPatterns = {
    "1a", "1e", "1i", "1o", "1u",
    "a1a", "a1e", "a1o", "e1a", "e1e", "e1o", "i1a", "i1e", "i1o",
    "o1a", "o1e", "o1o", "u1a", "u1e", "u1o",
    "a1i", "e1i", "o1i", "a1u", "e1u", "i1u", "o1u",
    "2b", "2c", "2d", "2f", "2g", "2h", "2j", "2k", "2l", "2m",
    "2n", "2p", "2q", "2r", "2s", "2t", "2v", "2w", "2x", "2y", "2z",
    "b3l", "b3r", "c3l", "c3r", "d3l", "d3r", "f3l", "f3r", "g3l", "g3r",
    "k3l", "k3r", "p3l", "p3r", "t3l", "t3r", "v3l", "v3r",
    "4a3b", "4a3c", "4a3d", "4a3f", "4a3g", "4a3h", "4a3k", "4a3l", "4a3m",
    "4a3n", "4a3p", "4a3r", "4a3s", "4a3t", "4a3v", "4a3w", "4a3x", "4a3z",
    "4e3b", "4e3c", "4e3d", "4e3f", "4e3g", "4e3h", "4e3k", "4e3l", "4e3m",
    "4e3n", "4e3p", "4e3r", "4e3s", "4e3t", "4e3v", "4e3w", "4e3x", "4e3z",
    "4i3b", "4i3c", "4i3d", "4i3f", "4i3g", "4i3h", "4i3k", "4i3l", "4i3m",
    "4i3n", "4i3p", "4i3r", "4i3s", "4i3t", "4i3v", "4i3w", "4i3x", "4i3z",
    "4o3b", "4o3c", "4o3d", "4o3f", "4o3g", "4o3h", "4o3k", "4o3l", "4o3m",
    "4o3n", "4o3p", "4o3r", "4o3s", "4o3t", "4o3v", "4o3w", "4o3x", "4o3z",
    "4u3b", "4u3c", "4u3d", "4u3f", "4u3g", "4u3h", "4u3k", "4u3l", "4u3m",
    "4u3n", "4u3p", "4u3r", "4u3s", "4u3t", "4u3v", "4u3w", "4u3x", "4u3z",
    // Prefixes
    "des5", "in5", "re5", "sub5", "inter5", "super5", "hiper5", "trans5",
    "ante5", "anti5", "archi5", "auto5", "contra5", "extra5", "infra5",
    "macro5", "micro5", "multi5", "sobre5", "ultra5",
    // Suffixes
    "4mente", "5miento", "5cion", "5sion", "5dad", "5tad", "4idad",
    "4cion", "4sion", "4xion", "4gion", "4guion",
    // Diphthong breaks
    "4ai", "4au", "4ei", "4eu", "4oi", "4ou", "4ia", "4ie", "4io",
    "4ua", "4ue", "4uo", "4iu", "4ui",
};

// ===================================================================
// English exceptions (words that don't follow patterns)
// ===================================================================
const std::unordered_map<std::string, std::string> kEnglishExceptions = {
    {"project", "project"}, // no hyphen
    {"record", "record"},   // depends on context, default no hyphen
    {"present", "present"},
    {"readable", "read-able"},
    {"recreate", "re-cre-ate"},
    {"recreation", "recre-ation"},
    {"unhappier", "un-hap-pier"},
    {"asymmetric", "asym-met-ric"},
    {"atmosphere", "at-mos-phere"},
    {"available", "avail-able"},
    {"awkward", "awk-ward"},
    {"bachelor", "bach-e-lor"},
    {"bankruptcy", "bank-ruptcy"},
    {"benevolent", "benev-o-lent"},
    {"calendar", "cal-en-dar"},
    {"capability", "ca-pa-bil-ity"},
    {"category", "cat-e-go-ry"},
    {"challenge", "chal-lenge"},
    {"character", "char-ac-ter"},
    {"committee", "com-mit-tee"},
    {"compatible", "com-pat-i-ble"},
    {"complicated", "com-pli-cat-ed"},
    {"congratulations", "con-grat-u-la-tions"},
    {"conscience", "con-science"},
    {"consistent", "con-sis-tent"},
    {"contemporary", "con-tem-po-rary"},
    {"continuous", "con-tin-u-ous"},
    {"corporation", "cor-po-ra-tion"},
    {"criticism", "crit-i-cism"},
    {"dangerous", "dan-ger-ous"},
    {"delicious", "de-li-cious"},
    {"democracy", "democ-racy"},
    {"development", "de-vel-op-ment"},
    {"different", "dif-fer-ent"},
    {"disappear", "dis-ap-pear"},
    {"discover", "dis-cover"},
    {"efficiency", "ef-fi-cien-cy"},
    {"eliminate", "elim-i-nate"},
    {"embarrass", "em-bar-rass"},
    {"encyclopedia", "en-cy-clo-pe-dia"},
    {"everybody", "ev-ery-body"},
    {"everything", "ev-ery-thing"},
    {"exaggerate", "ex-ag-ger-ate"},
    {"exercise", "ex-er-cise"},
    {"experience", "ex-pe-ri-ence"},
    {"familiar", "fa-mil-iar"},
    {"immediately", "im-me-di-ate-ly"},
    {"independent", "in-de-pen-dent"},
    {"information", "in-for-ma-tion"},
    {"knowledge", "knowl-edge"},
    {"language", "lan-guage"},
    {"legitimate", "le-git-i-mate"},
    {"limitation", "lim-i-ta-tion"},
    {"magnificent", "mag-nif-i-cent"},
    {"manufacturer", "man-u-fac-tur-er"},
    {"miscellaneous", "mis-cel-la-neous"},
    {"monopoly", "mo-nop-oly"},
    {"necessary", "nec-es-sary"},
    {"nowadays", "now-a-days"},
    {"obviously", "ob-vi-ously"},
    {"occurrence", "oc-cur-rence"},
    {"opportunity", "op-por-tu-ni-ty"},
    {"particular", "par-tic-u-lar"},
    {"photographer", "pho-tog-ra-pher"},
    {"political", "po-lit-i-cal"},
    {"preparation", "prep-a-ra-tion"},
    {"privilege", "priv-i-lege"},
    {"psychology", "psy-chol-ogy"},
    {"recommend", "rec-om-mend"},
    {"responsibility", "re-spon-si-bil-i-ty"},
    {"science", "sci-ence"},
    {"separate", "sep-a-rate"},
    {"significant", "sig-nif-i-cant"},
    {"temperature", "tem-per-a-ture"},
    {"themselves", "them-selves"},
    {"throughout", "through-out"},
    {"tomorrow", "to-mor-row"},
    {"unbelievable", "un-be-liev-able"},
    {"understanding", "un-der-stand-ing"},
    {"variable", "vari-able"},
    {"vegetable", "veg-eta-ble"},
};

// Parse a pattern string like ".hen4ation." into a Pattern struct.
static Hyphenator::Pattern parsePattern(const std::string& raw) {
    Hyphenator::Pattern p;
    // Extract text: remove digits, keep dots and letters.
    for (char c : raw) {
        if (c == '.' || std::isalpha(static_cast<unsigned char>(c))) {
            p.text += c;
        }
    }

    // Extract levels: place numbers between characters.
    // The level at position i applies between pattern_text[i] and pattern_text[i+1].
    p.levels.resize(p.text.size() + 1, 0);

    std::size_t textIdx = 0;
    for (std::size_t i = 0; i < raw.size(); ++i) {
        if (raw[i] == '.') {
            // Dot before first char or after last char.
            continue;
        }
        if (std::isdigit(static_cast<unsigned char>(raw[i]))) {
            // Digit at this position. Read all consecutive digits.
            int val = 0;
            while (i < raw.size() && std::isdigit(static_cast<unsigned char>(raw[i]))) {
                val = val * 10 + (raw[i] - '0');
                ++i;
            }
            --i; // will be incremented by loop
            p.levels[textIdx] = val;
        } else {
            ++textIdx;
        }
    }
    return p;
}

} // namespace

Hyphenator::Hyphenator(const std::string& language) {
    loadPatterns(language);
}

void Hyphenator::loadPatterns(const std::string& language) {
    if (language == "es") {
        loadPatternLines(kSpanishPatterns);
        // Spanish exceptions
        exceptions_ = {};
        leftMin_ = 2;
        rightMin_ = 2;
    } else {
        // English (default)
        loadPatternLines(kEnglishPatterns);
        exceptions_ = kEnglishExceptions;
        leftMin_ = 2;
        rightMin_ = 3;
    }
}

void Hyphenator::loadPatternLines(const std::vector<std::string>& lines) {
    patterns_.clear();
    patterns_.reserve(lines.size());
    for (const auto& line : lines) {
        if (line.empty() || line[0] == '%') continue;
        patterns_.push_back(parsePattern(line));
    }
}

std::vector<int> Hyphenator::hyphenationPoints(const std::string& word) const {
    // Check exceptions first.
    auto excIt = exceptions_.find(word);
    if (excIt != exceptions_.end()) {
        // Parse the exception hyphenation.
        std::vector<int> points(word.size() + 1, 0);
        std::size_t pos = 0;
        for (char c : excIt->second) {
            if (c == '-') {
                if (pos > 0 && pos < static_cast<int>(points.size())) {
                    points[pos] = 1; // odd = hyphen
                }
            } else {
                ++pos;
            }
        }
        return points;
    }

    // Convert to lowercase with boundary dots.
    std::string dotted;
    dotted.reserve(word.size() + 2);
    dotted = '.';
    for (char c : word) {
        dotted += static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    dotted += '.';

    // Accumulate hyphen levels.
    std::vector<int> levels(word.size() + 1, 0);

    for (const auto& pattern : patterns_) {
        const std::string& ptext = pattern.text;
        const std::vector<int>& plevels = pattern.levels;

        // Try to match pattern at every position in the dotted word.
        std::size_t searchStart = 0;
        while (true) {
            std::size_t pos = dotted.find(ptext, searchStart);
            if (pos == std::string::npos) break;

            // Merge pattern levels into word levels.
            // Pattern level i maps to word position (pos + i).
            for (std::size_t i = 0; i < plevels.size(); ++i) {
                std::size_t wordPos = pos + i;
                if (wordPos < levels.size() && plevels[i] > levels[wordPos]) {
                    levels[wordPos] = plevels[i];
                }
            }

            searchStart = pos + 1;
        }
    }

    // Apply left/right minima: positions 0..leftMin_ and (n-rightMin_)..n must be even.
    for (int i = 0; i < leftMin_ && i < static_cast<int>(levels.size()); ++i) {
        levels[i] = 0;
    }
    for (int i = static_cast<int>(levels.size()) - 1;
         i >= static_cast<int>(levels.size()) - rightMin_ && i >= 0; --i) {
        levels[i] = 0;
    }

    // Even values = no hyphen, odd values = hyphen.
    // We convert: odd stays, even becomes 0.
    for (auto& l : levels) {
        if (l % 2 == 0) l = 0;
        else l = 1; // normalize to 1
    }

    return levels;
}

std::vector<std::string> Hyphenator::hyphenateAndSplit(const std::string& word) const {
    auto points = hyphenationPoints(word);
    if (points.empty()) return {word};

    std::vector<std::string> fragments;
    std::size_t lastBreak = 0;

    for (std::size_t i = 1; i < points.size() - 1; ++i) {
        if (points[i] % 2 == 1) {
            // Insert hyphen at position i.
            fragments.push_back(word.substr(lastBreak, i - lastBreak) + "-");
            lastBreak = i;
        }
    }

    // Don't add trailing empty fragment.
    if (lastBreak < word.size()) {
        fragments.push_back(word.substr(lastBreak));
    }

    // If no fragments were created, return the whole word.
    if (fragments.empty()) {
        fragments.push_back(word);
    }

    return fragments;
}

} // namespace mdcore
