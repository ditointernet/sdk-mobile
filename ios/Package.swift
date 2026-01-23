// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "DitoSDK",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "DitoSDK",
            targets: ["DitoSDK"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DitoSDK",
            dependencies: [],
            path: "DitoSDK/Sources",
            exclude: ["DitoSDK/Info.plist"]
        ),
        .testTarget(
            name: "DitoSDKTests",
            dependencies: ["DitoSDK"],
            path: "Tests",
            exclude: ["DitoSDK/Info.plist"]
        ),
    ]
)
