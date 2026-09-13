// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "AppleIntelligenceKit",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "AppleIntelligenceKit", targets: ["AppleIntelligenceKit"])
  ],
  dependencies: [
    .package(path: "../ContextCoreKit")
  ],
  targets: [
    .target(
      name: "AppleIntelligenceKit",
      dependencies: ["ContextCoreKit"]
    ),
    .testTarget(
      name: "AppleIntelligenceKitTests",
      dependencies: ["AppleIntelligenceKit"]
    ),
  ]
)
