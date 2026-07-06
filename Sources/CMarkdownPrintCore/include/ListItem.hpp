#pragma once

#include <vector>
#include "InlineRun.hpp"

namespace mdcore {

struct ListItem {
    int number = 0; // 0 en listas sin numerar (UnorderedList)
    bool checked = false; // true si es [x], false si es [ ] o no aplica
    bool isTask = false; // true si es un item de task list
    int indent = 0;  // sangria en espacios
    std::vector<ListItem> items; // sub-items anidados
    std::vector<InlineRun> inlines;
};

} // namespace mdcore
