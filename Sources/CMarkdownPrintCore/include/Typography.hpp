#pragma once

namespace mdcore {

// Escala tipografica basada en Primer CSS (GitHub):
//   - Cuerpo: 12 pt (~16 px a 96 dpi)
//   - Proporciones de encabezado: 2em, 1.5em, 1.25em, 1em, 0.875em, 0.85em
//   - Codigo: 85% del cuerpo = 10.2 pt
//   - Interlineado: 1.5 (GitHub standard)
struct Typography {
    double paragraphFontSize = 12.0;
    double listItemFontSize = 12.0;
    double codeFontSize = 10.2;       // 85% de 12pt (GitHub)

    // GitHub usa margin-bottom: 16px (~12pt) para todos los bloques.
    double spacingAfterHeading = 16.0;
    double spacingAfterParagraph = 16.0;
    double spacingAfterListItem = 4.0;
    double spacingAfterList = 16.0;
    double spacingAfterHorizontalRule = 24.0;  // GitHub: margin 24px 0
    double spacingAfterCodeBlock = 16.0;
    double spacingAfterTable = 16.0;

    // Padding interior de las celdas de tabla. GitHub: 6px 13px.
    double tableCellPaddingH = 10.0;
    double tableCellPaddingV = 5.0;

    // Sangria del marcador ("\u2022" o "1.") respecto al margen izquierdo.
    double listIndent = 24.0;  // GitHub: padding-left 2em (~24pt)

    // True = justificar texto (margen derecho recto).
    // False = alineacion izquierda (default, estilo GitHub).
    bool textJustified = false;

    // Tamano de fuente de un encabezado segun su nivel (1-6).
    // Escala GitHub/Primer CSS: 2em, 1.5em, 1.25em, 1em, 0.875em, 0.85em.
    double headingFontSize(int level) const;
};

} // namespace mdcore
