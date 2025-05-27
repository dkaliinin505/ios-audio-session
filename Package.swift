// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IosAudioSession",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "IosAudioSession",
            targets: ["AudioSessionPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "AudioSessionPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/AudioSessionPlugin"),
        .testTarget(
            name: "AudioSessionPluginTests",
            dependencies: ["AudioSessionPlugin"],
            path: "ios/Tests/AudioSessionPluginTests")
    ]
)