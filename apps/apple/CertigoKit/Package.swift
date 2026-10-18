// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CertigoKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CertigoCortex", targets: ["CertigoCortex"]),
        .library(name: "CertigoDomain", targets: ["CertigoDomain"]),
        .library(name: "CertigoData", targets: ["CertigoData"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "5.0.1")
    ],
    targets: [
        .target(name: "CertigoCortex"),
        .target(name: "CertigoDomain"),
        .target(name: "CertigoAppleFileIO"),
        .target(
            name: "CertigoData",
            dependencies: [
                "CertigoDomain",
                .target(name: "CertigoAppleFileIO", condition: .when(platforms: [.iOS])),
                .product(
                    name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
            ]
        ),
        .testTarget(
            name: "CertigoKitTests",
            dependencies: ["CertigoCortex", "CertigoDomain", "CertigoData"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
