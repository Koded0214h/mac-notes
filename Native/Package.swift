// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FieldNotes",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "FieldNotes", targets: ["FieldNotes"])],
    targets: [.executableTarget(name: "FieldNotes")]
)
