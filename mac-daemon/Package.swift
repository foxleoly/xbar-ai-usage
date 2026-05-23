// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AgentUsageMacDaemon",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AgentUsageMacDaemon", targets: ["AgentUsageMacDaemon"]),
        .executable(name: "agent-usage-daemon", targets: ["AgentUsageDaemon"]),
        .executable(name: "agent-usage-tests", targets: ["AgentUsageTests"])
    ],
    targets: [
        .target(
            name: "AgentUsageMacDaemon"
        ),
        .executableTarget(
            name: "AgentUsageDaemon",
            dependencies: ["AgentUsageMacDaemon"],
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/AgentUsageDaemon/Info.plist"
                ])
            ]
        ),
        .executableTarget(
            name: "AgentUsageTests",
            dependencies: ["AgentUsageMacDaemon"]
        )
    ]
)
