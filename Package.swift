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
        // Extension-safe subset for a Notification Service Extension target.
        // Links only Foundation/UserNotifications: no CoreData, no UIKit, no
        // app-only API, so it can be linked into an app extension.
        .library(
            name: "DitoSDKNotificationService",
            targets: ["DitoSDKNotificationService"]
        )
    ],
    // This is the manifest Xcode resolves for
    // https://github.com/ditointernet/sdk-mobile, so it is the one integrators
    // actually build. It must stay in step with ios/Package.swift, which exists
    // for `Add Local...` pointing at the ios/ directory.
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf", from: "1.28.0"),
        .package(url: "https://github.com/connectrpc/connect-swift", from: "0.14.0"),
    ],
    targets: [
        .target(
            name: "DitoSDKNotificationService",
            dependencies: [],
            path: "ios/DitoNotificationService"
        ),
        .target(
            name: "DitoSDK",
            dependencies: [
                "DitoSDKNotificationService",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "Connect", package: "connect-swift"),
            ],
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
