#include "MathParser.hpp"

#include <cctype>
#include <stdexcept>
#include <unordered_set>

namespace mdcore {
namespace math {

// ===================================================================
// SymbolTable implementation
// ===================================================================

SymbolTable::SymbolTable() {
    // Greek lowercase
    symbols_["alpha"]   = {"α", MathNodeKind::GreekLetter};
    symbols_["beta"]    = {"β", MathNodeKind::GreekLetter};
    symbols_["gamma"]   = {"γ", MathNodeKind::GreekLetter};
    symbols_["delta"]   = {"δ", MathNodeKind::GreekLetter};
    symbols_["epsilon"] = {"ε", MathNodeKind::GreekLetter};
    symbols_["zeta"]    = {"ζ", MathNodeKind::GreekLetter};
    symbols_["eta"]     = {"η", MathNodeKind::GreekLetter};
    symbols_["theta"]   = {"θ", MathNodeKind::GreekLetter};
    symbols_["iota"]    = {"ι", MathNodeKind::GreekLetter};
    symbols_["kappa"]   = {"κ", MathNodeKind::GreekLetter};
    symbols_["lambda"]  = {"λ", MathNodeKind::GreekLetter};
    symbols_["mu"]      = {"μ", MathNodeKind::GreekLetter};
    symbols_["nu"]      = {"ν", MathNodeKind::GreekLetter};
    symbols_["xi"]      = {"ξ", MathNodeKind::GreekLetter};
    symbols_["pi"]      = {"π", MathNodeKind::GreekLetter};
    symbols_["rho"]     = {"ρ", MathNodeKind::GreekLetter};
    symbols_["sigma"]   = {"σ", MathNodeKind::GreekLetter};
    symbols_["tau"]     = {"τ", MathNodeKind::GreekLetter};
    symbols_["upsilon"] = {"υ", MathNodeKind::GreekLetter};
    symbols_["phi"]     = {"φ", MathNodeKind::GreekLetter};
    symbols_["chi"]     = {"χ", MathNodeKind::GreekLetter};
    symbols_["psi"]     = {"ψ", MathNodeKind::GreekLetter};
    symbols_["omega"]   = {"ω", MathNodeKind::GreekLetter};

    // Greek variants
    symbols_["varepsilon"] = {"ε", MathNodeKind::GreekLetter};
    symbols_["vartheta"]   = {"ϑ", MathNodeKind::GreekLetter};
    symbols_["varpi"]      = {"ϖ", MathNodeKind::GreekLetter};
    symbols_["varrho"]     = {"ϱ", MathNodeKind::GreekLetter};
    symbols_["varsigma"]   = {"ς", MathNodeKind::GreekLetter};
    symbols_["varphi"]     = {"φ", MathNodeKind::GreekLetter};

    // Greek uppercase
    symbols_["Gamma"]   = {"Γ", MathNodeKind::GreekLetter};
    symbols_["Delta"]   = {"Δ", MathNodeKind::GreekLetter};
    symbols_["Theta"]   = {"Θ", MathNodeKind::GreekLetter};
    symbols_["Lambda"]  = {"Λ", MathNodeKind::GreekLetter};
    symbols_["Xi"]      = {"Ξ", MathNodeKind::GreekLetter};
    symbols_["Pi"]      = {"Π", MathNodeKind::GreekLetter};
    symbols_["Sigma"]   = {"Σ", MathNodeKind::GreekLetter};
    symbols_["Phi"]     = {"Φ", MathNodeKind::GreekLetter};
    symbols_["Psi"]     = {"Ψ", MathNodeKind::GreekLetter};
    symbols_["Omega"]   = {"Ω", MathNodeKind::GreekLetter};

    // Binary operators
    symbols_["pm"]     = {"±", MathNodeKind::MathSymbol, false, true};
    symbols_["mp"]     = {"∓", MathNodeKind::MathSymbol, false, true};
    symbols_["times"]  = {"×", MathNodeKind::MathSymbol, false, true};
    symbols_["div"]    = {"÷", MathNodeKind::MathSymbol, false, true};
    symbols_["cdot"]   = {"·", MathNodeKind::MathSymbol, false, true};
    symbols_["ast"]    = {"∗", MathNodeKind::MathSymbol, false, true};
    symbols_["star"]   = {"⋆", MathNodeKind::MathSymbol, false, true};
    symbols_["circ"]   = {"∘", MathNodeKind::MathSymbol, false, true};
    symbols_["bullet"] = {"∙", MathNodeKind::MathSymbol, false, true};
    symbols_["oplus"]  = {"⊕", MathNodeKind::MathSymbol, false, true};
    symbols_["ominus"] = {"⊖", MathNodeKind::MathSymbol, false, true};
    symbols_["otimes"] = {"⊗", MathNodeKind::MathSymbol, false, true};
    symbols_["oslash"] = {"⊘", MathNodeKind::MathSymbol, false, true};
    symbols_["odot"]   = {"⊙", MathNodeKind::MathSymbol, false, true};

    // Relations
    symbols_["leq"]      = {"≤", MathNodeKind::MathSymbol, false, false, true};
    symbols_["geq"]      = {"≥", MathNodeKind::MathSymbol, false, false, true};
    symbols_["neq"]      = {"≠", MathNodeKind::MathSymbol, false, false, true};
    symbols_["approx"]   = {"≈", MathNodeKind::MathSymbol, false, false, true};
    symbols_["equiv"]    = {"≡", MathNodeKind::MathSymbol, false, false, true};
    symbols_["sim"]      = {"∼", MathNodeKind::MathSymbol, false, false, true};
    symbols_["simeq"]    = {"≃", MathNodeKind::MathSymbol, false, false, true};
    symbols_["propto"]   = {"∝", MathNodeKind::MathSymbol, false, false, true};
    symbols_["parallel"] = {"∥", MathNodeKind::MathSymbol, false, false, true};
    symbols_["perp"]     = {"⊥", MathNodeKind::MathSymbol, false, false, true};
    symbols_["ll"]       = {"≪", MathNodeKind::MathSymbol, false, false, true};
    symbols_["gg"]       = {"≫", MathNodeKind::MathSymbol, false, false, true};
    symbols_["subset"]   = {"⊂", MathNodeKind::MathSymbol, false, false, true};
    symbols_["supset"]   = {"⊃", MathNodeKind::MathSymbol, false, false, true};
    symbols_["subseteq"] = {"⊆", MathNodeKind::MathSymbol, false, false, true};
    symbols_["supseteq"] = {"⊇", MathNodeKind::MathSymbol, false, false, true};
    symbols_["in"]       = {"∈", MathNodeKind::MathSymbol, false, false, true};
    symbols_["notin"]    = {"∉", MathNodeKind::MathSymbol, false, false, true};
    symbols_["ni"]       = {"∋", MathNodeKind::MathSymbol, false, false, true};

    // Arrows
    symbols_["to"]          = {"→", MathNodeKind::MathSymbol};
    symbols_["rightarrow"]  = {"→", MathNodeKind::MathSymbol};
    symbols_["Rightarrow"]  = {"⇒", MathNodeKind::MathSymbol};
    symbols_["leftarrow"]   = {"←", MathNodeKind::MathSymbol};
    symbols_["Leftarrow"]   = {"⇐", MathNodeKind::MathSymbol};
    symbols_["leftrightarrow"] = {"↔", MathNodeKind::MathSymbol};
    symbols_["Leftrightarrow"] = {"⇔", MathNodeKind::MathSymbol};
    symbols_["uparrow"]     = {"↑", MathNodeKind::MathSymbol};
    symbols_["Uparrow"]     = {"⇑", MathNodeKind::MathSymbol};
    symbols_["downarrow"]   = {"↓", MathNodeKind::MathSymbol};
    symbols_["Downarrow"]   = {"⇓", MathNodeKind::MathSymbol};
    symbols_["mapsto"]      = {"↦", MathNodeKind::MathSymbol};
    symbols_["longmapsto"]  = {"⟼", MathNodeKind::MathSymbol};
    symbols_["longrightarrow"] = {"⟶", MathNodeKind::MathSymbol};
    symbols_["Longrightarrow"] = {"⟹", MathNodeKind::MathSymbol};

    // Large operators
    symbols_["sum"]  = {"∑", MathNodeKind::MathSymbol, true};
    symbols_["prod"] = {"∏", MathNodeKind::MathSymbol, true};
    symbols_["int"]  = {"∫", MathNodeKind::MathSymbol, true};
    symbols_["iint"] = {"∬", MathNodeKind::MathSymbol, true};
    symbols_["iiint"]= {"∭", MathNodeKind::MathSymbol, true};
    symbols_["oint"] = {"∮", MathNodeKind::MathSymbol, true};
    symbols_["bigcup"]   = {"⋃", MathNodeKind::MathSymbol, true};
    symbols_["bigcap"]   = {"⋂", MathNodeKind::MathSymbol, true};
    symbols_["bigvee"]   = {"⋁", MathNodeKind::MathSymbol, true};
    symbols_["bigwedge"] = {"⋀", MathNodeKind::MathSymbol, true};
    symbols_["bigoplus"] = {"⨁", MathNodeKind::MathSymbol, true};
    symbols_["bigotimes"]= {"⨂", MathNodeKind::MathSymbol, true};
    symbols_["coprod"]   = {"∐", MathNodeKind::MathSymbol, true};

    // Misc symbols
    symbols_["infty"]    = {"∞", MathNodeKind::MathSymbol};
    symbols_["partial"]  = {"∂", MathNodeKind::MathSymbol};
    symbols_["nabla"]    = {"∇", MathNodeKind::MathSymbol};
    symbols_["forall"]   = {"∀", MathNodeKind::MathSymbol};
    symbols_["exists"]   = {"∃", MathNodeKind::MathSymbol};
    symbols_["neg"]      = {"¬", MathNodeKind::MathSymbol};
    symbols_["emptyset"] = {"∅", MathNodeKind::MathSymbol};
    symbols_["varnothing"] = {"∅", MathNodeKind::MathSymbol};
    symbols_["Re"]       = {"ℜ", MathNodeKind::MathSymbol};
    symbols_["Im"]       = {"ℑ", MathNodeKind::MathSymbol};
    symbols_["aleph"]    = {"ℵ", MathNodeKind::MathSymbol};
    symbols_["hbar"]     = {"ℏ", MathNodeKind::MathSymbol};
    symbols_["ell"]      = {"ℓ", MathNodeKind::MathSymbol};
    symbols_["wp"]       = {"℘", MathNodeKind::MathSymbol};
    symbols_["angle"]    = {"∠", MathNodeKind::MathSymbol};
    symbols_["triangle"] = {"△", MathNodeKind::MathSymbol};
    symbols_["square"]   = {"□", MathNodeKind::MathSymbol};
    symbols_["Box"]      = {"□", MathNodeKind::MathSymbol};
    symbols_["diamond"]  = {"◇", MathNodeKind::MathSymbol};
    symbols_["clubsuit"] = {"♣", MathNodeKind::MathSymbol};
    symbols_["diamondsuit"] = {"♢", MathNodeKind::MathSymbol};
    symbols_["heartsuit"]= {"♡", MathNodeKind::MathSymbol};
    symbols_["spadesuit"]= {"♠", MathNodeKind::MathSymbol};
    symbols_["top"]      = {"⊤", MathNodeKind::MathSymbol};
    symbols_["bot"]      = {"⊥", MathNodeKind::MathSymbol};
    symbols_["vdash"]    = {"⊢", MathNodeKind::MathSymbol};
    symbols_["dashv"]    = {"⊣", MathNodeKind::MathSymbol};
    symbols_["models"]   = {"⊧", MathNodeKind::MathSymbol};
    symbols_["wr"]       = {"≀", MathNodeKind::MathSymbol};

    // Dots
    symbols_["dots"]     = {"…", MathNodeKind::MathSymbol};
    symbols_["cdots"]    = {"⋯", MathNodeKind::MathSymbol};
    symbols_["vdots"]    = {"⋮", MathNodeKind::MathSymbol};
    symbols_["ddots"]    = {"⋱", MathNodeKind::MathSymbol};
    symbols_["ldots"]    = {"…", MathNodeKind::MathSymbol};

    // Delimiter pairs.
    delimPairs_["("]  = ")";
    delimPairs_["["]  = "]";
    delimPairs_["{"]  = "}";
    delimPairs_["|"]  = "|";
    delimPairs_["\\|"] = "\\|";
    delimPairs_["\\lfloor"] = "\\rfloor";
    delimPairs_["\\lceil"]  = "\\rceil";
    delimPairs_["\\langle"] = "\\rangle";

    // Phase 2: accents, braces, binomial, cases, substack.
    // These are recognized by the parser via command names, not via symbol table entries.
    // We register them as special commands for tokenizer passthrough.
    symbols_["overline"]       = {"", MathNodeKind::AccentOver};
    symbols_["underline"]      = {"", MathNodeKind::AccentUnder};
    symbols_["overrightarrow"] = {"⟶", MathNodeKind::AccentOver};
    symbols_["overleftarrow"]  = {"⟵", MathNodeKind::AccentOver};
    symbols_["xrightarrow"]    = {"⟶", MathNodeKind::AccentOver};
    symbols_["xleftarrow"]     = {"⟵", MathNodeKind::AccentOver};
    symbols_["underbrace"]     = {"⏟", MathNodeKind::AccentUnder};
    symbols_["overbrace"]      = {"⏞", MathNodeKind::OverUnder};
    symbols_["binom"]          = {"", MathNodeKind::Binomial};
    symbols_["substack"]       = {"", MathNodeKind::SubStack};
    symbols_["text"]           = {"", MathNodeKind::TextBox};
    symbols_["color"]          = {"", MathNodeKind::TextBox};
    symbols_["displaystyle"]   = {"", MathNodeKind::MathSymbol}; // ignored in parser

    // Function names (rendered in upright/roman, not italic).
    // These are stored as symbols too for lookup.
    for (const auto* fn : {"sin","cos","tan","cot","sec","csc",
        "arcsin","arccos","arctan",
        "sinh","cosh","tanh","coth",
        "ln","log","lg","exp",
        "det","ker","gcd","deg","hom",
        "lim","liminf","limsup","sup","inf","max","min",
        "arg","dim","Pr"}) {
        symbols_[fn] = {fn, MathNodeKind::Identifier};
    }
}

const SymbolTable& SymbolTable::instance() {
    static SymbolTable st;
    return st;
}

const SymbolInfo* SymbolTable::lookup(const std::string& command) const {
    auto it = symbols_.find(command);
    if (it != symbols_.end()) return &it->second;
    return nullptr;
}

bool SymbolTable::isLeftDelim(const std::string& cmd) const {
    return delimPairs_.count(cmd) > 0;
}

bool SymbolTable::isRightDelim(const std::string& cmd) const {
    for (const auto& p : delimPairs_) {
        if (p.second == cmd) return true;
    }
    return false;
}

std::string SymbolTable::matchingRightDelim(const std::string& leftCmd) const {
    auto it = delimPairs_.find(leftCmd);
    if (it != delimPairs_.end()) return it->second;
    return "";
}

bool SymbolTable::isFunctionName(const std::string& name) const {
    // Check if name was registered in the function list above.
    auto it = symbols_.find(name);
    return it != symbols_.end() && it->second.nodeKind == MathNodeKind::Identifier;
}

// ===================================================================
// Tokenizer
// ===================================================================

std::vector<MathToken> tokenizeMath(const std::string& source) {
    std::vector<MathToken> tokens;
    std::size_t i = 0;

    while (i < source.size()) {
        char c = source[i];

        // Whitespace
        if (std::isspace(static_cast<unsigned char>(c))) {
            ++i;
            continue;
        }

        // Backslash commands
        if (c == '\\') {
            ++i; // skip backslash

            // Read command name (letters only for standard commands).
            std::size_t start = i;
            while (i < source.size() && std::isalpha(static_cast<unsigned char>(source[i]))) {
                ++i;
            }

            std::string cmd = source.substr(start, i - start);

            // Handle \| (double-bar delimiter)
            if (cmd.empty() && i < source.size() && source[i] == '|') {
                cmd = "|";
                ++i;
            }

            // Look up in symbol table.
            const auto* info = SymbolTable::instance().lookup(cmd);

            if (cmd == "frac") {
                tokens.emplace_back(MathTokenKind::Command, "frac");
            } else if (cmd == "sqrt") {
                tokens.emplace_back(MathTokenKind::Command, "sqrt");
            } else if (cmd == "left") {
                tokens.emplace_back(MathTokenKind::Command, "left");
            } else if (cmd == "right") {
                tokens.emplace_back(MathTokenKind::Command, "right");
            } else if (cmd == "begin") {
                tokens.emplace_back(MathTokenKind::Command, "begin");
            } else if (cmd == "end") {
                tokens.emplace_back(MathTokenKind::Command, "end");
            } else if (info) {
                tokens.emplace_back(MathTokenKind::Command, cmd, info->unicode);
            } else {
                // Unknown command — treat as identifier (e.g., custom names).
                tokens.emplace_back(MathTokenKind::Identifier, "\\" + cmd, "\\" + cmd);
            }
            continue;
        }

        // Numbers
        if (std::isdigit(static_cast<unsigned char>(c)) || (c == '.' && i + 1 < source.size() &&
            std::isdigit(static_cast<unsigned char>(source[i + 1])))) {
            std::size_t start = i;
            while (i < source.size() && (std::isdigit(static_cast<unsigned char>(source[i])) || source[i] == '.')) {
                ++i;
            }
            tokens.emplace_back(MathTokenKind::Number, source.substr(start, i - start));
            continue;
        }

        // Single-character tokens.
        switch (c) {
            case '^': tokens.emplace_back(MathTokenKind::Superscript, "^"); break;
            case '_': tokens.emplace_back(MathTokenKind::Subscript, "_"); break;
            case '{': tokens.emplace_back(MathTokenKind::LBrace, "{"); break;
            case '}': tokens.emplace_back(MathTokenKind::RBrace, "}"); break;
            case '(': tokens.emplace_back(MathTokenKind::LParen, "("); break;
            case ')': tokens.emplace_back(MathTokenKind::RParen, ")"); break;
            case '[': tokens.emplace_back(MathTokenKind::LBracket, "["); break;
            case ']': tokens.emplace_back(MathTokenKind::RBracket, "]"); break;
            case '+': tokens.emplace_back(MathTokenKind::Plus, "+"); break;
            case '-': tokens.emplace_back(MathTokenKind::Minus, "−"); break;
            case '*': tokens.emplace_back(MathTokenKind::Asterisk, "*"); break;
            case '=': tokens.emplace_back(MathTokenKind::Equals, "="); break;
            case '<': tokens.emplace_back(MathTokenKind::Less, "<"); break;
            case '>': tokens.emplace_back(MathTokenKind::Greater, ">"); break;
            case '|': tokens.emplace_back(MathTokenKind::Pipe, "|"); break;
            case ',': tokens.emplace_back(MathTokenKind::Comma, ","); break;
            case '&': tokens.emplace_back(MathTokenKind::Ampersand, "&"); break;
            default:
                // Letters (identifiers)
                if (std::isalpha(static_cast<unsigned char>(c))) {
                    std::size_t start = i;
                    while (i < source.size() && std::isalpha(static_cast<unsigned char>(source[i]))) {
                        ++i;
                    }
                    std::string ident = source.substr(start, i - start);
                    tokens.emplace_back(MathTokenKind::Identifier, ident, ident);
                    continue;
                }
                // Treat other chars as identifiers (spaces already skipped).
                tokens.emplace_back(MathTokenKind::Identifier, std::string(1, c), std::string(1, c));
                break;
        }
        ++i;
    }

    tokens.emplace_back(MathTokenKind::EndOfInput);
    return tokens;
}

// ===================================================================
// Recursive-Descent Parser
// ===================================================================

namespace {

class Parser {
public:
    explicit Parser(std::vector<MathToken> tokens, bool displayStyle)
        : tokens_(std::move(tokens)), displayStyle_(displayStyle) {}

