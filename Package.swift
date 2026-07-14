// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Berlinan",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // The macOS app (bundle assembled by build.sh — see development_workflow.md §2).
        .executable(name: "Berlinan", targets: ["Berlinan"]),
        // Headless render tool (spec §13, M1). Named `berlinan-cli` because a
        // product named `berlinan` would collide with `Berlinan` in the SPM
        // build directory on case-insensitive APFS.
        .executable(name: "berlinan-cli", targets: ["BerlinanCLI"]),
        // The pure, deterministic engine (spec §5.1) — no Apple-framework deps.
        .library(name: "BerlinanEngine", targets: ["BerlinanEngine"]),
    ],
    targets: [
        .target(
            name: "BerlinanEngine",
            path: "Sources/BerlinanEngine"
        ),
        .executableTarget(
            name: "BerlinanCLI",
            dependencies: ["BerlinanEngine"],
            path: "Sources/BerlinanCLI"
        ),
        .executableTarget(
            name: "Berlinan",
            dependencies: ["BerlinanEngine"],
            path: "Sources/Berlinan"
        ),
        .testTarget(
            name: "BerlinanEngineTests",
            dependencies: ["BerlinanEngine"],
            path: "Tests/BerlinanEngineTests"
        ),
    ]
)
