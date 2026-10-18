// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "WalkThisWay",
    platforms: [ .macOS(.v26) ],
    targets: [
        .executableTarget(
            name: "WalkThisWay",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableUpcomingFeature("ApproachableConcurrency"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("ExistentialAny"),
            ],
        ),
    ]
)
