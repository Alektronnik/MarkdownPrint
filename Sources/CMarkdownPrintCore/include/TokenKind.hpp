#pragma once

namespace mdcore {

// Tipos de bloque que el Lexer reconoce. Trabaja línea a línea: cada
// línea de entrada produce, como mucho, un token (con la excepción de
// los bloques de código, que abarcan varias líneas).
enum class TokenKind {
    Heading,           // # .. ######      -> level = 1..6
    UnorderedListItem, // - item
    OrderedListItem,   // 1. item          -> level = numero del item
    HorizontalRule,    // ---
    CodeBlock,         // ```lang ... ```  -> language = "lang"
    BlankLine,         // linea vacia: separador entre bloques
    TableRow,          // | celda | celda |
    Blockquote,        // > texto citado
    RawHtmlBlock,      // <div>, <pre>, <table>, etc.
    MathBlock,         // $$ ... $$ bloque de ecuacion
    FootnoteDef,       // [^label]: definicion de nota
    Paragraph,         // cualquier otra linea de texto
    Unknown
};

} // namespace mdcore