    MathNodePtr parse() {
        pos_ = 0;
        auto result = parseExpr();
        return result;
    }

private:
    std::vector<MathToken> tokens_;
    std::size_t pos_ = 0;
    bool displayStyle_;
    int forceLimits_ = 0; // 1 = force limits above/below, -1 = force no limits
    MathToken eof_{MathTokenKind::EndOfInput};

    const MathToken& current() const {
        if (pos_ < tokens_.size()) return tokens_[pos_];
        return eof_;
    }

    void advance() { if (pos_ < tokens_.size()) ++pos_; }

    bool match(MathTokenKind k) {
        if (current().kind == k) { advance(); return true; }
        return false;
    }

    // expr = relation (relationOp relation)*
    MathNodePtr parseExpr() {
        auto left = parseRelation();
        while (true) {
            auto tk = current().kind;
            if (tk == MathTokenKind::Equals || tk == MathTokenKind::Less || tk == MathTokenKind::Greater) {
                advance();
                auto bin = MathNode::make(MathNodeKind::BinaryOp);
                bin->text = tokens_[pos_ - 1].text;
                bin->unicode = tokens_[pos_ - 1].unicode.empty() ? bin->text : tokens_[pos_ - 1].unicode;
                bin->children.push_back(std::move(left));
                bin->children.push_back(parseRelation());
                left = std::move(bin);
            } else {
                // Check command relations (\leq, \geq, \neq, \approx...)
                if (tk == MathTokenKind::Command) {
                    const auto* info = SymbolTable::instance().lookup(current().text);
                    if (info && info->isRelation) {
                        advance();
                        auto bin = MathNode::make(MathNodeKind::BinaryOp);
                        bin->text = tokens_[pos_ - 1].text;
                        bin->unicode = tokens_[pos_ - 1].unicode;
                        bin->children.push_back(std::move(left));
                        bin->children.push_back(parseRelation());
                        left = std::move(bin);
                        continue;
                    }
                }
                break;
            }
        }
        return left;
    }

