// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FileStash",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "FileStash"
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
