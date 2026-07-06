#pragma once

#include <map>
#include <string>
#include <vector>
#include "Token.hpp"

namespace mdcore {

class Lexer {
public:
    std::vector<Token> tokenize(const std::string& source) const;

    /// Extrae definiciones de enlaces por referencia: [ref]: url
    static std::map<std::string, std::string> parseReferences(const std::string& source);
};

} // namespace mdcore
