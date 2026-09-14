// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ContextCaptureKit",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "ContextCaptureKit", targets: ["ContextCaptureKit"])
  ],
  targets: [
    .target(name: "ContextCaptureKit"),
    .testTarget(
      name: "ContextCaptureKitTests",
      dependencies: ["ContextCaptureKit"]
    ),
  ]
)
