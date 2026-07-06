#pragma once

#include <map>
#include <string>
#include <vector>
#include "Block.hpp"
#include "Token.hpp"

namespace mdcore {

class ASTBuilder {
public:
    std::vector<Block> build(const std::vector<Token>& tokens) const;

    /// Construye el AST resolviendo enlaces por referencia.
    std::vector<Block> build(const std::vector<Token>& tokens,
                             const std::map<std::string, std::string>& refs) const;
};

} // namespace mdcore
