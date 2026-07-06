#include "Lexer.hpp"

#include <cctype>
#include <sstream>

namespace mdcore {

namespace {

std::size_t countLeading(const std::string& line, char c) {
    std::size_t n = 0;
    while (n < line.size() && line[n] == c) {
        ++n;
    }
    return n;
}

std::string trim(const std::string& s) {
    std::size_t start = s.find_first_not_of(" \t\r");
    if (start == std::string::npos) {
        return "";
    }
    std::size_t end = s.find_last_not_of(" \t\r");
    return s.substr(start, end - start + 1);
}

// "---", "***" o "___": al menos 3 caracteres iguales y nada más.
bool isHorizontalRule(const std::string& trimmed) {
    if (trimmed.size() < 3) {
        return false;
    }
    char c = trimmed[0];
    if (c != '-' && c != '*' && c != '_') {
        return false;
    }
    for (char ch : trimmed) {
        if (ch != c) {
            return false;
        }
    }
    return true;
}

// "1. texto", "2. texto"... Devuelve el número y el resto de la línea.
bool isOrderedListItem(const std::string& trimmed, int& number, std::string& rest) {
    std::size_t i = 0;
    while (i < trimmed.size() && std::isdigit(static_cast<unsigned char>(trimmed[i]))) {
        ++i;
    }
    if (i == 0 || i + 1 >= trimmed.size() || trimmed[i] != '.' || trimmed[i + 1] != ' ') {
        return false;
    }
    number = std::stoi(trimmed.substr(0, i));
    rest = trimmed.substr(i + 2);
    return true;
}

// "| celda | celda |" — fila de tabla. Empieza y acaba con '|'.
bool isTableRow(const std::string& trimmed) {
    return trimmed.size() >= 2 && trimmed.front() == '|' && trimmed.back() == '|';
}

// Detecta si una linea empieza una etiqueta HTML de bloque: <div>, <pre>,
// <table>, <section>, <article>, <header>, <footer>, <nav>, <aside>,
// <main>, <form>, <fieldset>, <details>, <summary>, <figure>, <figcaption>,
// <blockquote>, <dl>, <dt>, <dd>, <ol>, <ul>, <li>, <p>, <h1>-<h6>,
// <hr>, <address>.
// Tambien sus variantes con atributos: <div class="x">, <pre id="y">, etc.
bool isHtmlBlockTag(const std::string& trimmed) {
    if (trimmed.size() < 3 || trimmed[0] != '<') return false;
    std::size_t i = 1;
    if (i < trimmed.size() && trimmed[i] == '/') ++i; // cierre </div>
    std::size_t tagStart = i;
    while (i < trimmed.size() && std::isalpha(static_cast<unsigned char>(trimmed[i]))) ++i;
    std::string tag = trimmed.substr(tagStart, i - tagStart);
    // convertir a minusculas
    for (char& c : tag) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    static const std::vector<std::string> blockTags = {
        "div", "pre", "table", "section", "article", "header", "footer",
        "nav", "aside", "main", "form", "fieldset", "details", "summary",
        "figure", "figcaption", "blockquote", "dl", "dt", "dd", "ol", "ul",
        "li", "p", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "address",
        "style", "script", "noscript", "iframe"
    };
    for (const auto& t : blockTags) {
        if (tag == t) {
            // La etiqueta debe cerrar o tener un atributo/espacio: <div>, <div >
            if (i >= trimmed.size() || trimmed[i] == '>' || trimmed[i] == ' ' || trimmed[i] == '\t') {
                return true;
            }
        }
    }
    return false;
}

bool isCodeFenceStart(const std::string& trimmed, char& fenceChar, std::size_t& fenceLength) {
    if (trimmed.empty() || (trimmed[0] != '`' && trimmed[0] != '~')) {
        return false;
    }
    std::size_t n = countLeading(trimmed, trimmed[0]);
    if (n < 3) {
        return false;
    }
    fenceChar = trimmed[0];
    fenceLength = n;
    return true;
}

bool isCodeFenceClose(const std::string& trimmed, char fenceChar, std::size_t fenceLength) {
    if (trimmed.empty() || trimmed[0] != fenceChar) {
        return false;
    }
    std::size_t n = countLeading(trimmed, fenceChar);
    if (n < fenceLength) {
        return false;
    }
    for (std::size_t i = n; i < trimmed.size(); ++i) {
        if (trimmed[i] != ' ' && trimmed[i] != '\t') {
            return false;
        }
    }
    return true;
}

} // namespace

std::vector<Token> Lexer::tokenize(const std::string& source) const {
    std::vector<Token> tokens;
    std::istringstream stream(source);
    std::string line;

    // YAML front-matter: solo si la primera linea es --- y hay cierre.
    bool inFrontMatter = false;
    std::string firstLine;
    std::streampos startPos = stream.tellg();
    if (std::getline(stream, firstLine)) {
        std::string t = trim(firstLine);
        if (t == "---") {
            std::string probeLine;
            bool foundClose = false;
            int linesChecked = 0;
            while (std::getline(stream, probeLine) && linesChecked < 20) {
                if (trim(probeLine) == "---" || trim(probeLine) == "...") {
                    foundClose = true;
                    break;
                }
                ++linesChecked;
            }
            if (foundClose) {
                inFrontMatter = true;
            }
            stream.clear();
            stream.seekg(startPos);
        } else {
            stream.clear();
            stream.seekg(startPos);
        }
    }

    bool insideCodeBlock = false;
    char codeFenceChar = '`';
    std::size_t codeFenceLength = 3;
    std::string codeBlockLanguage;
    std::string codeBlockContent;

    bool insideIndentedCode = false;
    std::string indentedCodeContent;

    bool insideHtmlBlock = false;
    std::string htmlBlockContent;

    bool insideMathBlock = false;
    std::string mathBlockContent;

    while (std::getline(stream, line)) {
        // Saltar front-matter YAML.
        if (inFrontMatter) {
            std::string t = trim(line);
            if (t == "---" || t == "...") {
                inFrontMatter = false;
            }
            continue;
        }

        // Hard line break: dos espacios al final de la linea.
        bool hardBreak = line.size() >= 2 && line[line.size() - 1] == ' ' && line[line.size() - 2] == ' ';
        int indent = static_cast<int>(countLeading(line, ' '));
        std::string trimmed = trim(line);

        // Codigo indentado: maquina de estados.
        if (!insideCodeBlock && insideIndentedCode) {
            if (!trimmed.empty() && indent >= 4) {
                indentedCodeContent += '\n';
                indentedCodeContent += line.substr(4);
                continue;
            } else {
                tokens.emplace_back(TokenKind::CodeBlock, indentedCodeContent);
                indentedCodeContent.clear();
                insideIndentedCode = false;
                // No hacer continue; procesar esta linea normalmente.
            }
        }

        // HTML block: maquina de estados. Acumula lineas hasta blank line.
        if (!insideCodeBlock && !insideIndentedCode && insideHtmlBlock) {
            if (trimmed.empty()) {
                tokens.emplace_back(TokenKind::RawHtmlBlock, htmlBlockContent);
                htmlBlockContent.clear();
                insideHtmlBlock = false;
                tokens.emplace_back(TokenKind::BlankLine, "");
                continue;
            }
            // Comprobar si esta linea empieza un nuevo bloque HTML anidado.
            if (isHtmlBlockTag(trimmed)) {
                htmlBlockContent += '\n';
                htmlBlockContent += line;
                continue;
            }
            htmlBlockContent += '\n';
            htmlBlockContent += line;
            continue;
        }

        // Math block: $$ ... $$. Maquina de estados similar a HTML block.
        if (!insideCodeBlock && !insideIndentedCode && !insideHtmlBlock && insideMathBlock) {
            if (trimmed == "$$") {
                tokens.emplace_back(TokenKind::MathBlock, mathBlockContent);
                mathBlockContent.clear();
                insideMathBlock = false;
                continue;
            }
            if (!mathBlockContent.empty()) {
                mathBlockContent += '\n';
            }
            mathBlockContent += line;
            continue;
        }

        if (!insideCodeBlock && !insideIndentedCode && indent >= 4 && !trimmed.empty()
            && trimmed[0] != '-' && trimmed[0] != '>' && trimmed[0] != '#' && trimmed[0] != '|') {
            insideIndentedCode = true;
            indentedCodeContent = line.substr(4);
            continue;
        }

        if (insideCodeBlock) {
            if (isCodeFenceClose(trimmed, codeFenceChar, codeFenceLength)) {
                tokens.emplace_back(TokenKind::CodeBlock, codeBlockContent, 0, codeBlockLanguage);
                insideCodeBlock = false;
                codeFenceChar = '`';
                codeFenceLength = 3;
                codeBlockLanguage.clear();
                codeBlockContent.clear();
            } else {
                if (!codeBlockContent.empty()) {
                    codeBlockContent += '\n';
                }
                codeBlockContent += line;
            }
            continue;
        }

        char fenceChar = '`';
        std::size_t fenceLength = 0;
        if (isCodeFenceStart(trimmed, fenceChar, fenceLength)) {
            insideCodeBlock = true;
            codeFenceChar = fenceChar;
            codeFenceLength = fenceLength;
            codeBlockLanguage = trim(trimmed.substr(fenceLength));
            continue;
        }

        if (trimmed.empty()) {
            tokens.emplace_back(TokenKind::BlankLine, "");
            continue;
        }

        if (isHorizontalRule(trimmed)) {
            tokens.emplace_back(TokenKind::HorizontalRule, "");
            continue;
        }

        std::size_t hashes = countLeading(trimmed, '#');
        if (hashes >= 1 && hashes <= 6 && hashes < trimmed.size() && trimmed[hashes] == ' ') {
            tokens.emplace_back(TokenKind::Heading, trim(trimmed.substr(hashes + 1)), static_cast<int>(hashes));
            continue;
        }

        if (trimmed.size() >= 2 && trimmed[0] == '-' && trimmed[1] == ' ') {
            // Task list: - [ ] texto  o  - [x] texto
            if (trimmed.size() >= 6 && trimmed[2] == '[' && trimmed[4] == ']' && trimmed[5] == ' ') {
                bool chk = (trimmed[3] == 'x' || trimmed[3] == 'X');
                if (chk || trimmed[3] == ' ') {
                    tokens.emplace_back(TokenKind::UnorderedListItem, trimmed.substr(6), 0, "", chk, false, indent, true);
                    continue;
                }
            }
            tokens.emplace_back(TokenKind::UnorderedListItem, trimmed.substr(2), 0, "", false, false, indent);
            continue;
        }

        int number = 0;
        std::string rest;
        if (isOrderedListItem(trimmed, number, rest)) {
            tokens.emplace_back(TokenKind::OrderedListItem, rest, number, "", false, false, indent);
            continue;
        }

        if (isTableRow(trimmed)) {
            tokens.emplace_back(TokenKind::TableRow, trimmed);
            continue;
        }

        if (trimmed.size() >= 2 && trimmed[0] == '>' && (trimmed[1] == ' ' || trimmed[1] == '\t')) {
            tokens.emplace_back(TokenKind::Blockquote, trimmed.substr(2));
            continue;
        }
        if (trimmed == ">") {
            tokens.emplace_back(TokenKind::Blockquote, "");
            continue;
        }

        if (isHtmlBlockTag(trimmed)) {
            insideHtmlBlock = true;
            htmlBlockContent = line;
            continue;
        }

        // Math block: $$ ... $$
        if (trimmed == "$$" && !insideCodeBlock && !insideIndentedCode && !insideHtmlBlock) {
            insideMathBlock = true;
            continue;
        }

        // Footnote definition: [^label]: definicion
        if (trimmed.size() >= 4 && trimmed[0] == '[' && trimmed[1] == '^') {
            std::size_t closeBracket = trimmed.find(']', 2);
            if (closeBracket != std::string::npos &&
                closeBracket + 1 < trimmed.size() && trimmed[closeBracket + 1] == ':') {
                std::string label = trimmed.substr(2, closeBracket - 2);
                std::string def = trim(trimmed.substr(closeBracket + 2));
                Token tok;
                tok.kind = TokenKind::FootnoteDef;
                tok.text = def;
                tok.footnoteLabel = label;
                tokens.push_back(std::move(tok));
                continue;
            }
        }

        tokens.emplace_back(TokenKind::Paragraph, trimmed, 0, "", false, hardBreak);
    }

    // Documento que termina con un bloque de codigo sin cerrar: se
    // vuelca igualmente en vez de perder el contenido.
    if (insideCodeBlock) {
        tokens.emplace_back(TokenKind::CodeBlock, codeBlockContent, 0, codeBlockLanguage);
    }
    if (insideIndentedCode) {
        tokens.emplace_back(TokenKind::CodeBlock, indentedCodeContent);
    }
    if (insideHtmlBlock) {
        tokens.emplace_back(TokenKind::RawHtmlBlock, htmlBlockContent);
    }
    if (insideMathBlock) {
        tokens.emplace_back(TokenKind::MathBlock, mathBlockContent);
    }

    // Post-procesado: Setext headings (= o - bajo un parrafo).
    for (std::size_t i = 1; i < tokens.size(); ++i) {
        if (tokens[i].kind == TokenKind::Paragraph) {
            const std::string& t = tokens[i].text;
            if (t.size() >= 1 && (t[0] == '=' || t[0] == '-')) {
                bool allSame = true;
                for (char c : t) {
                    if (c != t[0]) { allSame = false; break; }
                }
                if (allSame && t.size() >= 1 && tokens[i - 1].kind == TokenKind::Paragraph) {
                    int level = (t[0] == '=') ? 1 : 2;
                    tokens[i - 1].kind = TokenKind::Heading;
                    tokens[i - 1].level = level;
                    tokens.erase(tokens.begin() + static_cast<std::ptrdiff_t>(i));
                    --i;
                }
            }
        }
    }

    return tokens;
}

std::map<std::string, std::string> Lexer::parseReferences(const std::string& source) {
    std::map<std::string, std::string> refs;
    std::istringstream stream(source);
    std::string line;
    while (std::getline(stream, line)) {
        std::string t = trim(line);
        // [ref]: url
        if (t.size() >= 4 && t[0] == '[') {
            std::size_t close = t.find(']');
            if (close != std::string::npos && close + 2 < t.size() && t[close + 1] == ':') {
                std::string ref = t.substr(1, close - 1);
                std::string url = trim(t.substr(close + 2));
                if (!ref.empty() && !url.empty()) {
                    refs[ref] = url;
                }
            }
        }
    }
    return refs;
}

} // namespace mdcore
