// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EdgeRouter",
    defaultLocalization: "uk",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "EdgeRouter", targets: ["EdgeRouter"]),
        .library(name: "FraudLite", targets: ["FraudLite"]),
    ],
    targets: [
        // Вибір місця виконання: контекст, оцінки, політика, каскад, журнал
        .target(name: "EdgeRouter"),
        // Layer 1 антифроду з бекенду, перенесений на телефон один до одного
        .target(name: "FraudLite"),
        .testTarget(name: "EdgeRouterTests", dependencies: ["EdgeRouter"]),
        .testTarget(
            name: "FraudLiteTests",
            dependencies: ["FraudLite"],
            exclude: ["gen_l1_vectors.py"],
            resources: [.copy("Resources/l1_vectors.json")]
        ),
    ]
)
