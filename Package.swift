// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SnatchShot",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SnatchShot",
            targets: ["SnatchShot"]
        ),
    ],
    dependencies: [
        // Google Sign In SDK
        .package(
            url: "https://github.com/google/GoogleSignIn-iOS.git",
            .upToNextMajor(from: "9.0.0")
        ),
        // Superwall SDK for paywalls
        .package(
            url: "https://github.com/superwall/Superwall-iOS",
            .upToNextMajor(from: "4.0.0")
        ),
        // AppsFlyer SDK for attribution and marketing analytics
        .package(
            url: "https://github.com/AppsFlyerSDK/AppsFlyerFramework.git",
            .upToNextMajor(from: "6.12.0")
        ),
        // Mixpanel SDK for product analytics
        .package(
            url: "https://github.com/mixpanel/mixpanel-swift.git",
            .upToNextMajor(from: "4.0.0")
        ),
    ],
    targets: [
        .target(
            name: "SnatchShot",
            dependencies: [
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS"),
                .product(name: "SuperwallKit", package: "Superwall-iOS"),
                .product(name: "AppsFlyerLib", package: "AppsFlyerFramework"),
                .product(name: "Mixpanel", package: "mixpanel-swift"),
            ],
            path: "SnatchShot"
        ),
        .testTarget(
            name: "SnatchShotTests",
            dependencies: ["SnatchShot"],
            path: "SnatchShotTests"
        ),
    ]
)
