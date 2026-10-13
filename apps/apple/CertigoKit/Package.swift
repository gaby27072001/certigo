// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CertigoKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CertigoDomain", targets: ["CertigoDomain"]),
        .library(name: "CertigoData", targets: ["CertigoData"]),
        .library(name: "CertigoCortex", targets: ["CertigoCortex"]),
    ],
    targets: [
        .target(name: "CertigoDomain"),
        .target(name: "CertigoData", dependencies: ["CertigoDomain"]),
        .target(name: "CertigoCortex"),
        .testTarget(
            name: "CertigoKitTests",
            dependencies: ["CertigoDomain", "CertigoData", "CertigoCortex"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
