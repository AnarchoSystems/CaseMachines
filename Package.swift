// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CaseMachines",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CaseMachines",
            targets: ["CaseMachines"]),
    ],
    dependencies: [
      .package(url: "https://github.com/pointfreeco/swift-case-paths.git", exact: "0.4.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CaseMachines",
            dependencies: [.product(name: "CasePaths", package: "swift-case-paths")]),
        .testTarget(
            name: "CaseMachineTests",
            dependencies: ["CaseMachines"]),
    ]
)