    // relation = addsub
    MathNodePtr parseRelation() {
        return parseAddSub();
    }

    // addsub = muldiv ((+|-) muldiv)*
    MathNodePtr parseAddSub() {
        auto left = parseMulDiv();
        while (current().kind == MathTokenKind::Plus || current().kind == MathTokenKind::Minus) {
            auto tk = current();
            advance();
            auto bin = MathNode::make(MathNodeKind::BinaryOp);
            bin->text = tk.text;
            bin->unicode = tk.unicode.empty() ? tk.text : tk.unicode;
            bin->children.push_back(std::move(left));
            bin->children.push_back(parseMulDiv());
            left = std::move(bin);
        }
        return left;
    }

    // muldiv = factor (binaryOp factor)*
    MathNodePtr parseMulDiv() {
        auto left = parseFactor();
        while (true) {
            auto tk = current();
            if (tk.kind == MathTokenKind::Asterisk) {
                advance();
                auto bin = MathNode::make(MathNodeKind::BinaryOp);
                bin->text = "·";
                bin->unicode = "·";
                bin->children.push_back(std::move(left));
                bin->children.push_back(parseFactor());
                left = std::move(bin);
            } else if (tk.kind == MathTokenKind::Command) {
                const auto* info = SymbolTable::instance().lookup(tk.text);
                if (info && info->isBinaryOp) {
                    advance();
                    auto bin = MathNode::make(MathNodeKind::BinaryOp);
                    bin->text = tk.text;
                    bin->unicode = tk.unicode;
                    bin->children.push_back(std::move(left));
                    bin->children.push_back(parseFactor());
                    left = std::move(bin);
                } else {
                    break;
                }
            } else {
                break;
            }
        }
        // Check for implicit multiplication: identifier next to identifier/number/group.
        // e.g., "2x", "a b", "\sin x"
        if (left && !isOperator(left->kind)) {
            auto childOpt = tryParseFactor();
            if (childOpt) {
                auto bin = MathNode::make(MathNodeKind::BinaryOp);
                bin->text = "·";
                bin->unicode = "·";
                bin->children.push_back(std::move(left));
                bin->children.push_back(std::move(childOpt));
                left = std::move(bin);
            }
        }
        return left;
    }

