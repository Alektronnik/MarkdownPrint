import Foundation
import MarkdownPrint

// The CLI target delegates all parsing and execution to CLIParser
// in the MarkdownPrint module so that logic is testable without
// forking a subprocess.

let args = CommandLine.arguments
if args.count < 2 {
    print(CLIParser.helpText)
} else {
    let parsed = CLIParser.parse(Array(args.dropFirst()))
    do {
        try CLIParser.run(parsed)
    } catch {
        print("ERROR: \(error.localizedDescription)")
    }
}
