// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AdsManagerKit",
    platforms: [
        .iOS(.v15) // <- minimum iOS version is 15
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AdsManagerKit",
            targets: ["AdsManagerKit"]),
        .library(
            name: "AdsManager",
            targets: ["AdsManager"]),
    ],
    dependencies: [
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads", from: "13.4.0"),
        .package(url: "https://github.com/JonasGessner/JGProgressHUD.git", from: "2.2.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AdsManagerKit",
            dependencies: [
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
                .product(name: "JGProgressHUD", package: "JGProgressHUD")
            ],
            path: "Sources",
            exclude: ["AdsManagerCompatibility"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "AdsManager",
            dependencies: ["AdsManagerKit"],
            path: "Sources/AdsManagerCompatibility"
        ),
            
    ],
)
