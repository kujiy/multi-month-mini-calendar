// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MultiMonthMiniCalendar",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "MultiMonthMiniCalendar",
            path: "Sources/MultiMonthMiniCalendar",
            resources: [
                .copy("Holidays")
            ]
        ),
        .testTarget(
            name: "MultiMonthMiniCalendarTests",
            dependencies: ["MultiMonthMiniCalendar"],
            path: "Tests/MultiMonthMiniCalendarTests",
            resources: [
                .copy("Fixtures/Holidays")
            ]
        )
    ]
)
