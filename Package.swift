// swift-tools-version: 6.1

import PackageDescription

var adwaitaSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .unsafeFlags(["-module-alias", "SwiftUI=OmniUIAdwaita"]),
    .unsafeFlags(["-module-alias", "SwiftData=OmniSwiftData"]),
    .unsafeFlags(["-Xfrontend", "-solver-expression-time-threshold=120000"]),
]

#if compiler(>=6.2)
adwaitaSwiftSettings.insert(
    .unsafeFlags(["-Xfrontend", "-default-isolation", "-Xfrontend", "MainActor"]),
    at: 2
)
#endif

let package = Package(
    name: "iGopherBrowserAdwaita",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "iGopherBrowserAdwaita", targets: ["iGopherBrowserAdwaita"]),
    ],
    dependencies: [
        .package(path: "../../GitHub-Repos/swift-omnikit"),
        .package(url: "https://github.com/navanchauhan/swift-gopher.git", branch: "master"),
        .package(url: "https://github.com/apple/swift-nio.git", "2.69.0"..<"2.84.0"),
        .package(url: "https://github.com/apple/swift-collections.git", "1.0.0"..<"1.3.0"),
    ],
    targets: [
        .target(
            name: "AppIntents",
            path: "Compatibility/AppIntents"
        ),
        .target(
            name: "QuickLook",
            path: "Compatibility/QuickLook"
        ),
        .target(
            name: "TelemetryDeck",
            path: "Compatibility/TelemetryDeck"
        ),
        .executableTarget(
            name: "iGopherBrowserAdwaita",
            dependencies: [
                "AppIntents",
                "QuickLook",
                .product(name: "OmniUIAdwaita", package: "swift-omnikit"),
                .product(name: "SwiftData", package: "swift-omnikit"),
                .product(name: "SwiftGopherClient", package: "swift-gopher"),
                .product(name: "NIOCore", package: "swift-nio"),
                "TelemetryDeck",
            ],
            path: "iGopherBrowser",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "iGopherBrowser.entitlements",
                "Preview Content",
            ],
            swiftSettings: adwaitaSwiftSettings
        ),
    ]
)
