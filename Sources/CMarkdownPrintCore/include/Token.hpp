#pragma once

#include <string>
#include "TokenKind.hpp"

namespace mdcore {

struct Token {
    TokenKind kind = TokenKind::Unknown;
    std::string text;
    int level = 0;
    std::string language;
    bool checked = false;
    bool hardBreak = false;
    int indent = 0;
    bool isTask = false;
    std::string footnoteLabel;

    Token() = default;
    Token(TokenKind k, std::string t, int lvl = 0, std::string lang = "",
          bool chk = false, bool hb = false, int ind = 0, bool task = false)
        : kind(k), text(std::move(t)), level(lvl), language(std::move(lang)),
          checked(chk), hardBreak(hb), indent(ind), isTask(task) {}
};

} // namespace mdcore
