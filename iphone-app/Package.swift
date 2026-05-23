// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AgentUsageBridgeApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v8)
    ],
    products: [
        .library(name: "AgentUsageBridgeCore", targets: ["AgentUsageBridgeCore"]),
        .library(name: "AgentUsageBridgeUI", targets: ["AgentUsageBridgeUI"]),
        .executable(name: "agent-usage-bridge-tests", targets: ["AgentUsageBridgeTests"])
    ],
    targets: [
        .target(name: "AgentUsageBridgeCore"),
        .target(
            name: "AgentUsageBridgeUI",
            dependencies: ["AgentUsageBridgeCore"]
        ),
        .executableTarget(
            name: "AgentUsageBridgeTests",
            dependencies: ["AgentUsageBridgeCore"]
        )
    ]
)
