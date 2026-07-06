#include "ApproximateFontMetrics.hpp"

#include <cctype>

namespace mdcore {

double ApproximateFontMetrics::widthOfChar(char c, double pointSize) const {
    switch (c) {
        // Caracteres estrechos.
        case 'i': case 'l': case 'j': case 'I': case '.': case ',':
        case '\'': case '!': case '|': case ':': case ';':
            return 0.34 * pointSize;
        // Espacio.
        case ' ':
            return 0.30 * pointSize;
        // Caracteres anchos.
        case 'm': case 'w': case 'M': case 'W': case '@':
            return 0.95 * pointSize;
        default:
            break;
    }
    if (std::isdigit(static_cast<unsigned char>(c))) {
        return 0.62 * pointSize;
    }
    if (std::isupper(static_cast<unsigned char>(c))) {
        return 0.75 * pointSize;
    }
    return 0.58 * pointSize;
}

double ApproximateFontMetrics::widthOfText(const std::string& text, double pointSize) const {
    double total = 0.0;
    for (char c : text) {
        total += widthOfChar(c, pointSize);
    }
    return total;
}

double ApproximateFontMetrics::lineHeight(double pointSize) const {
    // GitHub usa line-height: 1.5 para el cuerpo del texto.
    return pointSize * 1.5;
}

} // namespace mdcore
