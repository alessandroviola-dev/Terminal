// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Terminal",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Terminal", targets: ["Terminal"])],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", branch: "main")
    ],
    targets: [
        .executableTarget(name: "Terminal", dependencies: [
            .product(name: "SwiftTerm", package: "SwiftTerm")
        ]),
        .testTarget(name: "TerminalTests", dependencies: ["Terminal"])
    ]
)
