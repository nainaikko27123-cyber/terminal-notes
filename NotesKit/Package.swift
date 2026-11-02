// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotesKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NotesKit", targets: ["NotesKit"]),
    ],
    targets: [
        .target(name: "NotesKit"),
        .testTarget(name: "NotesKitTests", dependencies: ["NotesKit"]),
    ]
)