    static bool isOperator(MathNodeKind k) {
        return k == MathNodeKind::BinaryOp || k == MathNodeKind::UnaryOp;
    }

    // factor = atom subSup*
    MathNodePtr parseFactor() {
        auto base = parseAtom();
        if (!base) return base;

        // Attach subscripts/superscripts.
        while (current().kind == MathTokenKind::Subscript || current().kind == MathTokenKind::Superscript) {
            bool hasSub = false, hasSuper = false;
            MathNodePtr sub, super;

            if (current().kind == MathTokenKind::Subscript) {
                advance();
                hasSub = true;
                sub = parseGroupOrAtom();
            }
            if (current().kind == MathTokenKind::Superscript) {
                advance();
                hasSuper = true;
                super = parseGroupOrAtom();
            }

            if (hasSub && hasSuper) {
                auto ss = MathNode::make(MathNodeKind::SubSup);
                ss->children.push_back(std::move(base));
                ss->children.push_back(std::move(sub));
                ss->children.push_back(std::move(super));
                base = std::move(ss);
            } else if (hasSub) {
                auto s = MathNode::make(MathNodeKind::Subscript);
                s->children.push_back(std::move(base));
                s->children.push_back(std::move(sub));
                base = std::move(s);
            } else {
                auto s = MathNode::make(MathNodeKind::Superscript);
                s->children.push_back(std::move(base));
                s->children.push_back(std::move(super));
                base = std::move(s);
            }
        }
        return base;
    }

