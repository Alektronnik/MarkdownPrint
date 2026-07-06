#include "InlineParser.hpp"

#include <algorithm>
#include <cctype>
#include <map>
#include <string>

namespace mdcore {

namespace {

std::string lower(const std::string& s) {
    std::string r = s;
    for (auto& c : r) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return r;
}

// Intenta parsear una etiqueta HTML a partir de la posicion i (i apunta a '<').
// Devuelve true si se parseo correctamente.
//   tagName  -> nombre de la etiqueta en minusculas
//   attrs    -> mapa de atributos (ej. {"href": "url", "src": "img.png"})
//   selfClose -> true si acaba en />
//   endPos   -> posicion justo despues de '>'
bool parseHtmlTag(const std::string& text, std::size_t i,
                  std::string& tagName,
                  std::map<std::string, std::string>& attrs,
                  bool& selfClose,
                  std::size_t& endPos) {
    if (i >= text.size() || text[i] != '<') return false;
    std::size_t start = i + 1;
    if (start >= text.size()) return false;

    // Leer nombre de etiqueta
    std::size_t nameEnd = start;
    while (nameEnd < text.size() && std::isalnum(static_cast<unsigned char>(text[nameEnd]))) {
        ++nameEnd;
    }
    if (nameEnd == start) return false;
    tagName = lower(text.substr(start, nameEnd - start));

    // Parsear atributos
    attrs.clear();
    selfClose = false;
    std::size_t pos = nameEnd;

    while (pos < text.size()) {
        // Saltar espacios
        while (pos < text.size() && std::isspace(static_cast<unsigned char>(text[pos]))) ++pos;
        if (pos >= text.size()) return false;

        if (text[pos] == '>') {
            endPos = pos + 1;
            return true;
        }
        if (text[pos] == '/' && pos + 1 < text.size() && text[pos + 1] == '>') {
            selfClose = true;
            endPos = pos + 2;
            return true;
        }

        // Leer nombre de atributo
        std::size_t attrStart = pos;
        while (pos < text.size() && (std::isalnum(static_cast<unsigned char>(text[pos])) || text[pos] == '-' || text[pos] == '_')) {
            ++pos;
        }
        if (pos == attrStart) return false;
        std::string attrName = lower(text.substr(attrStart, pos - attrStart));

        // Saltar espacios antes de =
        while (pos < text.size() && std::isspace(static_cast<unsigned char>(text[pos]))) ++pos;

        std::string attrValue;
        if (pos < text.size() && text[pos] == '=') {
            ++pos;
            while (pos < text.size() && std::isspace(static_cast<unsigned char>(text[pos]))) ++pos;
            if (pos < text.size() && (text[pos] == '"' || text[pos] == '\'')) {
                char quote = text[pos];
                ++pos;
                std::size_t valEnd = text.find(quote, pos);
                if (valEnd == std::string::npos) return false;
                attrValue = text.substr(pos, valEnd - pos);
                pos = valEnd + 1;
            } else {
                // Valor sin comillas
                std::size_t valStart = pos;
                while (pos < text.size() && !std::isspace(static_cast<unsigned char>(text[pos])) && text[pos] != '>' && text[pos] != '/') {
                    ++pos;
                }
                attrValue = text.substr(valStart, pos - valStart);
            }
        }
        attrs[attrName] = attrValue;
    }
    return false;
}

} // namespace

std::vector<InlineRun> parseInlines(const std::string& text) {
    std::map<std::string, std::string> empty;
    return parseInlines(text, empty);
}

std::vector<InlineRun> parseInlines(const std::string& text,
                                     const std::map<std::string, std::string>& refs) {
    std::vector<InlineRun> runs;
    std::string buffer;

    auto flushPlain = [&]() {
        if (!buffer.empty()) {
            runs.emplace_back(InlineKind::PlainText, buffer);
            buffer.clear();
        }
    };

    std::size_t i = 0;
    while (i < text.size()) {
        // Escapado: \X -> X literal
        if (text[i] == '\\' && i + 1 < text.size()) {
            buffer += text[i + 1];
            i += 2;
            continue;
        }

        // Codigo: `texto`
        if (text[i] == '`') {
            std::size_t close = text.find('`', i + 1);
            if (close != std::string::npos) {
                flushPlain();
                runs.emplace_back(InlineKind::Code, text.substr(i + 1, close - i - 1));
                i = close + 1;
                continue;
            }
        }
        // Math inline: $...$ (no $$ que es bloque)
        if (text[i] == '$' && (i + 1 >= text.size() || text[i + 1] != '$')) {
            std::size_t close = text.find('$', i + 1);
            if (close != std::string::npos && (close + 1 >= text.size() || text[close + 1] != '$')) {
                flushPlain();
                runs.emplace_back(InlineKind::InlineMath, text.substr(i + 1, close - i - 1));
                i = close + 1;
                continue;
            }
        }
        // Tachado: ~~texto~~
        if (i + 1 < text.size() && text[i] == '~' && text[i + 1] == '~') {
            std::size_t close = text.find("~~", i + 2);
            if (close != std::string::npos) {
                flushPlain();
                runs.emplace_back(InlineKind::Strikethrough, text.substr(i + 2, close - i - 2));
                i = close + 2;
                continue;
            }
        }
        // Imagen: ![alt](url)
        if (text[i] == '!' && i + 1 < text.size() && text[i + 1] == '[') {
            std::size_t closeBracket = text.find(']', i + 2);
            if (closeBracket != std::string::npos &&
                closeBracket + 1 < text.size() && text[closeBracket + 1] == '(') {
                std::size_t closeParen = text.find(')', closeBracket + 2);
                if (closeParen != std::string::npos) {
                    flushPlain();
                    std::string altText = text.substr(i + 2, closeBracket - i - 2);
                    std::string imageUrl = text.substr(closeBracket + 2, closeParen - closeBracket - 2);
                    runs.emplace_back(InlineKind::Image, altText, imageUrl);
                    i = closeParen + 1;
                    continue;
                }
            }
        }

        // HTML inline: <tag ...>
        if (text[i] == '<' && i + 1 < text.size() && std::isalpha(static_cast<unsigned char>(text[i + 1]))) {
            std::string tagName;
            std::map<std::string, std::string> attrs;
            bool selfClose = false;
            std::size_t tagEnd = 0;

            if (parseHtmlTag(text, i, tagName, attrs, selfClose, tagEnd)) {
                // <br> o <br/>
                if (tagName == "br") {
                    flushPlain();
                    runs.emplace_back(InlineKind::HardBreak, "");
                    i = tagEnd;
                    continue;
                }
                // <img src="..." alt="..." /> o <img src="..." alt="...">
                if (tagName == "img") {
                    flushPlain();
                    std::string src, alt;
                    auto sit = attrs.find("src");
                    if (sit != attrs.end()) src = sit->second;
                    auto ait = attrs.find("alt");
                    if (ait != attrs.end()) alt = ait->second;
                    runs.emplace_back(InlineKind::Image, alt, src);
                    i = tagEnd;
                    if (!selfClose) {
                        // Si no es self-closing, buscar </img> de cierre
                        std::size_t closeImg = text.find("</img>", i);
                        if (closeImg != std::string::npos) i = closeImg + 6;
                    }
                    continue;
                }
                // <em>texto</em>
                if (tagName == "em") {
                    std::size_t closeTag = text.find("</em>", tagEnd);
                    if (closeTag != std::string::npos) {
                        flushPlain();
                        runs.emplace_back(InlineKind::Italic, text.substr(tagEnd, closeTag - tagEnd));
                        i = closeTag + 5;
                        continue;
                    }
                }
                // <strong>texto</strong>
                if (tagName == "strong") {
                    std::size_t closeTag = text.find("</strong>", tagEnd);
                    if (closeTag != std::string::npos) {
                        flushPlain();
                        runs.emplace_back(InlineKind::Bold, text.substr(tagEnd, closeTag - tagEnd));
                        i = closeTag + 9;
                        continue;
                    }
                }
                // <code>texto</code>
                if (tagName == "code") {
                    std::size_t closeTag = text.find("</code>", tagEnd);
                    if (closeTag != std::string::npos) {
                        flushPlain();
                        runs.emplace_back(InlineKind::Code, text.substr(tagEnd, closeTag - tagEnd));
                        i = closeTag + 7;
                        continue;
                    }
                }
                // <del>texto</del>
                if (tagName == "del") {
                    std::size_t closeTag = text.find("</del>", tagEnd);
                    if (closeTag != std::string::npos) {
                        flushPlain();
                        runs.emplace_back(InlineKind::Strikethrough, text.substr(tagEnd, closeTag - tagEnd));
                        i = closeTag + 6;
                        continue;
                    }
                }
                // <a href="url">texto</a>
                if (tagName == "a") {
                    std::size_t closeTag = text.find("</a>", tagEnd);
                    if (closeTag != std::string::npos) {
                        flushPlain();
                        std::string href;
                        auto hit = attrs.find("href");
                        if (hit != attrs.end()) href = hit->second;
                        runs.emplace_back(InlineKind::Link, text.substr(tagEnd, closeTag - tagEnd), href);
                        i = closeTag + 4;
                        continue;
                    }
                }
                // Etiqueta HTML desconocida o sin cierre: tratar '<' como literal
            }
        }

        // Footnote reference: [^label]
        if (text[i] == '[' && i + 1 < text.size() && text[i + 1] == '^') {
            std::size_t closeBracket = text.find(']', i + 2);
            if (closeBracket != std::string::npos) {
                flushPlain();
                std::string label = text.substr(i + 2, closeBracket - i - 2);
                runs.emplace_back(InlineKind::FootnoteRef, label);
                i = closeBracket + 1;
                continue;
            }
        }

        // Cross-reference: [@type:label]
        if (text[i] == '[' && i + 1 < text.size() && text[i + 1] == '@') {
            std::size_t closeBracket = text.find(']', i + 2);
            if (closeBracket != std::string::npos) {
                flushPlain();
                std::string label = text.substr(i + 2, closeBracket - i - 2); // "sec:metodo"
                runs.emplace_back(InlineKind::CrossRef, "[" + label + "]");
                runs.back().crossRefLabel = label;
                i = closeBracket + 1;
                continue;
            }
        }

        // Heading label: {#label} at end of text (swallowed, extracted in AST)

        // Enlace: [texto](url) o [texto][ref]
        if (text[i] == '[') {
            std::size_t closeBracket = text.find(']', i + 1);
            if (closeBracket != std::string::npos) {
                // [texto](url)
                if (closeBracket + 1 < text.size() && text[closeBracket + 1] == '(') {
                    std::size_t closeParen = text.find(')', closeBracket + 2);
                    if (closeParen != std::string::npos) {
                        flushPlain();
                        std::string linkText = text.substr(i + 1, closeBracket - i - 1);
                        std::string linkUrl  = text.substr(closeBracket + 2, closeParen - closeBracket - 2);
                        runs.emplace_back(InlineKind::Link, linkText, linkUrl);
                        i = closeParen + 1;
                        continue;
                    }
                }
                // [texto][ref] o [texto][]
                if (closeBracket + 1 < text.size() && text[closeBracket + 1] == '[') {
                    std::size_t closeRef = text.find(']', closeBracket + 2);
                    if (closeRef != std::string::npos) {
                        std::string linkText = text.substr(i + 1, closeBracket - i - 1);
                        std::string ref = text.substr(closeBracket + 2, closeRef - closeBracket - 2);
                        if (ref.empty()) ref = linkText; // [texto][] usa texto como ref
                        auto it = refs.find(ref);
                        if (it != refs.end()) {
                            flushPlain();
                            runs.emplace_back(InlineKind::Link, linkText, it->second);
                            i = closeRef + 1;
                            continue;
                        }
                    }
                }
            }
        }

        // Negrita: **texto**
        if (i + 1 < text.size() && text[i] == '*' && text[i + 1] == '*') {
            std::size_t close = text.find("**", i + 2);
            if (close != std::string::npos) {
                flushPlain();
                runs.emplace_back(InlineKind::Bold, text.substr(i + 2, close - i - 2));
                i = close + 2;
                continue;
            }
        }

        // Cursiva: *texto*
        if (text[i] == '*') {
            std::size_t close = text.find('*', i + 1);
            if (close != std::string::npos) {
                flushPlain();
                runs.emplace_back(InlineKind::Italic, text.substr(i + 1, close - i - 1));
                i = close + 1;
                continue;
            }
        }

        // Marcador sin cierre (p. ej. un "*" suelto): se trata como
        // texto literal en vez de consumir el resto de la línea.
        buffer += text[i];
        ++i;
    }

    flushPlain();
    return runs;
}

} // namespace mdcore
