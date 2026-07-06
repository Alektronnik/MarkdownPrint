#pragma once

#include <string>

namespace mdcore {

// Fuente de métricas tipográficas para el motor de layout. El
// algoritmo de layout no sabe ni le importa de dónde vienen estos
// números: hoy usamos una aproximación portable (ApproximateFontMetrics)
// para poder testear en Linux; en macOS/iOS, la Capa 3 la sustituirá
// por una implementación respaldada por CoreText con las métricas
// reales de San Francisco, sin tocar ni una línea del algoritmo.
class FontMetrics {
public:
    virtual ~FontMetrics() = default;

    // Ancho, en puntos, de `text` renderizado a `pointSize`.
    virtual double widthOfText(const std::string& text, double pointSize) const = 0;

    // Alto de línea recomendado (interlineado incluido) a `pointSize`.
    virtual double lineHeight(double pointSize) const = 0;
};

} // namespace mdcore
