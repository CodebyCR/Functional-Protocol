// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "FunctionalProtocol",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "FunctionalProtocols",
            targets: ["FunctionalProtocols"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
    ],
    targets: [
        // MARK: – Macro Implementation (SwiftSyntax AST Transformation)
        .macro(
            name: "FunctionalProtocolMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // MARK: – Public Library (Macro Declaration + Re-Export)
        .target(
            name: "FunctionalProtocols",
            dependencies: ["FunctionalProtocolMacros"]
        ),

        // MARK: – Client Example (Playground / Smoke Test)
        .executableTarget(
            name: "FunctionalProtocolClient",
            dependencies: ["FunctionalProtocols"]
        ),

        // MARK: – Unit Tests (Macro Expansion Verification)
        .testTarget(
            name: "FunctionalProtocolTests",
            dependencies: [
                "FunctionalProtocolMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
