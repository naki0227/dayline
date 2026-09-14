// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ContextCoreFFIKit",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "ContextCoreFFIKit", targets: ["ContextCoreFFIKit"])
  ],
  dependencies: [
    .package(path: "../ContextCoreKit")
  ],
  targets: [
    .binaryTarget(
      name: "context_ffiFFI",
      path: ".artifacts/ContextCoreFFI.xcframework"
    ),
    .target(
      name: "ContextCoreFFIGenerated",
      dependencies: ["context_ffiFFI"],
      path: ".generated/ContextCoreFFIGenerated"
    ),
    .target(
      name: "ContextCoreFFIKit",
      dependencies: [
        "ContextCoreKit",
        "ContextCoreFFIGenerated",
      ]
    ),
    .testTarget(
      name: "ContextCoreFFIKitTests",
      dependencies: ["ContextCoreFFIKit"]
    ),
  ]
)
