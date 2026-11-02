// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "advanced_in_app_review",
    platforms: [.iOS("13.0")],
    products: [.library(name: "advanced-in-app-review", targets: ["advanced_in_app_review"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [.target(
        name: "advanced_in_app_review",
        dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")],
        resources: [.process("PrivacyInfo.xcprivacy")]
    )]
)
