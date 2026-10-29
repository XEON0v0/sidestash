import Foundation

/// Zips a set of files into one archive. Runs off the main actor: copying and
/// compressing large files can take a while.
enum StashArchiveExporter {
    enum ExportError: LocalizedError {
        case noFiles
        case archiverFailed(status: Int32, message: String)

        var errorDescription: String? {
            switch self {
            case .noFiles:
                return NSLocalizedString("bulk.unavailable.empty", comment: "No stashed files")
            case let .archiverFailed(status, message):
                let detail = message.isEmpty ? "ditto exited with status \(status)" : message
                return detail
            }
        }
    }

    /// `"SideStash 2026-10-29 14.05"` — dots instead of colons, which Finder
    /// shows as slashes.
    static func defaultBaseName(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "SideStash \(formatter.string(from: date))"
    }

    /// Writes `<baseName>.zip` (collision-safe) into `directory`. The archive
    /// holds one `<baseName>` folder with every file; the sources are untouched.
    static func exportArchive(
        of files: [URL],
        to directory: URL,
        baseName: String = defaultBaseName(),
        fileManager: FileManager = .default
    ) throws -> URL {
        guard !files.isEmpty else { throw ExportError.noFiles }

        let stagingRoot = fileManager.temporaryDirectory
            .appendingPathComponent("SideStashExport-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: stagingRoot) }

        // A folder of copies (APFS clones, so nearly free) gives the archive
        // one tidy top-level folder instead of loose files.
        let stagingFolder = stagingRoot.appendingPathComponent(baseName, isDirectory: true)
        try fileManager.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        for file in files {
            let destination = StashStore.uniqueURL(at: stagingFolder, for: file.lastPathComponent) {
                fileManager.fileExists(atPath: $0)
            }
            try fileManager.copyItem(at: file, to: destination)
        }

        let archiveURL = StashStore.uniqueURL(at: directory, for: "\(baseName).zip") {
            fileManager.fileExists(atPath: $0)
        }
        try runDitto(source: stagingFolder, archive: archiveURL)
        return archiveURL
    }

    /// `ditto -c -k` without Finder's `--sequesterRsrc`: the archive is meant
    /// for sharing, so it leaves out resource forks, extended attributes and
    /// quarantine, which would otherwise land as `__MACOSX/._*` clutter.
    private static func runDitto(source: URL, archive: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k", "--keepParent", "--norsrc", "--noextattr", "--noqtn", "--noacl",
            source.path, archive.path,
        ]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            try? FileManager.default.removeItem(at: archive)
            throw ExportError.archiverFailed(status: process.terminationStatus, message: message)
        }
    }
}
