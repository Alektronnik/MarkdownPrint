#pragma once

#include <string>
#include "InlineKind.hpp"

namespace mdcore {

struct InlineRun {
    InlineKind kind = InlineKind::PlainText;
    std::string text;
    std::string url;          // solo cuando kind == Link
    std::string crossRefLabel;// CrossRef: "sec:metodo", FootnoteRef: "1"

    InlineRun() = default;
    InlineRun(InlineKind k, std::string t, std::string u = "") : kind(k), text(std::move(t)), url(std::move(u)) {}
};

} // namespace mdcore
