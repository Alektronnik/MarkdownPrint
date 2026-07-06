#pragma once

#include <string>
#include <vector>
#include "InlineKind.hpp"
#include "PageGeometry.hpp"

namespace mdcore {

// Que representa un elemento ya posicionado en la pagina.
enum class LayoutElementKind {
    Word,           // un fragmento de texto (una "palabra" o unidad no divisible)
    HorizontalRule,  // una linea horizontal completa
    TableGridLine,  // una linea de cuadricula de tabla (horizontal o vertical)
    Image,          // una caja reservada para ![alt](url)
    RawHtml,        // un bloque de HTML literal (<div>, <pre>, etc.)
    MathBlock,      // un bloque de ecuacion LaTeX ($$...$$)
    FootnoteRef,    // [^label] referencia de nota al pie/endnote
};

// Un elemento con su posición final en la página. Las coordenadas
// (x, y) se miden desde la esquina superior izquierda del área de
// CONTENIDO de la página (es decir, ya dentro de los márgenes), con
// y creciendo hacia abajo. Convertir esto al sistema de coordenadas
// de CoreGraphics (origen abajo-izquierda) es trabajo de la Capa 3,
// que para ello necesita también `Layout::geometry` (más abajo).
struct LayoutElement {
    LayoutElementKind kind = LayoutElementKind::Word;
    double x = 0;
    double y = 0;
    double width = 0;
    double height = 0;

    // Solo relevante cuando kind == Word:
    double fontSize = 0;
    InlineKind style = InlineKind::PlainText;
    std::string text;
    std::string url;   // solo cuando style == Link
    // 0 = no es encabezado. 1-6 = nivel de encabezado (H1-H6).
    int headingLevel = 0;
    // Distingue codigo inline de lineas pertenecientes a un bloque
    // fenced. Ambos usan InlineKind::Code, pero se pintan distinto.
    bool isCodeBlock = false;
    // Permite al renderer tratar las celdas como unidades tabulares
    // en vez de mezclarlas con texto de parrafos/listas.
    bool isTableCell = false;
    // Permite al renderer aplicar color muted a citas.
    bool isBlockquote = false;
    // Text direction: false=LTR, true=RTL (para arabe, hebreo, etc.)
    bool isRTL = false;
    // Footnote label for FootnoteRef elements.
    std::string footnoteLabel;
    // Heading label for cross-references ({#sec:label}).
    std::string headingLabel;
    // Cross-reference label for [@sec:label] references.
    std::string crossRefLabel;
};

struct Page {
    int pageNumber = 1; // empieza en 1
    std::vector<LayoutElement> elements;
};

struct FootnoteDef {
    std::string label;
    std::string text;
};

struct Layout {
    std::vector<Page> pages;
    PageGeometry geometry;
    std::vector<FootnoteDef> footnoteDefs;
};

} // namespace mdcore
