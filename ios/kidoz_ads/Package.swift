// swift-tools-version: 5.9

import PackageDescription

// The Swift Package Manager half of the iOS build. `kidoz_ads.podspec` builds
// the same sources for CocoaPods; keep the two in step.
//
// KidozSDK comes from Kidoz's own package, pinned exactly to the version the
// podspec pins. Both resolve to the same binary: the package's binaryTarget
// and the pod's `source` are the one KidozSDK.zip, checksum-verified here by
// SPM. Bump them together or a CocoaPods app and an SPM app ship different
// SDKs from the same plugin version.
let package = Package(
    name: "kidoz_ads",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "kidoz-ads", targets: ["kidoz_ads"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(
            url: "https://github.com/Kidoz-SDK/kidoz-sdk-swift-package.git",
            exact: "10.1.5"
        ),
    ],
    targets: [
        .target(
            name: "kidoz_ads",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "KidozSDK", package: "kidoz-sdk-swift-package"),
            ],
            // KidozSDK's podspec adds `-lc++` to the app's link; its Swift
            // package does not. Linked here so the two builds agree.
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        )
    ]
)
