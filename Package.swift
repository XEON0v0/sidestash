// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SideStash",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SideStash",
            resources: [.process("en.lproj"), .process("zh-Hans.lproj")]
        ),
        .testTarget(
            name: "SideStashTests",
            dependencies: ["SideStash"],
            swiftSettings: [
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"]),
            ],
            linkerSettings: [
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"]),
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"]),
            ]
        )
    ]
)
