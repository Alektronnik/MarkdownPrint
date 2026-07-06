#pragma once

#include <string>
#include <vector>
#include "BlockKind.hpp"
#include "InlineRun.hpp"
#include "ListItem.hpp"

namespace mdcore {

// Un bloque del documento. Según `kind`, solo algunos campos están
// en uso (es el mismo patrón "struct plano + enum" que Token, para
// que el interop con Swift sea directo):
//
//   Heading / Paragraph  -> level (solo Heading), inlines
//   UnorderedList        -> items (number = 0 en cada ítem)
//   OrderedList          -> items (number = posición en la lista)
//   HorizontalRule        -> ningún campo adicional
//   CodeBlock             -> language, text (contenido literal, sin
//                            parsear énfasis)
//   Table                -> tableHeaders, tableCells, tableColumnCount
//   RawHtmlBlock         -> htmlTag, htmlContent
struct Block {
    BlockKind kind = BlockKind::Unknown;
    int level = 0;
    std::string language;
    std::string text;
    std::vector<InlineRun> inlines;
    std::vector<ListItem> items;
    std::vector<std::string> tableHeaders;
    std::vector<std::string> tableCells;
    int tableColumnCount = 0;
    std::vector<int> tableAlign; // 0=left, 1=center, 2=right por columna

    // RawHtmlBlock
    std::string htmlTag;      // nombre de la etiqueta: "div", "pre", "table", etc.
    std::string htmlContent;  // contenido HTML literal del bloque

    // FootnoteDef
    std::string footnoteLabel; // [^label]: la etiqueta de la nota
};

} // namespace mdcore
