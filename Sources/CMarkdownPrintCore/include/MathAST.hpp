#pragma once

#include <memory>
#include <string>
#include <vector>

namespace mdcore {
namespace math {

// === Math expression AST nodes ===
//
// Represents a parsed LaTeX math expression as a tree.
// The layout engine walks this tree to produce positioned boxes.

enum class MathNodeKind {
    // Atoms
    Number,        // 42, 3.14
    Identifier,    // x, y, foo, \sin, \cos
    GreekLetter,   // \alpha, \beta, \Gamma...
    MathSymbol,    // \infty, \pm, \times, \leq, \rightarrow...

    // Compounds
    Group,         // { ... }
    Superscript,   // base ^ exponent
    Subscript,     // base _ subscript
    SubSup,        // base _ sub ^ super
    Fraction,      // \frac{num}{den}
    Radical,       // \sqrt{radicand} or \sqrt[index]{radicand}
    LargeOp,       // \sum, \int, \prod with optional limits
    Delimited,     // \left( ... \right)
    Matrix,        // \begin{pmatrix}...\end{pmatrix}

    // New compounds (Phase 2)
    AccentOver,    // \overline, \overrightarrow, \xrightarrow{text}
    AccentUnder,   // \underline, \underbrace
    OverUnder,     // \overbrace (decoration above, annotation above that)
    Binomial,      // \binom{n}{k}
    CasesBlock,    // \begin{cases}
    SubStack,      // \substack{...} for multiline limits
    TextBox,       // \text{...}, \color{...}{...}

    // Operators
    BinaryOp,      // +, -, \times, \div, \cdot, =, <, >, \leq...
    UnaryOp,       // - (negation)
};

// Forward declarations.
struct MathNode;
using MathNodePtr = std::unique_ptr<MathNode>;

struct MathNode {
    MathNodeKind kind;
    std::string text;       // For atoms: the literal text or LaTeX command
    std::string unicode;    // For atoms: the mapped Unicode glyph

    // Children. Meaning depends on kind:
    //   Group:       children[0] = content
    //   Superscript: children[0] = base, children[1] = exponent
    //   Subscript:   children[0] = base, children[1] = subscript
    //   SubSup:      children[0] = base, children[1] = sub, children[2] = super
    //   Fraction:    children[0] = numerator, children[1] = denominator
    //   Radical:     children[0] = radicand, children[1] = index (optional)
    //   LargeOp:     children[0..n] = limits (in display mode: lower, upper)
    //   Delimited:   children[0..n] = content
    //   Matrix:      children[0..n] = cells (row-major)
    //   BinaryOp:    children[0] = left, children[1] = right
    //   UnaryOp:     children[0] = operand
    //   AccentOver:  children[0] = content; text=decoration type; unicode=glyph
    //   AccentUnder: children[0] = content; text=decoration type; unicode=glyph
    //                children[1] = annotation (optional, for \underbrace)
    //   OverUnder:   children[0] = content; children[1] = annotation above
    //                text=decoration type (overbrace)
    //   Binomial:    children[0] = top, children[1] = bottom
    //   CasesBlock:  children[0..n] = cases (alternating: value, condition...)
    //   SubStack:    children[0..n] = stacked lines
    //   TextBox:     children[0] = content; text=command (\text or \color)
    //                unicode=color name (for \color)
    std::vector<MathNodePtr> children;

    // True for display-style rendering (bigger fractions, integrals with
    // limits above/below instead of as sub/superscripts).
    bool displayStyle = false;

    MathNode(MathNodeKind k) : kind(k) {}

    // Factory helpers.
    static MathNodePtr make(MathNodeKind k) {
        return std::make_unique<MathNode>(k);
    }
    static MathNodePtr atom(MathNodeKind k, const std::string& txt, const std::string& uni = "") {
        auto n = std::make_unique<MathNode>(k);
        n->text = txt;
        n->unicode = uni;
        return n;
    }
};

} // namespace math
} // namespace mdcore
