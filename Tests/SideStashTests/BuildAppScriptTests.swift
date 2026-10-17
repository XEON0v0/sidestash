import Foundation
import Testing

struct BuildAppScriptTests {
    private let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    @Test func buildAppScript_declaresAppleEventsUsageDescription() throws {
        let script = try contents(of: "build_app.sh")

        #expect(script.contains("NSAppleEventsUsageDescription"))
        #expect(script.contains("current Finder folder"))
    }

    @Test func activeProductMetadata_requiresMacOS26() throws {
        let package = try contents(of: "Package.swift")
        let script = try contents(of: "build_app.sh")
        let readme = try contents(of: "README.md")

        #expect(package.contains(".macOS(\"26.0\")"))
        #expect(script.contains("<key>LSMinimumSystemVersion</key>\n    <string>26.0</string>"))
        #expect(readme.contains("macOS 26 or newer"))
    }

    @Test func buildAppScript_supportsExternalBuildOutput() throws {
        let script = try contents(of: "build_app.sh")

        #expect(script.contains("SIDESTASH_BUILD_DIR"))
        #expect(script.contains("SIDESTASH_APP_DIR"))
        #expect(script.contains("SIDESTASH_SWIFTPM_CACHE"))
        #expect(script.contains("--scratch-path"))
        #expect(script.contains("--show-bin-path"))
    }

    private func contents(of relativePath: String) throws -> String {
        try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
