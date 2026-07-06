import CoreGraphics

/// Resaltador de sintaxis basico para bloques de codigo.
/// Reconoce palabras clave, strings, comentarios y numeros.
enum SyntaxHighlighter {

    // Colores inspirados en GitHub.
    private static let keywordColor = CGColor(red: 0xCF/255.0, green: 0x22/255.0, blue: 0x2E/255.0, alpha: 1.0) // rojo #CF222E
    private static let stringColor  = CGColor(red: 0x0A/255.0, green: 0x30/255.0, blue: 0x69/255.0, alpha: 1.0) // azul oscuro #0A3069
    private static let commentColor = CGColor(red: 0x6E/255.0, green: 0x77/255.0, blue: 0x81/255.0, alpha: 1.0) // gris #6E7781
    private static let numberColor  = CGColor(red: 0x05/255.0, green: 0x54/255.0, blue: 0xAE/255.0, alpha: 1.0) // azul #0554AE
    private static let typeColor    = CGColor(red: 0x82/255.0, green: 0x5D/255.0, blue: 0x25/255.0, alpha: 1.0) // marron #825D25
    private static let plainColor   = CGColor(red: 0x1F/255.0, green: 0x23/255.0, blue: 0x28/255.0, alpha: 1.0) // negro #1F2328

    private static let keywords: Set<String> = [
        // Swift
        "let", "var", "func", "class", "struct", "enum", "protocol", "extension",
        "import", "return", "if", "else", "guard", "switch", "case", "default",
        "for", "while", "repeat", "in", "break", "continue", "where", "throws",
        "throw", "try", "catch", "do", "as", "is", "self", "Self", "super",
        "true", "false", "nil", "public", "private", "internal", "fileprivate",
        "static", "final", "override", "mutating", "nonmutating", "lazy", "weak",
        "unowned", "required", "optional", "convenience", "init", "deinit",
        "subscript", "associatedtype", "typealias", "some", "any", "async", "await",
        // Python
        "def", "from", "not", "and", "or", "pass", "yield", "lambda", "with",
        "raise", "except", "finally", "elif", "print", "None",
        // JavaScript/TypeScript
        "function", "const", "new", "typeof", "instanceof", "this", "undefined",
        "export", "default", "null", "void", "delete",
        // C/C++
        "int", "double", "float", "char", "bool", "void", "unsigned", "signed",
        "long", "short", "const", "auto", "include", "define", "ifdef", "endif",
        "namespace", "using", "template", "typename", "virtual", "explicit",
        // Go
        "package", "go", "defer", "select", "chan", "map", "range", "interface",
        "string", "error", "byte", "rune", "int32", "int64", "uint", "uintptr",
        // Rust
        "fn", "impl", "trait", "crate", "mod", "use", "pub", "mut", "ref",
        "match", "loop", "move", "unsafe", "dyn", "extern",
        // Shell
        "echo", "export", "source", "alias", "unset", "readonly", "local",
        "fi", "esac", "done", "elif", "then",
    ]

    private static let builtinTypes: Set<String> = [
        "String", "Int", "Double", "Float", "Bool", "Void", "Any", "AnyObject",
        "Array", "Dictionary", "Set", "Optional", "Result", "Error", "Data",
        "URL", "Date", "UUID", "CGFloat", "CGColor", "CGContext", "CGRect",
        "CTFont", "CTLine", "CFString", "CFDictionary", "NSObject", "NSArray",
        "NSDictionary", "NSString", "NSData", "NSURL",
    ]

    /// Determina el color para un token de codigo.
    static func color(for token: String) -> CGColor {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return plainColor }

        // Strings: "texto" o 'texto'
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return stringColor
        }

        // Comentarios: // o /* */
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") || trimmed.hasPrefix("#") {
            return commentColor
        }

        // Numeros: enteros o decimales
        if let first = trimmed.first, first.isNumber || (first == "-" && trimmed.count > 1 && trimmed[trimmed.index(after: trimmed.startIndex)].isNumber) {
            return numberColor
        }

        // Palabras clave
        if keywords.contains(trimmed) {
            return keywordColor
        }

        // Tipos built-in
        if builtinTypes.contains(trimmed) {
            return typeColor
        }

        return plainColor
    }
}
