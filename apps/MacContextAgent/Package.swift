// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "DaylineMacContext",
  platforms: [.macOS(.v15)],
  products: [.executable(name: "dayline-mac-context", targets: ["DaylineMacContext"])],
  dependencies: [
    .package(path: "../../integrations/MacContextKit"),
    .package(path: "../../packages/ContextCoreFFIKit"),
  ],
  targets: [
    .executableTarget(
      name: "DaylineMacContext",
      dependencies: ["MacContextKit", "ContextCoreFFIKit"]
    )
  ]
)