    // atom = NUMBER | IDENTIFIER | command | group | frac | sqrt | delimited | matrix
    //      | '(' expr ')' | '[' expr ']'
    MathNodePtr parseAtom() {
        auto tk = current();

        switch (tk.kind) {
            case MathTokenKind::Number:
                advance();
                return MathNode::atom(MathNodeKind::Number, tk.text, tk.text);

            case MathTokenKind::Identifier: {
                advance();
                // Check if it's a function name (\sin, \cos, \lim...)
                if (!tk.text.empty() && tk.text[0] == '\\') {
                    std::string cmd = tk.text.substr(1);
                    if (SymbolTable::instance().isFunctionName(cmd)) {
                        auto fn = MathNode::atom(MathNodeKind::Identifier, tk.text, cmd);
                        fn->displayStyle = displayStyle_;
                        return fn;
                    }
                }
                return MathNode::atom(MathNodeKind::Identifier, tk.text, tk.unicode.empty() ? tk.text : tk.unicode);
            }

            case MathTokenKind::Command: {
                const std::string& cmd = tk.text;

                if (cmd == "frac") {
                    advance();
                    return parseFrac();
                }
                if (cmd == "sqrt") {
                    advance();
                    return parseSqrt();
                }
                if (cmd == "binom") {
                    advance();
                    return parseBinom();
                }
                if (cmd == "overline" || cmd == "overrightarrow" || cmd == "overleftarrow") {
                    advance();
                    return parseAccentOver(cmd);
                }
                if (cmd == "underline" || cmd == "underbrace") {
                    advance();
                    return parseAccentUnder(cmd);
                }
                if (cmd == "overbrace") {
                    advance();
                    return parseOverUnder(cmd);
                }
                if (cmd == "xrightarrow" || cmd == "xleftarrow") {
                    advance();
                    return parseXArrow(cmd);
                }
                if (cmd == "substack") {
                    advance();
                    return parseSubStack();
                }
                if (cmd == "text" || cmd == "color") {
                    advance();
                    return parseTextBox(cmd);
                }
                if (cmd == "left") {
                    advance();
                    return parseLeftRight();
                }
                if (cmd == "begin") {
                    advance();
                    return parseMatrix();
                }

                // Other commands: Greek, symbols, large ops, function names.
                if (cmd == "limits") {
                    advance();
                    forceLimits_ = 1;
                    // Parse the next atom with limits forced.
                    auto next = parseAtom();
                    forceLimits_ = 0;
                    return next;
                }
                if (cmd == "nolimits") {
                    advance();
                    forceLimits_ = -1;
                    auto next = parseAtom();
                    forceLimits_ = 0;
                    return next;
                }
                if (cmd == "displaystyle") {
                    advance();
                    // Ignore: we handle display style via the displayStyle parameter.
                    return parseAtom();
                }

                advance();
                const auto* info = SymbolTable::instance().lookup(cmd);
                if (info) {
                    if (info->isLargeOp) {
                        auto op = MathNode::make(MathNodeKind::LargeOp);
                        op->text = cmd;
                        op->unicode = info->unicode;
                        // Apply forced limits if set.
                        if (forceLimits_ == 1) op->displayStyle = true;
                        else if (forceLimits_ == -1) op->displayStyle = false;
                        else op->displayStyle = displayStyle_;
                        // Parse optional limits.
                        parseLimits(*op);
                        return op;
                    }
                    return MathNode::atom(info->nodeKind, cmd, info->unicode);
                }
                // Unknown command — render as text.
                return MathNode::atom(MathNodeKind::Identifier, "\\" + cmd, "\\" + cmd);
            }

            case MathTokenKind::LBrace: {
                advance();
                auto group = MathNode::make(MathNodeKind::Group);
                group->children.push_back(parseExpr());
                match(MathTokenKind::RBrace); // Skip closing brace
                return group;
            }

            case MathTokenKind::LParen: {
                advance();
                auto left = parseExpr();
                match(MathTokenKind::RParen);
                auto del = MathNode::make(MathNodeKind::Delimited);
                del->text = "(";
                del->unicode = "(";
                del->children.push_back(std::move(left));
                return del;
            }

            case MathTokenKind::LBracket: {
                advance();
                auto left = parseExpr();
                match(MathTokenKind::RBracket);
                auto del = MathNode::make(MathNodeKind::Delimited);
                del->text = "[";
                del->unicode = "[";
                del->children.push_back(std::move(left));
                return del;
            }

            case MathTokenKind::Minus: {
                // Unary minus
                advance();
                auto un = MathNode::make(MathNodeKind::UnaryOp);
                un->text = "−";
                un->unicode = "−";
                un->children.push_back(parseAtom());
                return un;
            }

            default:
                // Unexpected token — return null (caller handles).
                return nullptr;
        }
    }

