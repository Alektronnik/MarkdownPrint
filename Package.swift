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
        // Capa 1+2 expuestas sueltas: util para un backend Linux, un
        // CLI, o cualquier consumidor que solo necesite parsear y
        // calcular el layout sin pintar nada.
        .library(name: "MarkdownPrintCore", targets: ["MarkdownPrintCore"]),
        // Paquete completo con el renderizado final (Apple-only).
        .library(name: "MarkdownPrint", targets: ["MarkdownPrint"]),
        // Utilidad de linea de comandos para generar PDFs desde Markdown.
        .executable(name: "markdownprint-cli", targets: ["MarkdownPrintCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
    ],
    targets: [
        // Capa 1 — El cerebro: C++ puro, sin dependencias de Apple.
        // Se compila y se testea igual en Linux, macOS o en CI.
        .target(
            name: "CMarkdownPrintCore",
            path: "Sources/CMarkdownPrintCore"
        ),

        // Capa 2 — Envoltorio Swift ergonomico sobre el C++, usando
        // interop nativo (Swift 5.9+). No hay puente Objective-C++:
        // Swift llama directamente a las clases C++. Sigue sin tocar
        // CoreGraphics, así que es cross-platform.
        .target(
            name: "MarkdownPrintCore",
            dependencies: ["CMarkdownPrintCore"],
            path: "Sources/MarkdownPrintCore",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),

        // Capa 3 — Renderizado PDF con CoreGraphics/CoreText/PDFKit.
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
