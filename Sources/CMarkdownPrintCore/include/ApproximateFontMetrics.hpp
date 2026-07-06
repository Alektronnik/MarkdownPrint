#pragma once

#include "FontMetrics.hpp"

namespace mdcore {

// Aproximación razonable de un tipo de letra proporcional (clasifica
// caracteres en estrechos / normales / anchos). No pretende ser
// exacta: existe para poder desarrollar y testear el algoritmo de
// layout en cualquier plataforma. La Capa 3 la sustituye por
// CoreText en macOS/iOS.
class ApproximateFontMetrics : public FontMetrics {
public:
    double widthOfText(const std::string& text, double pointSize) const override;
    double lineHeight(double pointSize) const override;

private:
    double widthOfChar(char c, double pointSize) const;
};

} // namespace mdcore
