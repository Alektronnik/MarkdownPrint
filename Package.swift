// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkdownPrint",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        // Layer 1 -- C++ core, zero Apple dependencies. Compiles and
        // tests on Linux, macOS, or CI. Use standalone for parsing +
        // layout computation without any rendering.
        .library(name: "CMarkdownPrintCore", targets: ["CMarkdownPrintCore"]),
        // Layer 1+2 exposed together: useful for a Linux backend, a
        // CLI, or any consumer that only needs to parse and compute
        // layout without painting anything.
        .library(name: "MarkdownPrintCore", targets: ["MarkdownPrintCore"]),
        // Full package with final rendering (Apple-only).
        .library(name: "MarkdownPrint", targets: ["MarkdownPrint"]),
        // Command-line utility to generate PDFs from Markdown.
        .executable(name: "markdownprint-cli", targets: ["MarkdownPrintCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
    ],
    targets: [
        // Layer 1 -- The brain: pure C++, no Apple dependencies.
        // Compiles and tests identically on Linux, macOS, or CI.
        .target(
            name: "CMarkdownPrintCore",
            path: "Sources/CMarkdownPrintCore"
        ),

        // Layer 2 -- Ergonomic Swift wrapper over C++, using native
        // interop (Swift 5.9+). No Objective-C++ bridge: Swift calls
        // C++ classes directly. Still no CoreGraphics, so cross-platform.
        .target(
            name: "MarkdownPrintCore",
            dependencies: ["CMarkdownPrintCore"],
            path: "Sources/MarkdownPrintCore",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),

        // Layer 3 -- PDF rendering with CoreGraphics/CoreText/PDFKit.
        // Apple-only: macOS 13+, iOS 16+, visionOS 1+.
        .target(
            name: "MarkdownPrint",
            dependencies: ["MarkdownPrintCore"],
            path: "Sources/MarkdownPrint",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),

        // CLI para convertir archivos .md a PDF desde la terminal.
        .executableTarget(
            name: "MarkdownPrintCLI",
            dependencies: ["MarkdownPrint"],
            path: "Sources/MarkdownPrintCLI",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),

        // Tests de todo el stack. Dependen de MarkdownPrint (capa 3)
        // y requieren macOS para ejecutarse.
        .testTarget(
            name: "MarkdownPrintCoreTests",
            dependencies: [
                "MarkdownPrint",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/MarkdownPrintCoreTests",
            exclude: ["__Snapshots__"],
            resources: [.copy("Resources")],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        )
    ],
    cxxLanguageStandard: .cxx17
)
