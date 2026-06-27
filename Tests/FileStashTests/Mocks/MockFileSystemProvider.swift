import Foundation
@testable import FileStash

/// Mock implementation of `FileSystemProvider` for unit testing.
///
/// Every method records its arguments for test assertions and checks
/// configurable error properties before returning configurable results.
/// A minimal in-memory file set tracks which paths "exist".
///
/// Usage:
/// ```swift
/// let mock = MockFileSystemProvider()
/// mock.fileExistsResult = true
/// mock.contentsOfDirectoryResult = [someURL]
/// let store = StashStore(fileSystem: mock)
/// ```
@MainActor
class MockFileSystemProvider: @preconcurrency FileSystemProvider {

    // MARK: - Recorded calls

    private(set) var createDirectoryCalls: [(url: URL, withIntermediateDirectories: Bool)] = []
    private(set) var contentsOfDirectoryCalls: [(url: URL, keys: [URLResourceKey]?)] = []
    private(set) var moveItemCalls: [(from: URL, to: URL)] = []
    private(set) var copyItemCalls: [(from: URL, to: URL)] = []
    private(set) var removeItemCalls: [URL] = []
    private(set) var fileExistsCalls: [String] = []
    private(set) var urlsForDirectoryCalls: [(directory: FileManager.SearchPathDirectory, domainMask: FileManager.SearchPathDomainMask)] = []
    private(set) var replaceItemAtCalls: [(original: URL, new: URL, backupName: String?, options: FileManager.ItemReplacementOptions)] = []

    // MARK: - Configurable results

    /// Returned by `urls(for:in:)`. Default: a path under `/tmp/TestSupport`.
    var urlsForDirectoryResult: [URL] = [
        URL(fileURLWithPath: "/tmp/FileStashTestSupport")
    ]

    /// Returned by `contentsOfDirectory(at:includingPropertiesForKeys:)`.
    var contentsOfDirectoryResult: [URL] = []

    /// Returned by `fileExists(atPath:)` when the path is not in the simulated file set.
    var fileExistsResult: Bool = false

    /// Returned by `replaceItemAt(_:withItemAt:backupItemName:options:)` when no error.
    /// If `nil`, returns `newItemURL` instead.
    var replaceItemAtResult: URL?

    // MARK: - Configurable errors (nil = no error / success)

    var createDirectoryError: (any Error)?
    var contentsOfDirectoryError: (any Error)?
    var moveItemError: (any Error)?
    var copyItemError: (any Error)?
    var removeItemError: (any Error)?
    var replaceItemAtError: (any Error)?

    // MARK: - Simulated file system

    /// Paths that report as existing via `fileExists(atPath:)`.
    private var existingFiles: Set<String> = []

    /// Register a path as "existing" in the simulated file system.
    func addExistingFile(at url: URL) {
        existingFiles.insert(url.path)
    }

    /// Remove a path from the simulated file system.
    func removeExistingFile(at url: URL) {
        existingFiles.remove(url.path)
    }

    // MARK: - Reset

    /// Clears all recorded calls, configured results, errors, and simulated files.
    func reset() {
        createDirectoryCalls.removeAll()
        contentsOfDirectoryCalls.removeAll()
        moveItemCalls.removeAll()
        copyItemCalls.removeAll()
        removeItemCalls.removeAll()
        fileExistsCalls.removeAll()
        urlsForDirectoryCalls.removeAll()
        replaceItemAtCalls.removeAll()

        urlsForDirectoryResult = [URL(fileURLWithPath: "/tmp/FileStashTestSupport")]
        contentsOfDirectoryResult = []
        fileExistsResult = false
        replaceItemAtResult = nil

        createDirectoryError = nil
        contentsOfDirectoryError = nil
        moveItemError = nil
        copyItemError = nil
        removeItemError = nil
        replaceItemAtError = nil

        existingFiles.removeAll()
    }

    // MARK: - FileSystemProvider

    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        createDirectoryCalls.append((url, withIntermediateDirectories))
        if let error = createDirectoryError { throw error }
        existingFiles.insert(url.path)
    }

    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?) throws -> [URL] {
        contentsOfDirectoryCalls.append((url, keys))
        if let error = contentsOfDirectoryError { throw error }
        return contentsOfDirectoryResult
    }

    func moveItem(at srcURL: URL, to dstURL: URL) throws {
        moveItemCalls.append((srcURL, dstURL))
        if let error = moveItemError { throw error }
        existingFiles.remove(srcURL.path)
        existingFiles.insert(dstURL.path)
    }

    func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copyItemCalls.append((srcURL, dstURL))
        if let error = copyItemError { throw error }
        existingFiles.insert(dstURL.path)
    }

    func removeItem(at url: URL) throws {
        removeItemCalls.append(url)
        if let error = removeItemError { throw error }
        existingFiles.remove(url.path)
    }

    func fileExists(atPath path: String) -> Bool {
        fileExistsCalls.append(path)
        return fileExistsResult || existingFiles.contains(path)
    }

    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        urlsForDirectoryCalls.append((directory, domainMask))
        return urlsForDirectoryResult
    }

    func replaceItemAt(_ originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String?, options: FileManager.ItemReplacementOptions) throws -> URL? {
        replaceItemAtCalls.append((originalItemURL, newItemURL, backupItemName, options))
        if let error = replaceItemAtError { throw error }
        existingFiles.remove(originalItemURL.path)
        existingFiles.insert(newItemURL.path)
        return replaceItemAtResult ?? newItemURL
    }
}
