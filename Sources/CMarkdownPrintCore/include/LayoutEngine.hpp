#pragma once

#include <vector>
#include "Block.hpp"
#include "FontMetrics.hpp"
#include "LayoutTypes.hpp"
#include "PageGeometry.hpp"
#include "Typography.hpp"

namespace mdcore {

class Hyphenator;

class LayoutEngine {
public:
    LayoutEngine(PageGeometry geometry, const FontMetrics& metrics, Typography typography = Typography(),
                 const Hyphenator* hyphenator = nullptr);

    Layout layout(const std::vector<Block>& blocks) const;

private:
    PageGeometry geometry_;
    const FontMetrics& metrics_;
    Typography typography_;
    const Hyphenator* hyphenator_;
};

} // namespace mdcore
