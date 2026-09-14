// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "DaylineProductKit",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "DaylineProductKit", targets: ["DaylineProductKit"])
  ],
  targets: [
    .target(
      name: "DaylineProductKit",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "DaylineProductKitTests",
      dependencies: ["DaylineProductKit"]
    ),
  ]
)
