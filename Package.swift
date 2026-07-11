// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "CodexMeter",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "CodexMeter", targets: ["CodexMeter"])
  ],
  targets: [
    .target(
      name: "CodexMeterKit",
      resources: [.process("Resources")]
    ),
    .executableTarget(
      name: "CodexMeter",
      dependencies: ["CodexMeterKit"]
    ),
    .testTarget(
      name: "CodexMeterKitTests",
      dependencies: ["CodexMeterKit"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
