#include "ASTBuilder.hpp"
#include "InlineParser.hpp"

#include <sstream>

namespace mdcore {

namespace {

// " --- ", " :--- ", " :---: ", " ---: " -> true (al menos 3 guiones).
bool isTableSeparatorCell(const std::string& cell) {
    std::size_t dashes = 0;
    for (char c : cell) {
        if (c == '-') {
            ++dashes;
        } else if (c != ':' && c != ' ') {
            return false;
        }
    }
    return dashes >= 3;
}

// "| celda | celda |" -> {"celda", "celda"}
std::vector<std::string> splitTableCells(const std::string& line) {
    std::vector<std::string> cells;
    if (line.size() < 2) return cells;
    std::string inner = line.substr(1, line.size() - 2); // quitar | inicial y final
    std::istringstream stream(inner);
    std::string cell;
    while (std::getline(stream, cell, '|')) {
        // trim manual
        std::size_t start = cell.find_first_not_of(" \t");
        if (start == std::string::npos) {
            cells.push_back("");
        } else {
            std::size_t end = cell.find_last_not_of(" \t");
            cells.push_back(cell.substr(start, end - start + 1));
        }
    }
    return cells;
}

} // namespace

std::vector<Block> ASTBuilder::build(const std::vector<Token>& tokens) const {
    std::map<std::string, std::string> empty;
    return build(tokens, empty);
}

std::vector<Block> ASTBuilder::build(const std::vector<Token>& tokens,
                                      const std::map<std::string, std::string>& refs) const {
    std::vector<Block> blocks;
    std::size_t i = 0;

    while (i < tokens.size()) {
        const Token& token = tokens[i];

        switch (token.kind) {
            case TokenKind::BlankLine: {
                ++i;
                break;
            }

            case TokenKind::Heading: {
                Block block;
                block.kind = BlockKind::Heading;
                block.level = token.level;
                block.inlines = parseInlines(token.text, refs);
                blocks.push_back(std::move(block));
                ++i;
                break;
            }

            case TokenKind::HorizontalRule: {
                Block block;
                block.kind = BlockKind::HorizontalRule;
                blocks.push_back(std::move(block));
                ++i;
                break;
            }

            case TokenKind::CodeBlock: {
                Block block;
                block.kind = BlockKind::CodeBlock;
                block.language = token.language;
                block.text = token.text;
                blocks.push_back(std::move(block));
                ++i;
                break;
            }

            case TokenKind::UnorderedListItem: {
                // Agrupar items consecutivos, luego anidar por indentacion.
                std::vector<Token> listTokens;
                while (i < tokens.size() && tokens[i].kind == TokenKind::UnorderedListItem) {
                    listTokens.push_back(tokens[i]);
                    ++i;
                }
                if (listTokens.empty()) break;

                Block block;
                block.kind = BlockKind::UnorderedList;
                int baseIndent = listTokens[0].indent;

                // Pila para anidar: (indent, items*)
                std::vector<ListItem*> stack;
                for (const auto& tok : listTokens) {
                    ListItem item;
                    item.number = 0;
                    item.checked = tok.checked;
                    item.isTask = tok.isTask;
                    item.indent = tok.indent;
                    item.inlines = parseInlines(tok.text, refs);

                    // Encontrar el padre: ultimo item con indent menor.
                    while (!stack.empty() && stack.back()->indent >= tok.indent) {
                        stack.pop_back();
                    }
                    if (stack.empty()) {
                        block.items.push_back(std::move(item));
                        stack.push_back(&block.items.back());
                    } else {
                        stack.back()->items.push_back(std::move(item));
                        stack.push_back(&stack.back()->items.back());
                    }
                }
                blocks.push_back(std::move(block));
                break;
            }

            case TokenKind::OrderedListItem: {
                std::vector<Token> listTokens;
                while (i < tokens.size() && tokens[i].kind == TokenKind::OrderedListItem) {
                    listTokens.push_back(tokens[i]);
                    ++i;
                }
                if (listTokens.empty()) break;

                Block block;
                block.kind = BlockKind::OrderedList;
                int baseIndent = listTokens[0].indent;
                int startNumber = listTokens[0].level;
                int itemIndex = 0;

                std::vector<ListItem*> stack;
                for (const auto& tok : listTokens) {
                    ListItem item;
                    item.number = startNumber + itemIndex;
                    item.indent = tok.indent;
                    item.inlines = parseInlines(tok.text, refs);
                    ++itemIndex;

                    while (!stack.empty() && stack.back()->indent >= tok.indent) {
                        stack.pop_back();
                    }
                    if (stack.empty()) {
                        block.items.push_back(std::move(item));
                        stack.push_back(&block.items.back());
                    } else {
                        stack.back()->items.push_back(std::move(item));
                        stack.push_back(&stack.back()->items.back());
                    }
                }
                blocks.push_back(std::move(block));
                break;
            }

            case TokenKind::TableRow: {
                // Agrupa filas consecutivas de tabla. La primera es
                // cabecera. Si la segunda tiene solo -, : y espacios,
                // es una fila separadora (se descarta).
                std::vector<Token> tableTokens;
                while (i < tokens.size() && tokens[i].kind == TokenKind::TableRow) {
                    tableTokens.push_back(tokens[i]);
                    ++i;
                }
                if (tableTokens.empty()) break;

                Block block;
                block.kind = BlockKind::Table;

                auto headerCells = splitTableCells(tableTokens[0].text);
                block.tableColumnCount = static_cast<int>(headerCells.size());
                for (const auto& cell : headerCells) {
                    block.tableHeaders.push_back(cell);
                    block.tableCells.push_back(cell); // cabecera como primera "fila de datos"
                }

                std::size_t dataStart = 1;
                if (tableTokens.size() > 1) {
                    auto secondRow = splitTableCells(tableTokens[1].text);
                    bool allSep = !secondRow.empty();
                    for (const auto& cell : secondRow) {
                        if (!isTableSeparatorCell(cell)) {
                            allSep = false;
                            break;
                        }
                    }
                    if (allSep) {
                        dataStart = 2;
                        // Detectar alineacion: :--- = left, :---: = center, ---: = right.
                        for (const auto& cell : secondRow) {
                            bool left = !cell.empty() && cell.front() == ':';
                            bool right = !cell.empty() && cell.back() == ':';
                            int align = (left && right) ? 1 : (right ? 2 : 0);
                            block.tableAlign.push_back(align);
                        }
                    }
                }

                for (std::size_t r = dataStart; r < tableTokens.size(); ++r) {
                    auto cells = splitTableCells(tableTokens[r].text);
                    for (const auto& cell : cells) {
                        block.tableCells.push_back(cell);
                    }
                }
                // No forzamos padding: las celdas faltantes se
                // manejan en Layout (columna vacia = celda vacia).

                blocks.push_back(std::move(block));
                break;
            }

            case TokenKind::Blockquote: {
                // Fusion "lazy" de lineas de cita consecutivas.
                std::string merged = tokens[i].text;
                ++i;
                while (i < tokens.size() && tokens[i].kind == TokenKind::Blockquote) {
                    merged += ' ';
                    merged += tokens[i].text;
                    ++i;
                }
                Block block;
                block.kind = BlockKind::Blockquote;
                block.inlines = parseInlines(merged, refs);
                blocks.push_back(std::move(block));
                break;
            }

            case TokenKind::MathBlock: {
                Block block;
                block.kind = BlockKind::MathBlock;
                block.text = tokens[i].text;
                ++i;
                blocks.push_back(std::move(block));
                break;
            }

            case TokenKind::FootnoteDef: {
                Block block;
                block.kind = BlockKind::FootnoteDef;
                block.text = tokens[i].text;           // definition text
                block.footnoteLabel = tokens[i].footnoteLabel; // [^label]
                ++i;
                blocks.push_back(std::move(block));
                break;
            }

            case TokenKind::RawHtmlBlock: {
                // Fusion "lazy" de lineas HTML consecutivas en un solo bloque.
                std::string merged = tokens[i].text;
                ++i;
                while (i < tokens.size() && tokens[i].kind == TokenKind::RawHtmlBlock) {
                    merged += '\n';
                    merged += tokens[i].text;
                    ++i;
                }
                Block block;
                block.kind = BlockKind::RawHtmlBlock;
                // Extraer el nombre de la etiqueta de la primera linea.
                std::string trimmed = merged;
                std::size_t start = trimmed.find_first_not_of(" \t");
                if (start != std::string::npos && start < trimmed.size() && trimmed[start] == '<') {
                    std::size_t tagStart = start + 1;
                    if (tagStart < trimmed.size() && trimmed[tagStart] == '/') ++tagStart;
                    std::size_t tagEnd = tagStart;
                    while (tagEnd < trimmed.size() && std::isalpha(static_cast<unsigned char>(trimmed[tagEnd]))) ++tagEnd;
                    block.htmlTag = trimmed.substr(tagStart, tagEnd - tagStart);
                    for (char& c : block.htmlTag) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
                }
                block.htmlContent = merged;
                blocks.push_back(std::move(block));
                break;
            }

            case TokenKind::Paragraph: {
                // Fusión "lazy": líneas de párrafo consecutivas, sin
                // línea en blanco entre medias, forman un solo bloque.
                std::string merged = tokens[i].text;
                ++i;
                while (i < tokens.size() && tokens[i].kind == TokenKind::Paragraph) {
                    merged += tokens[i - 1].hardBreak ? '\n' : ' ';
                    merged += tokens[i].text;
                    ++i;
                }
                Block block;
                block.kind = BlockKind::Paragraph;
                block.inlines = parseInlines(merged, refs);
                blocks.push_back(std::move(block));
                break;
            }

            default: {
                ++i;
                break;
            }
        }
    }

    return blocks;
}

} // namespace mdcore