    // Tries to parse a factor, returns null if it wouldn't make sense.
    MathNodePtr tryParseFactor() {
        auto tk = current().kind;
        if (tk == MathTokenKind::Number || tk == MathTokenKind::Identifier ||
            tk == MathTokenKind::Command || tk == MathTokenKind::LBrace ||
            tk == MathTokenKind::LParen || tk == MathTokenKind::LBracket) {
            return parseFactor();
        }
        return nullptr;
    }

    // group_or_atom = '{' expr '}' | atom
    MathNodePtr parseGroupOrAtom() {
        if (current().kind == MathTokenKind::LBrace) {
            return parseAtom(); // Will parse as group.
        }
        return parseAtom();
    }

    // \frac{num}{den}
    MathNodePtr parseFrac() {
        auto frac = MathNode::make(MathNodeKind::Fraction);

        // Parse numerator (must be in braces).
        if (current().kind != MathTokenKind::LBrace) {
            // Graceful degradation: treat as atom.
            frac->children.push_back(parseAtom());
        } else {
            advance();
            frac->children.push_back(parseExpr());
            match(MathTokenKind::RBrace);
        }

        // Parse denominator (must be in braces).
        if (current().kind != MathTokenKind::LBrace) {
            frac->children.push_back(parseAtom());
        } else {
            advance();
            frac->children.push_back(parseExpr());
            match(MathTokenKind::RBrace);
        }

        return frac;
    }

