// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CertigoKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CertigoDomain", targets: ["CertigoDomain"]),
        .library(name: "CertigoData", targets: ["CertigoData"]),
        .library(name: "CertigoCortex", targets: ["CertigoCortex"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "5.0.1")
    ],
    targets: [
        .target(name: "CertigoDomain"),
        .target(
            name: "CertigoData",
            dependencies: [
                "CertigoDomain",
                .product(
                    name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
            ]
        ),
        .target(name: "CertigoCortex"),
        .testTarget(
            name: "CertigoKitTests",
            dependencies: ["CertigoDomain", "CertigoData", "CertigoCortex"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
