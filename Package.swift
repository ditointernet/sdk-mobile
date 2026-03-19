// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "DitoSDK",
    version: "3.1.3",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "DitoSDK",
            targets: ["DitoSDK"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DitoSDK",
            dependencies: [],
            path: "ios/DitoSDK",
            exclude: ["Info.plist"],
            resources: [
                .process("GlobalState.plist"),
                .process("Persistence/DitoDataModel.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "DitoSDKTests",
            dependencies: ["DitoSDK"],
            path: "ios/DitoSDKTests",
            exclude: ["Info.plist"]
        )
    ]
)
