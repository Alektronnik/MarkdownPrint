#pragma once

namespace mdcore {

// Geometría de una página: dimensiones totales y márgenes.
struct PageGeometry {
    double pageWidth = 0;
    double pageHeight = 0;
    double marginTop = 0;
    double marginBottom = 0;
    double marginLeft = 0;
    double marginRight = 0;

    double contentWidth() const { return pageWidth - marginLeft - marginRight; }
    double contentHeight() const { return pageHeight - marginTop - marginBottom; }

    // Margenes de documento estandar:
    //  - 1 pulgada (72 pt) en izquierda, derecha y superior.
    //  - 1.25 pulgadas (90 pt) en el margen inferior.
    static PageGeometry standardMargins(double pageWidth, double pageHeight);
};

} // namespace mdcore
