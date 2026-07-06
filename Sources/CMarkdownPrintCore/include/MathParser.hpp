#pragma once

#include "MathAST.hpp"
#include <string>
#include <unordered_map>
#include <functional>

namespace mdcore {
namespace math {

// === Math Tokenizer ===
//
// Splits a LaTeX math string into tokens for the parser.

enum class MathTokenKind {
    Number,
    Identifier,
    Command,       // \alpha, \frac, \sqrt, \sum, ...
    Superscript,   // ^
    Subscript,     // _
    LBrace,        // {
    RBrace,        // }
    LParen,        // (
    RParen,        // )
    LBracket,      // [
    RBracket,      // ]
    Plus,          // +
    Minus,         // -
    Asterisk,      // *
    Equals,        // =
    Less,          // <
    Greater,       // >
    Pipe,          // |
    Comma,         // ,
    Ampersand,     // &
    EndOfInput,
};

struct MathToken {
    MathTokenKind kind;
    std::string text;
    std::string unicode; // pre-mapped glyph for known commands

    MathToken(MathTokenKind k, std::string t = "", std::string u = "")
        : kind(k), text(std::move(t)), unicode(std::move(u)) {}
};

// === Symbol Table ===
//
// Maps LaTeX commands to Unicode math glyphs and categorizes them.

struct SymbolInfo {
    std::string unicode;
    MathNodeKind nodeKind;
    bool isLargeOp = false;   // \sum, \int, \prod...
    bool isBinaryOp = false;  // \times, \div, \pm...
    bool isRelation = false;  // =, <, >, \leq, \geq...
};

class SymbolTable {
public:
    static const SymbolTable& instance();

    const SymbolInfo* lookup(const std::string& command) const;
    bool isLeftDelim(const std::string& cmd) const;
    bool isRightDelim(const std::string& cmd) const;
    std::string matchingRightDelim(const std::string& leftCmd) const;

    // Function names that get rendered in roman (not italic).
    bool isFunctionName(const std::string& name) const;

private:
    SymbolTable();
    std::unordered_map<std::string, SymbolInfo> symbols_;
    std::unordered_map<std::string, std::string> delimPairs_; // left -> right
};

// === Tokenizer ===
std::vector<MathToken> tokenizeMath(const std::string& source);

// === Parser ===
//
// Recursive-descent parser. Grammar (simplified):
//   expr     = relation (relationOp relation)*
//   relation = addsub
//   addsub   = muldiv ((+|-) muldiv)*
//   muldiv   = factor ((*|\times|\div|\cdot) factor)*
//   factor   = atom (subSup)*
//   atom     = NUMBER | IDENTIFIER | command | group | frac | sqrt | delimited | matrix
//   subSup   = '_' group_or_atom '^' group_or_atom | '_' group_or_atom | '^' group_or_atom

MathNodePtr parseMath(const std::string& source, bool displayStyle = false);

} // namespace math
} // namespace mdcore
