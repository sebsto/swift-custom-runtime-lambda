// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HelloSwiftLambda",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "LambdaRuntime",
            targets: ["LambdaRuntime"])        
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/IBM-Swift/HeliumLogger.git", from: "1.8.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "HelloSwiftLambda",
            dependencies: ["LambdaRuntime", "HeliumLogger"],
            path: "lambda-function/Sources"
        ),
        .target(
            name: "LambdaRuntime",
            dependencies: ["HeliumLogger"],
            path: "lambda-runtime/Sources"
        ),
        .testTarget(
            name: "HelloSwiftLambdaTests",
            dependencies: ["HelloSwiftLambda"],
            path: "lambda-function/Tests"
        ),
    ]
)
