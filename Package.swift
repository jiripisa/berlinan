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
    dependencies: [
        // Auto-update (phase 56): the standard updater for apps outside the
        // App Store; EdDSA-signed appcast on GitHub Pages.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4"),
    ],
    targets: [
        .target(
            name: "BerlinanEngine",
            path: "Sources/BerlinanEngine"
        ),
        // Ableton Link (FR-IO-5): the official abl_link C wrapper compiled
        // from the vendored GPLv2+ sources (Vendor/link, git submodule with
        // its asio-standalone submodule). C++ stays behind the C header.
        .target(
            name: "CAblLink",
            path: "Vendor/link/extensions/abl_link",
            sources: ["src/abl_link.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../../include"),
                .headerSearchPath("../../modules/asio-standalone/asio/include"),
                .define("LINK_PLATFORM_MACOSX", to: "1"),
            ]
        ),
        // Runtime layer (spec §5.1): owns CoreMIDI and real time. No UI.
        .target(
            name: "BerlinanRuntime",
            dependencies: ["BerlinanEngine", "CAblLink"],
            path: "Sources/BerlinanRuntime"
        ),
        .executableTarget(
            name: "BerlinanCLI",
            dependencies: ["BerlinanEngine"],
            path: "Sources/BerlinanCLI"
        ),
        .executableTarget(
            name: "Berlinan",
            dependencies: [
                "BerlinanEngine", "BerlinanRuntime",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Berlinan",
            linkerSettings: [
                // Sparkle.framework ships in Contents/Frameworks (build.sh).
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .testTarget(
            name: "BerlinanEngineTests",
            dependencies: ["BerlinanEngine"],
            path: "Tests/BerlinanEngineTests",
            resources: [
                .copy("Goldens")
            ]
        ),
        .testTarget(
            name: "BerlinanRuntimeTests",
            dependencies: ["BerlinanRuntime"],
            path: "Tests/BerlinanRuntimeTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
