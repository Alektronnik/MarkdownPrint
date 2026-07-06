import Foundation

/// Parses command-line arguments into `RenderOptions` and input/output paths.
/// Exposed for testing -- the `markdownprint-cli` executable calls this directly.
public enum CLIParser {

    /// Parsed result from command-line arguments.
    public struct ParsedArgs {
        public let inputPath: String
        public let outputPath: String
        public let options: RenderOptions

        public init(inputPath: String, outputPath: String, options: RenderOptions) {
            self.inputPath = inputPath
            self.outputPath = outputPath
            self.options = options
        }
    }

    /// Parses command-line arguments (excluding argv[0]).
    public static func parse(
        _ args: [String],
        emitsWarnings: Bool = true,
        warningHandler: ((String) -> Void)? = nil
    ) -> ParsedArgs {
        var inputPath = ""
        var outputPath = ""
        var options = RenderOptions()
        func warn(_ message: String) {
            guard emitsWarnings else { return }
            let warning = "Warning: \(message)"
            warningHandler?(warning) ?? print(warning)
        }

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--size":
                i += 1
                if i < args.count {
                    switch args[i].lowercased() {
                    case "letter": options.pageSize = .usLetter
                    case "a4": options.pageSize = .a4
                    default: break
                    }
                }
            case "--theme":
                i += 1
                if i < args.count {
                    switch args[i].lowercased() {
                    case "light": options.theme = .light
                    case "dark": options.theme = .dark
                    case "mono": options.theme = .mono
                    default: break
                    }
                }
            case "--theme-file":
                i += 1
                if i < args.count {
                    do {
                        options.theme = try MarkdownPrintTheme.from(jsonFile: args[i])
                    } catch {
                        warn("could not load theme from \(args[i]): \(error.localizedDescription)")
                    }
                }
            case "--high-contrast": options.theme = .highContrast
            case "--toc": options.withTOC = true
            case "--title":
                i += 1
                if i < args.count { options.metadata = PDFMetadata(title: args[i], author: options.metadata.author) }
            case "--author":
                i += 1
                if i < args.count { options.metadata = PDFMetadata(title: options.metadata.title, author: args[i]) }
            case "--font":
                i += 1
                if i < args.count {
                    switch args[i].lowercased() {
                    case "web": options.fontFamily = .web
                    default: options.fontFamily = .apple
                    }
                }
            case "--justify": options.justifyText = true
            case "--line-numbers": options.showLineNumbers = true
            case "--watermark":
                i += 1
                if i < args.count { options.watermark = Watermark(kind: .text(args[i])) }
            case "--watermark-image":
                i += 1
                if i < args.count { options.watermark = Watermark(kind: .image(URL(fileURLWithPath: args[i]))) }
            case "--header":
                i += 1
                if i < args.count {
                    let hf = PageHeaderFooter(header: args[i], footer: options.headerFooter?.footer)
                    options.headerFooter = hf
                }
            case "--footer":
                i += 1
                if i < args.count {
                    let hf = PageHeaderFooter(header: options.headerFooter?.header, footer: args[i])
                    options.headerFooter = hf
                }
            case "--scale":
                i += 1
                if i < args.count, let s = Double(args[i]), s > 0 {
                    options.dynamicTypeScale = CGFloat(s)
                } else {
                    warn("invalid scale value '\(i < args.count ? args[i] : "")', using default 1.0")
                }
            default:
                if inputPath.isEmpty { inputPath = args[i] }
                else if outputPath.isEmpty { outputPath = args[i] }
            }
            i += 1
        }

        if outputPath.isEmpty {
            outputPath = (inputPath as NSString).deletingPathExtension + ".pdf"
        }
        return ParsedArgs(inputPath: inputPath, outputPath: outputPath, options: options)
    }

    /// Renders a markdown file to PDF using the parsed arguments.
    /// Returns the output path on success, or throws on failure.
    @discardableResult
    public static func run(_ parsed: ParsedArgs) throws -> String {
        guard let markdown = try? String(contentsOfFile: parsed.inputPath, encoding: .utf8) else {
            throw CLIError.cannotReadInput(path: parsed.inputPath)
        }
        let inputURL = URL(fileURLWithPath: parsed.inputPath)
        var resolvedOptions = parsed.options
        resolvedOptions.baseURL = inputURL.deletingLastPathComponent()

        let engine = MarkdownPrintEngine()
        let result = try engine.render(markdown, options: resolvedOptions)
        try result.pdfData.write(to: URL(fileURLWithPath: parsed.outputPath))
        return parsed.outputPath
    }

    /// Returns the help text shown when no arguments are provided.
    public static let helpText: String = {
        """
        markdownprint-cli - generates PDFs from Markdown files

        Usage: markdownprint-cli <input.md> [output.pdf] [options]

        Layout:
          --size a4|letter        Page size (default: a4)
          --justify               Justify text (align both margins)
          --line-numbers          Show line numbers in code blocks
          --scale N               Font scale factor (default: 1.0)

        Theme:
          --theme light|dark|mono Visual theme (default: light)
          --theme-file path.json  Load custom theme from JSON
          --high-contrast         High contrast accessibility mode

        Content:
          --toc                   Include table of contents
          --title \"...\"            PDF title
          --author \"...\"           PDF author
          --font apple|web        Font family (default: apple)

        Decorations:
          --watermark \"TEXT\"       Diagonal text watermark
          --watermark-image PATH   Image watermark (logo, stamp)
          --header \"TEXT\"          Page header ({page}, {title}, {section})
          --footer \"TEXT\"          Page footer ({page}, {title})
        """
    }()
}

public enum CLIError: LocalizedError {
    case cannotReadInput(path: String)

    public var errorDescription: String? {
        switch self {
        case .cannotReadInput(let path): return "Could not read input file: \(path)"
        }
    }
}
