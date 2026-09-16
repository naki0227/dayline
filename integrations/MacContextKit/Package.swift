// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "MacContextKit",
  platforms: [.macOS(.v15)],
  products: [.library(name: "MacContextKit", targets: ["MacContextKit"])],
  dependencies: [.package(path: "../../packages/ContextCoreKit")],
  targets: [
    .target(
      name: "MacContextKit",
      dependencies: ["ContextCoreKit"],
      linkerSettings: [.linkedLibrary("sqlite3")]
    ),
    .testTarget(
      name: "MacContextKitTests",
      dependencies: ["MacContextKit", "ContextCoreKit"]
    ),
  ]
)
