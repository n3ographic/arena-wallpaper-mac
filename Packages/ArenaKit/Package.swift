// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ArenaKit",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ArenaKit", targets: ["ArenaKit"])],
    targets: [
        .target(name: "ArenaKit"),
        .testTarget(name: "ArenaKitTests", dependencies: ["ArenaKit"]),
    ],
    swiftLanguageModes: [.v5]
)
