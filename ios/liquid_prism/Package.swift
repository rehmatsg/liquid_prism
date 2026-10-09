// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "liquid_prism",
    platforms: [.iOS("13.0")],
    products: [.library(name: "liquid-prism", targets: ["liquid_prism"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [.target(name: "liquid_prism", dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")])]
)