    // \sqrt{radicand}  or  \sqrt[index]{radicand}
    MathNodePtr parseSqrt() {
        auto rad = MathNode::make(MathNodeKind::Radical);

        // Optional index in brackets.
        if (current().kind == MathTokenKind::LBracket) {
            advance();
            rad->children.push_back(parseExpr()); // index
            match(MathTokenKind::RBracket);
        }

        // Radicand in braces.
        if (current().kind == MathTokenKind::LBrace) {
            advance();
            rad->children.push_back(parseExpr()); // radicand
            match(MathTokenKind::RBrace);
        } else {
            rad->children.push_back(parseAtom()); // bare radicand
        }

        return rad;
    }

    // \left delim expr \right delim
    MathNodePtr parseLeftRight() {
        auto del = MathNode::make(MathNodeKind::Delimited);

        // Read left delimiter.
        std::string leftDelim;
        if (current().kind == MathTokenKind::Command) {
            leftDelim = "\\" + current().text;
            advance();
        } else {
            leftDelim = current().text;
            advance();
        }
        del->text = leftDelim;
        del->unicode = leftDelim;

        // Read content until \right.
        while (current().kind != MathTokenKind::Command || current().text != "right") {
            if (current().kind == MathTokenKind::EndOfInput) break;
            del->children.push_back(parseExpr());
            // Skip commas at top level (they separate expressions in delimited context).
            if (current().kind == MathTokenKind::Comma) advance();
        }

        // Skip \right and the right delimiter.
        if (current().kind == MathTokenKind::Command && current().text == "right") {
            advance(); // skip \right
            if (current().kind != MathTokenKind::EndOfInput) {
                advance(); // skip right delimiter
            }
        }

        return del;
    }

    // Parse limits for large operators: _{lower} ^{upper} or ^{upper} _{lower}.
    void parseLimits(MathNode& op) {
        // In display style, limits go above/below.
        // In text style, they go as sub/superscripts (but we still parse them here).

        // Try subscript first.
        if (current().kind == MathTokenKind::Subscript) {
            advance();
            op.children.push_back(parseGroupOrAtom()); // lower limit
        }

        // Try superscript.
        if (current().kind == MathTokenKind::Superscript) {
            advance();
            op.children.push_back(parseGroupOrAtom()); // upper limit
        }

        // If we got superscript first, subscript might come after.
        if (current().kind == MathTokenKind::Subscript) {
            // Already parsed an upper limit (superscript), this is lower.
            // Insert at position 0 if needed.
            advance();
            auto lower = parseGroupOrAtom();
            if (op.children.size() == 1) {
                op.children.insert(op.children.begin(), std::move(lower));
            } else {
                op.children.push_back(std::move(lower));
            }
        }
    }

    // \binom{n}{k}
    MathNodePtr parseBinom() {
        auto binom = MathNode::make(MathNodeKind::Binomial);
        if (current().kind == MathTokenKind::LBrace) {
            advance();
            binom->children.push_back(parseExpr());
            match(MathTokenKind::RBrace);
        } else {
            binom->children.push_back(parseAtom());
        }
        if (current().kind == MathTokenKind::LBrace) {
            advance();
            binom->children.push_back(parseExpr());
            match(MathTokenKind::RBrace);
        } else {
            binom->children.push_back(parseAtom());
        }
        return binom;
    }

    // \overline{...}, \overrightarrow{...}, \overleftarrow{...}
    MathNodePtr parseAccentOver(const std::string& cmd) {
        auto node = MathNode::make(MathNodeKind::AccentOver);
        node->text = cmd;
        // Map to Unicode glyph.
        if (cmd == "overrightarrow") node->unicode = "⟶";
        else if (cmd == "overleftarrow") node->unicode = "⟵";
        // \overline renders as a rule (handled by layout engine).
        if (current().kind == MathTokenKind::LBrace) {
            advance();
            node->children.push_back(parseExpr());
            match(MathTokenKind::RBrace);
        } else {
            node->children.push_back(parseAtom());
        }
        return node;
    }

    // \underline{...}, \underbrace{...}
    MathNodePtr parseAccentUnder(const std::string& cmd) {
        auto node = MathNode::make(MathNodeKind::AccentUnder);
        node->text = cmd;
        if (cmd == "underbrace") node->unicode = "⏟";
        if (current().kind == MathTokenKind::LBrace) {
            advance();
            node->children.push_back(parseExpr());
            match(MathTokenKind::RBrace);
        } else {
            node->children.push_back(parseAtom());
        }
        // Optional annotation: \underbrace{x+y}_{n}
        if (current().kind == MathTokenKind::Subscript) {
            advance();
            node->children.push_back(parseGroupOrAtom());
        }
        return node;
    }

    // \overbrace{...}^{annotation}
    MathNodePtr parseOverUnder(const std::string& cmd) {
        auto node = MathNode::make(MathNodeKind::OverUnder);
        node->text = cmd;
        node->unicode = "⏞";
        if (current().kind == MathTokenKind::LBrace) {
            advance();
            node->children.push_back(parseExpr());
            match(MathTokenKind::RBrace);
        } else {
            node->children.push_back(parseAtom());
        }
        // Optional annotation: \overbrace{x+y}^{n}
        if (current().kind == MathTokenKind::Superscript) {
            advance();
            node->children.push_back(parseGroupOrAtom());
        }
        return node;
    }

