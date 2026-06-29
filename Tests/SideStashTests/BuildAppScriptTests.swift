import Foundation
import Testing

struct BuildAppScriptTests {
    @Test func buildAppScript_declaresAppleEventsUsageDescription() throws {
        let scriptURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("build_app.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        #expect(script.contains("NSAppleEventsUsageDescription"))
        #expect(script.contains("current Finder folder"))
    }
}
