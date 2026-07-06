#pragma once

namespace mdcore {

// Tipos de fragmento dentro de un bloque de texto (encabezado,
// párrafo o ítem de lista). El código de un CodeBlock NO pasa por
// aquí: es contenido literal, no se le parsea énfasis.
enum class InlineKind {
    PlainText,
    Bold,   // **texto**
    Italic, // *texto*
    Code,         // `texto`
    Strikethrough, // ~~texto~~
    Link,          // [texto](url)
    Image,         // ![alt](url)
    HardBreak,     // <br> HTML
    InlineMath,    // $...$ ecuacion inline
    FootnoteRef,   // [^label] referencia a nota
    CrossRef       // [@sec:label] referencia cruzada
};

} // namespace mdcore
