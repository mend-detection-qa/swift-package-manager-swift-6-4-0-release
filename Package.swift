// swift-tools-version: 6.0
// Pattern: spm640-plugin-dedup-tree-structure
// Tests: plugin dependency chains + duplicate module dedup (Swift 6.4.0)
import PackageDescription

let package = Package(
    name: "PluginDedupProbe",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "NetworkLib",
            targets: ["NetworkLib"]
        ),
        .plugin(
            name: "SwiftFormatBuildPlugin",
            targets: ["SwiftFormatBuildPlugin"]
        ),
        .plugin(
            name: "NickSwiftFormatPlugin",
            targets: ["NickSwiftFormatPlugin"]
        ),
    ],
    dependencies: [
        // Main library deps
        .package(
            url: "https://github.com/apple/swift-nio",
            from: "2.65.0"
        ),
        // Shared transitive: appears in both main library path
        // (via swift-nio's own dep) AND pulled directly here,
        // AND re-used by the SwiftFormatBuildPlugin target.
        // This is the diamond/dedup axis.
        .package(
            url: "https://github.com/apple/swift-log",
            from: "1.6.1"
        ),
        // Build tool plugin dep — apple/swift-format
        // transitively requires swift-syntax
        .package(
            url: "https://github.com/apple/swift-format",
            from: "510.1.0"
        ),
        // swift-syntax is a transitive of swift-format.
        // Declared explicitly here so the probe exercises
        // the case where the same package (swift-syntax)
        // appears both as a direct plugin dep AND as a
        // transitive of swift-format.
        .package(
            url: "https://github.com/swiftlang/swift-syntax",
            from: "600.0.1"
        ),
        // Command plugin dep — nicklockwood/SwiftFormat
        // (different identity from apple/swift-format above,
        // exercises the case where two plugins from different
        // packages are both present)
        .package(
            url: "https://github.com/nicklockwood/SwiftFormat",
            from: "0.54.3"
        ),
    ],
    targets: [
        // ----- Main library target -----
        .target(
            name: "NetworkLib",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        // ----- Build tool plugin -----
        // Depends on apple/swift-format (formatter as build step)
        // AND on swift-log (shared dep — diamond dedup axis).
        // swift-syntax is a transitive of swift-format (not
        // listed here as a direct dep of the plugin target).
        .plugin(
            name: "SwiftFormatBuildPlugin",
            capability: .buildTool(),
            dependencies: [
                .product(name: "swift-format", package: "swift-format"),
                // Shared with main NetworkLib target — Mend must
                // deduplicate and emit ONE swift-log entry with
                // group: "main" (production wins).
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        // ----- Command plugin -----
        // Uses nicklockwood/SwiftFormat — a different package
        // identity from apple/swift-format.
        .plugin(
            name: "NickSwiftFormatPlugin",
            capability: .command(
                intent: .custom(
                    verb: "nick-format",
                    description: "Run nicklockwood/SwiftFormat"
                ),
                permissions: [.writeToPackageDirectory(reason: "Format source")]
            ),
            dependencies: [
                .product(name: "SwiftFormat", package: "SwiftFormat"),
            ]
        ),
    ]
)
