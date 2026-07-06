#include "Typography.hpp"

#include <algorithm>
#include <array>

namespace mdcore {

double Typography::headingFontSize(int level) const {
    // Escala GitHub/Primer CSS (basada en cuerpo 12pt):
    // H1=2em(24pt), H2=1.5em(18pt), H3=1.25em(15pt), H4=1em(12pt), H5=0.875em(10.5pt), H6=0.85em(10.2pt)
    static constexpr std::array<double, 6> scale = {24.0, 18.0, 15.0, 12.0, 10.5, 10.2};
    int clamped = std::clamp(level, 1, static_cast<int>(scale.size()));
    return scale[static_cast<std::size_t>(clamped - 1)];
}

} // namespace mdcore
