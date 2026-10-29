import Foundation
import Testing
@testable import SideStash

struct StashArchiveExporterTests {
    private func unzip(_ archive: URL, into directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, directory.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    @Test func export_zipsEveryFileIntoOneFolderAndKeepsTheSources() throws {
        let sourceDir = makeTempDir()
        let destinationDir = makeTempDir()
        let extractDir = makeTempDir()
        defer {
            removeDir(sourceDir)
            removeDir(destinationDir)
            removeDir(extractDir)
        }
        let first = makeTempFile(named: "a.txt", in: sourceDir, content: "alpha")
        let second = makeTempFile(named: "b.md", in: sourceDir, content: "beta")

        let archive = try StashArchiveExporter.exportArchive(
            of: [first, second],
            to: destinationDir,
            baseName: "SideStash Test"
        )

        #expect(archive.lastPathComponent == "SideStash Test.zip")
        #expect(fileExists(at: archive))
        #expect(fileExists(at: first))
        #expect(fileExists(at: second))

        try unzip(archive, into: extractDir)
        let folder = extractDir.appendingPathComponent("SideStash Test")
        #expect(try String(contentsOf: folder.appendingPathComponent("a.txt"), encoding: .utf8) == "alpha")
        #expect(try String(contentsOf: folder.appendingPathComponent("b.md"), encoding: .utf8) == "beta")
    }

    @Test func export_leavesOutMacOnlySidecars() throws {
        let sourceDir = makeTempDir()
        let destinationDir = makeTempDir()
        defer {
            removeDir(sourceDir)
            removeDir(destinationDir)
        }
        let file = makeTempFile(named: "tagged.txt", in: sourceDir, content: "alpha")
        let value = Array("tag".utf8)
        #expect(setxattr(file.path, "com.sidestash.test", value, value.count, 0, 0) == 0)

        let archive = try StashArchiveExporter.exportArchive(of: [file], to: destinationDir, baseName: "Clean")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo")
        process.arguments = ["-1", archive.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let listing = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        #expect(listing.contains("Clean/tagged.txt"))
        #expect(!listing.contains("__MACOSX"))
    }

    @Test func export_neverOverwritesAnExistingArchive() throws {
        let sourceDir = makeTempDir()
        let destinationDir = makeTempDir()
        defer {
            removeDir(sourceDir)
            removeDir(destinationDir)
        }
        let file = makeTempFile(named: "a.txt", in: sourceDir, content: "alpha")
        _ = makeTempFile(named: "Batch.zip", in: destinationDir, content: "existing")

        let archive = try StashArchiveExporter.exportArchive(of: [file], to: destinationDir, baseName: "Batch")

        #expect(archive.lastPathComponent == "Batch 2.zip")
        #expect(try String(contentsOf: destinationDir.appendingPathComponent("Batch.zip"), encoding: .utf8) == "existing")
    }

    @Test func export_withNoFilesThrows() {
        let destinationDir = makeTempDir()
        defer { removeDir(destinationDir) }

        #expect(throws: StashArchiveExporter.ExportError.self) {
            try StashArchiveExporter.exportArchive(of: [], to: destinationDir)
        }
    }

    @Test func defaultBaseName_avoidsColons() {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 29
        components.hour = 14
        components.minute = 5
        let date = Calendar.current.date(from: components)!

        #expect(StashArchiveExporter.defaultBaseName(for: date) == "SideStash 2026-10-29 14.05")
    }
}
