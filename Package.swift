// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ServerFramework",
    platforms: [.macOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ServerFramework",
            targets: [
                "ServerFramework"
            ]),
        .library(
            name: "ServerFrameworkNIO",
            targets: [
                "ServerFramework",
                "ServerFrameworkNIO"
            ]),
        .library(
            name: "ServerFrameworkLambda",
            targets: [
                "ServerFramework",
                "ServerFrameworkLambda",
            ]),
        .library(
            name: "ServerFrameworkAuth",
            targets: [
                "ServerFramework",
                "ServerFrameworkAuth"
            ]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", .upToNextMajor(from:"0.5.0")),
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", "1.0.0" ..< "3.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "1.0.0-alpha"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-json.git", .upToNextMajor(from: "0.6.0")),
        .package(
              url: "https://github.com/karwa/swift-url",
              .upToNextMajor(from: "0.2.0")
            ),
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "0.1.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
        .package(url: "https://github.com/Kitura/Swift-JWT.git", from: "3.6.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ServerFramework",
            dependencies: [ 
                .product(name: "Swinject", package: "Swinject"),
                
                // swift-server
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Lifecycle", package: "swift-service-lifecycle"),
                .product(name: "Metrics", package: "swift-metrics"),
                
                
                // NIO for ByteBuffer
                .product(name: "NIO", package: "swift-nio"),

                // Extras
                .product(name: "WebURL", package: "swift-url"),
                // TODO: remove ExtrasJSON from other targets if it is in the base one
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
            ],
            path: "Sources/ServerFramework"
        ),
        .target(
            name: "ServerFrameworkNIO",
            dependencies: [
                .byName(name: "ServerFramework"),
                
                // NIO
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                
                // swift-server
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                
                // Extras
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
            ],
            path: "Sources/ServerFrameworkNIO"
        ),
        .target(
            name: "ServerFrameworkLambda",
            dependencies: [
                .byName(name: "ServerFramework"),
                
                // AWS
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-runtime"),
                
                // NIO
                .product(name: "NIO", package: "swift-nio"),
                
                // Extras
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
            ],
            path: "Sources/ServerFrameworkLambda"
        ),
        .target(
            name: "ServerFrameworkXCTest",
            dependencies: [
                .byName(name: "ServerFramework"),
                
                // Extras
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
                
                // NIO
                .product(name: "NIO", package: "swift-nio"),
            ],
            path: "Sources/ServerFrameworkXCTest"
        ),
        .target(
            name: "ServerFrameworkAuth",
            dependencies: [
                .byName(name: "ServerFramework"),
                
                // Extras
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
                
                // NIO
                .product(name: "NIO", package: "swift-nio"),

                 
                .product(name: "SwiftJWT", package: "Swift-JWT"),

                
                // HTTP client
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            path: "Sources/ServerFrameworkAuth"
        ),
        .testTarget(
            name: "ServerFrameworkTests",
            dependencies: ["ServerFramework"]),
    ]
)
