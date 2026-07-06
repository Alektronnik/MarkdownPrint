#pragma once

namespace mdcore {

// Tipo de bloque ya agrupado por el AST Builder. A diferencia de
// TokenKind (línea a línea), aquí una lista completa ya es un solo
// bloque con varios ítems, y un párrafo multilínea ya es un único
// bloque con las líneas fusionadas.
enum class BlockKind {
    Heading,
    Paragraph,
    UnorderedList,
    OrderedList,
    HorizontalRule,
    CodeBlock,
    Table,
    Blockquote,
    RawHtmlBlock,
    MathBlock,
    FootnoteDef,  // [^label]: definicion
    Unknown
};

} // namespace mdcore
