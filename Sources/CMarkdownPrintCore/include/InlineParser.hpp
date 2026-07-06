#pragma once

#include <map>
#include <string>
#include <vector>
#include "InlineRun.hpp"

namespace mdcore {

std::vector<InlineRun> parseInlines(const std::string& text);

/// Resuelve enlaces por referencia usando el mapa [ref] -> url.
std::vector<InlineRun> parseInlines(const std::string& text,
                                     const std::map<std::string, std::string>& refs);

} // namespace mdcore
