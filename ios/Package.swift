// swift-tools-version:5.10
// Mantenha em par com o Package.swift da raiz, que é o manifesto que o Xcode resolve
// a partir da URL do repositório. Piso real do código: `nonisolated(unsafe)` (5.10).

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
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf", from: "1.28.0"),
        .package(url: "https://github.com/connectrpc/connect-swift", from: "0.14.0"),
    ],
    targets: [
        .target(
            name: "DitoSDKNotificationService",
            dependencies: [],
            path: "DitoNotificationService"
        ),
        .target(
            name: "DitoSDK",
            dependencies: [
                "DitoSDKNotificationService",
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
