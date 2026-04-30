import Foundation

func makeTempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("stash_test_\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

func makeTempFile(named filename: String, in directory: URL, content: String = "") -> URL {
    let file = directory.appendingPathComponent(filename)
    try? content.write(to: file, atomically: true, encoding: .utf8)
    return file
}

func removeDir(_ dir: URL) {
    try? FileManager.default.removeItem(at: dir)
}

func removeFile(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

func fileExists(at url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
}

func makeNonexistentFileURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("stash_nonexistent_\(UUID().uuidString).txt")
}
