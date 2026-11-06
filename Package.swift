// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Fala",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "Fala", path: "Sources/Fala")]
)
