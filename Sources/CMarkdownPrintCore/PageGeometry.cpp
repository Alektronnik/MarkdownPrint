#include "PageGeometry.hpp"

namespace mdcore {

PageGeometry PageGeometry::standardMargins(double pageWidth, double pageHeight) {
    // Margenes de documento estandar: 1 pulgada (72 pt) en cada lado.
    // El margen inferior es ligeramente mayor que el superior (1.25")
    // por convencion tipografica clasica.
    constexpr double marginH = 72.0;  // izquierda y derecha: 1"
    constexpr double marginTop = 72.0;    // superior: 1"
    constexpr double marginBottom = 90.0; // inferior: 1.25"

    PageGeometry geometry;
    geometry.pageWidth = pageWidth;
    geometry.pageHeight = pageHeight;
    geometry.marginLeft = marginH;
    geometry.marginRight = marginH;
    geometry.marginTop = marginTop;
    geometry.marginBottom = marginBottom;
    return geometry;
}

} // namespace mdcore
