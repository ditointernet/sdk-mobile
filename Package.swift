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
    dependencies: [],
    targets: [
        .target(
            name: "DitoSDKNotificationService",
            dependencies: [],
            path: "ios/DitoNotificationService"
        ),
        .target(
            name: "DitoSDK",
            dependencies: ["DitoSDKNotificationService"],
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