    // \xrightarrow{text}, \xleftarrow{text}
    MathNodePtr parseXArrow(const std::string& cmd) {
        auto node = MathNode::make(MathNodeKind::AccentOver);
        node->text = cmd;
        node->unicode = (cmd == "xrightarrow") ? "⟶" : "⟵";
        // Content is empty, arrow spans the available space.
        // The "text" argument above the arrow.
        node->children.push_back(MathNode::atom(MathNodeKind::Identifier, "", ""));
        if (current().kind == MathTokenKind::LBrace) {
            advance();
            // Replace the empty content with actual text.
            node->children[0] = parseExpr();
            match(MathTokenKind::RBrace);
        }
        return node;
    }

    // \substack{a \\ b \\ c}
    MathNodePtr parseSubStack() {
        auto ss = MathNode::make(MathNodeKind::SubStack);
        if (current().kind == MathTokenKind::LBrace) {
            advance();
            // Parse lines until closing brace.
            while (current().kind != MathTokenKind::RBrace && current().kind != MathTokenKind::EndOfInput) {
                ss->children.push_back(parseExpr());
                // Skip separator (treated as implicit row break).
                // The tokenizer doesn't handle \\, so we rely on the closing brace.
                if (current().kind == MathTokenKind::Comma) advance();
            }
            match(MathTokenKind::RBrace);
        } else {
            ss->children.push_back(parseAtom());
        }
        return ss;
    }

    // \text{...} or \color{name}{...}
    MathNodePtr parseTextBox(const std::string& cmd) {
        auto tb = MathNode::make(MathNodeKind::TextBox);
        tb->text = cmd;
        if (cmd == "color") {
            // Parse color name.
            if (current().kind == MathTokenKind::LBrace) {
                advance();
                tb->unicode = current().text;
                advance();
                match(MathTokenKind::RBrace);
            }
        }
        // Parse content.
        if (current().kind == MathTokenKind::LBrace) {
            advance();
            auto content = MathNode::make(MathNodeKind::Group);
            // For \text, parse the content as literal text (not math).
            while (current().kind != MathTokenKind::RBrace && current().kind != MathTokenKind::EndOfInput) {
                if (current().kind == MathTokenKind::Identifier || current().kind == MathTokenKind::Number) {
                    content->children.push_back(MathNode::atom(
                        MathNodeKind::Identifier, current().text, current().text));
                    advance();
                } else if (current().kind == MathTokenKind::Command) {
                    content->children.push_back(MathNode::atom(
                        MathNodeKind::Identifier, "\\" + current().text, current().text));
                    advance();
                } else {
                    content->children.push_back(MathNode::atom(
                        MathNodeKind::Identifier, current().text, current().text));
                    advance();
                }
            }
            match(MathTokenKind::RBrace);
            tb->children.push_back(std::move(content));
        } else {
            tb->children.push_back(parseAtom());
        }
        return tb;
    }

    // \begin{pmatrix} ... \end{pmatrix} (extended for cases too)
    MathNodePtr parseMatrix() {
        // Read environment name.
        std::string env;
        if (current().kind == MathTokenKind::Identifier) {
            env = current().text;
            advance();
        } else if (current().kind == MathTokenKind::LBrace) {
            advance();
            env = current().text;
            advance();
            match(MathTokenKind::RBrace);
        }

        // \begin{cases} -> CasesBlock
        if (env == "cases") {
            auto cs = MathNode::make(MathNodeKind::CasesBlock);
            cs->text = env;
            if (current().kind == MathTokenKind::LBrace) advance();

            while (true) {
                if (current().kind == MathTokenKind::EndOfInput) break;
                if (current().kind == MathTokenKind::Command && current().text == "end") break;
                cs->children.push_back(parseExpr());
                if (current().kind == MathTokenKind::Ampersand) advance();
            }

            // Skip \end{cases}
            if (current().kind == MathTokenKind::Command && current().text == "end") {
                advance();
                if (current().kind == MathTokenKind::LBrace) {
                    advance(); advance();
                    match(MathTokenKind::RBrace);
                } else if (current().kind == MathTokenKind::Identifier) {
                    advance();
                }
            }
            return cs;
        }

        auto mat = MathNode::make(MathNodeKind::Matrix);
        mat->text = env; // env already read at the top of parseMatrix
        if (!env.empty() && current().kind == MathTokenKind::LBrace) {
            advance(); // skip opening brace
        }

        // Parse cells until \end.
        int cellCount = 0;
        while (true) {
            if (current().kind == MathTokenKind::EndOfInput) break;
            // Check for \end.
            if (current().kind == MathTokenKind::Command && current().text == "end") break;

            mat->children.push_back(parseExpr());
            ++cellCount;

            if (current().kind == MathTokenKind::Ampersand) {
                advance();
            } else if (current().kind == MathTokenKind::Pipe) {
                advance();
            }
            // Otherwise, next iteration (handles implicit row separators).
        }

        // Skip \end{env}.
        if (current().kind == MathTokenKind::Command && current().text == "end") {
            advance();
            if (current().kind == MathTokenKind::LBrace) {
                advance();
                advance(); // skip env name
                match(MathTokenKind::RBrace);
            } else if (current().kind == MathTokenKind::Identifier) {
                advance();
            }
        }

        return mat;
    }
};

} // namespace

MathNodePtr parseMath(const std::string& source, bool displayStyle) {
    auto tokens = tokenizeMath(source);
    Parser parser(std::move(tokens), displayStyle);
    return parser.parse();
}

} // namespace math
} // namespace mdcore
