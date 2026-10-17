// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CertigoKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CertigoCortex", targets: ["CertigoCortex"])
    ],
    targets: [
        .target(name: "CertigoCortex"),
        .testTarget(name: "CertigoKitTests", dependencies: ["CertigoCortex"]),
    ]
)
