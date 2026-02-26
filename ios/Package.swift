// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "DitoSDK",
    platforms: [.iOS(.v16)],
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
            path: "DitoSDK",
            exclude: ["DitoSDK/Info.plist"]
        ),
        .testTarget(
            name: "DitoSDKTests",
            dependencies: ["DitoSDK"],
            path: "DitoSDKTests",
            exclude: ["Info.plist"]
        ),
    ]
)
