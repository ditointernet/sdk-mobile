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
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf", from: "1.28.0"),
        .package(url: "https://github.com/connectrpc/connect-swift", from: "0.14.0"),
    ],
    targets: [
        .target(
            name: "DitoSDK",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "Connect", package: "connect-swift"),
            ],
            path: "DitoSDK",
            exclude: ["Info.plist"],
            resources: [
                .process("GlobalState.plist"),
                .process("Persistence/DitoDataModel.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "DitoSDKTests",
            dependencies: ["DitoSDK"],
            path: "DitoSDKTests",
            exclude: ["Info.plist"]
        ),
    ]
)
