// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ContextCoreKit",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "ContextCoreKit", targets: ["ContextCoreKit"])
  ],
  targets: [
    .target(name: "ContextCoreKit"),
    .testTarget(name: "ContextCoreKitTests", dependencies: ["ContextCoreKit"]),
  ]
)
