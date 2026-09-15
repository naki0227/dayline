// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "NotionKit",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "NotionKit", targets: ["NotionKit"])
  ],
  dependencies: [
    .package(path: "../../packages/ContextCoreKit"),
    .package(path: "../../packages/DaylineProductKit"),
  ],
  targets: [
    .target(
      name: "NotionKit",
      dependencies: ["ContextCoreKit", "DaylineProductKit"]
    ),
    .testTarget(name: "NotionKitTests", dependencies: ["NotionKit", "ContextCoreKit"]),
  ]
)
