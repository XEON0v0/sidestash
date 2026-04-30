// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FileStash",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "FileStash",
            resources: [.process("en.lproj"), .process("zh-Hans.lproj")]
        ),
        .testTarget(
            name: "FileStashTests",
            dependencies: ["FileStash"],
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
